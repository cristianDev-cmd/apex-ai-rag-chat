-- ============================================================
-- PLUGIN AI RAG DATA LOADER - PL/SQL Code (Plugin Process Inline)
-- Autor: Cristian Alcántara
-- Licencia: Gratis / Open Source
-- Pegar este contenido en: Shared Components > Plugins > 
--   AI RAG Data Loader > PL/SQL Code
-- ============================================================
-- IMPORTANTE: 
--   Execution Function Name = e_execute_loader
-- ============================================================

-- ============================================================
-- 1. FUNCIÓN PRINCIPAL DE EJECUCIÓN (Process Plugin Callback)
-- ============================================================
PROCEDURE e_execute_loader (
    p_process             IN             apex_plugin.t_process,
    p_plugin              IN             apex_plugin.t_plugin,
    p_result              IN OUT NOCOPY  apex_plugin.t_process_exec_result
) 
IS
    
    -- Variables del Plugin
    v_api_key            VARCHAR2(200);
    v_table_raw          VARCHAR2(100);
    v_table_name         VARCHAR2(100);
    v_write_mode         VARCHAR2(20);
    v_existing_count     NUMBER := 0;
    
    -- Mapeo de columnas (con fallbacks estandarizados)
    v_col_id             VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2('col_id'), 'id'));
    v_col_title          VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2('col_title'), 'title'));
    v_col_content        VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2('col_content'), 'content'));
    v_col_embedding      VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2('col_embedding'), 'embedding'));
    v_col_category       VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2('col_category'), 'category'));
    
    -- Page Items de origen
    v_item_title         VARCHAR2(100);
    v_item_content       VARCHAR2(100);
    v_item_category      VARCHAR2(100);
    
    -- Parámetros de Chunking
    v_chunk_sz           NUMBER := NVL(p_process.attributes.get_number('chunk_size'), 1500);
    v_overlap            NUMBER := NVL(p_process.attributes.get_number('chunk_overlap'), 200);
    
    -- Valores recuperados del formulario de la página
    v_doc_title          VARCHAR2(500);
    v_doc_content        CLOB;
    v_doc_category       VARCHAR2(255);
    
    -- Variables de control
    v_table_exists       NUMBER;
    v_table_created      BOOLEAN := FALSE;
    v_msg                VARCHAR2(32767);
    v_len                NUMBER;
    v_pos                NUMBER := 1;
    v_num                NUMBER := 1;
    v_chunk              VARCHAR2(4000);
    v_embedding          VECTOR;
    v_chunks_inserted    NUMBER := 0;
    
    v_sql                VARCHAR2(32767);
    
    -- ============================================================
    -- FUNCIÓN INTERNA: get_embedding (Llamada Gemini Embeddings API)
    -- ============================================================
    FUNCTION get_embedding(p_texto IN VARCHAR2, p_key IN VARCHAR2) RETURN VECTOR IS
        C_GEMINI_EMBED_URL CONSTANT VARCHAR2(500) := 'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent';
        v_request   CLOB;
        v_response  CLOB;
        v_arr_str   CLOB;
        v_embedding VECTOR;
        v_first     BOOLEAN := TRUE;
    BEGIN
        IF p_key IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003, 'La API Key de Gemini está vacía. Ingrese su API Key en Shared Components > Plugins > AI RAG Data Loader > Component Settings.');
        END IF;

        -- Generar request JSON
        APEX_JSON.INITIALIZE_CLOB_OUTPUT;
        APEX_JSON.OPEN_OBJECT;
            APEX_JSON.OPEN_OBJECT('content');
                APEX_JSON.OPEN_ARRAY('parts');
                    APEX_JSON.OPEN_OBJECT;
                        APEX_JSON.WRITE('text', p_texto);
                    APEX_JSON.CLOSE_OBJECT;
                APEX_JSON.CLOSE_ARRAY;
            APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_OBJECT;
        v_request := APEX_JSON.GET_CLOB_OUTPUT;
        APEX_JSON.FREE_OUTPUT;

        APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME  := 'Content-Type';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'application/json';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME  := 'x-goog-api-key';
        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_key;

        v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
            p_url         => C_GEMINI_EMBED_URL || '?key=' || p_key,
            p_http_method => 'POST',
            p_body        => v_request
        );

        IF v_response LIKE '%"error"%' THEN
            RAISE_APPLICATION_ERROR(-20002, 'Gemini embedding error: ' || SUBSTR(v_response, 1, 500));
        END IF;

        DBMS_LOB.CREATETEMPORARY(v_arr_str, TRUE);

        FOR r IN (
            SELECT idx,
                   TO_CHAR(TO_NUMBER(TRIM(val)), 'FM999999990D9999999999999999', 
                           'NLS_NUMERIC_CHARACTERS=.,') AS val_clean
              FROM JSON_TABLE(v_response, '$.embedding.values[*]'
                   COLUMNS (idx FOR ORDINALITY, val VARCHAR2(60) PATH '$'))
             ORDER BY idx
        ) LOOP
            IF v_first THEN
                DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(r.val_clean), r.val_clean);
                v_first := FALSE;
            ELSE
                DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(',' || r.val_clean), ',' || r.val_clean);
            END IF;
        END LOOP;

        v_embedding := TO_VECTOR('[' || v_arr_str || ']', 3072, FLOAT32);
        DBMS_LOB.FREETEMPORARY(v_arr_str);
        RETURN v_embedding;
    EXCEPTION
        WHEN OTHERS THEN
            IF DBMS_LOB.ISTEMPORARY(v_arr_str) = 1 THEN
                DBMS_LOB.FREETEMPORARY(v_arr_str);
            END IF;
            RAISE_APPLICATION_ERROR(-20001, 'Fallo al generar embedding: ' || SQLERRM || ' | Resp API: ' || SUBSTR(v_response, 1, 200));
    END get_embedding;

BEGIN
    -- 1. RECUPERAR API KEY DESDE COMPONENT SETTINGS (Shared Components)
    v_api_key := p_plugin.attributes.get_varchar2('api_key');
    
    -- 2. RECUPERAR CONFIGURACIÓN DE TABLA Y PAGE ITEMS
    v_table_raw     := p_process.attributes.get_varchar2('target_table');
    v_write_mode    := UPPER(NVL(p_process.attributes.get_varchar2('write_mode'), 'REPLACE'));
    v_item_title    := p_process.attributes.get_varchar2('item_title');
    v_item_content  := p_process.attributes.get_varchar2('item_content');
    v_item_category := p_process.attributes.get_varchar2('item_category');
    
    IF v_table_raw IS NULL OR v_item_title IS NULL OR v_item_content IS NULL THEN
        RAISE_APPLICATION_ERROR(-20010, 'Faltan parámetros obligatorios en el Proceso. Verifique Tabla Destino, Item Título e Item Contenido.');
    END IF;
    
    v_table_name := UPPER(TRIM(v_table_raw));
    
    -- 3. RECUPERAR VALORES DE LOS PAGE ITEMS DE APEX
    v_doc_title    := V(v_item_title);
    v_doc_content  := apex_session_state.get_clob(p_item => v_item_content);
    IF v_item_category IS NOT NULL THEN
        v_doc_category := V(v_item_category);
    END IF;
    
    IF v_doc_title IS NULL OR v_doc_content IS NULL OR DBMS_LOB.GETLENGTH(v_doc_content) = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'El título o el contenido del documento están vacíos en el formulario.');
    END IF;

    -- 4. VERIFICAR SI LA TABLA EXISTE EN EL ESQUEMA. SI NO EXISTE, SE CREA AUTOMÁTICAMENTE
    SELECT COUNT(*)
      INTO v_table_exists
      FROM user_tables
     WHERE table_name = v_table_name;
     
    IF v_table_exists = 0 THEN
        BEGIN
            v_sql := 'CREATE TABLE ' || dbms_assert.enquote_name(v_table_name) || ' (' ||
                     dbms_assert.enquote_name(v_col_id)        || ' NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, ' ||
                     dbms_assert.enquote_name(v_col_title)     || ' VARCHAR2(500), ' ||
                     dbms_assert.enquote_name(v_col_content)   || ' CLOB, ' ||
                     dbms_assert.enquote_name(v_col_embedding) || ' VECTOR(3072, FLOAT32), ' ||
                     dbms_assert.enquote_name(v_col_category)  || ' VARCHAR2(255) ' ||
                     ')';
            EXECUTE IMMEDIATE v_sql;
            v_table_created := TRUE;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE_APPLICATION_ERROR(-20012, 'No se pudo crear la tabla RAG automáticamente (' || v_table_name || '): ' || SQLERRM);
        END;
    END IF;

    -- 4.5. AUTOMATIC CLEANUP OF PREVIOUS CHUNKS OR CONTINUATION CALCULATION (Auto-Update RAG)
    IF v_write_mode = 'REPLACE' THEN
        -- Replace Mode: If chunks already exist, we delete them before inserting the new version.
        BEGIN
            v_sql := 'DELETE FROM ' || dbms_assert.enquote_name(v_table_name) || 
                     ' WHERE ' || dbms_assert.enquote_name(v_col_title) || ' = :1 ' ||
                     '    OR ' || dbms_assert.enquote_name(v_col_title) || ' LIKE :2';
            EXECUTE IMMEDIATE v_sql USING v_doc_title, v_doc_title || ' [Part %';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    ELSE
        -- Append Mode: Calculate how many parts already exist to continue the v_num counter correctly
        BEGIN
            v_sql := 'SELECT COUNT(*) FROM ' || dbms_assert.enquote_name(v_table_name) || 
                     ' WHERE ' || dbms_assert.enquote_name(v_col_title) || ' = :1 ' ||
                     '    OR ' || dbms_assert.enquote_name(v_col_title) || ' LIKE :2';
            EXECUTE IMMEDIATE v_sql INTO v_existing_count USING v_doc_title, v_doc_title || ' [Part %';
            v_num := v_existing_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                v_num := 1;
        END;
    END IF;

    -- 5. CHUNKING DINÁMICO Y CARGA DE VECTORES
    v_len := DBMS_LOB.GETLENGTH(v_doc_content);
    
    WHILE v_pos <= v_len LOOP
        -- Obtener fragmento (chunk)
        v_chunk := DBMS_LOB.SUBSTR(v_doc_content, v_chunk_sz, v_pos);
        
        -- Obtener vector de Gemini embeddings
        v_embedding := get_embedding(v_chunk, v_api_key);
        
        -- Insertar en la tabla mapeada de forma dinámica y segura
        v_sql := 'INSERT INTO ' || dbms_assert.enquote_name(v_table_name) || ' (' ||
                 dbms_assert.enquote_name(v_col_title)     || ', ' ||
                 dbms_assert.enquote_name(v_col_content)   || ', ' ||
                 dbms_assert.enquote_name(v_col_embedding) || ', ' ||
                 dbms_assert.enquote_name(v_col_category)  || ') VALUES (:1, :2, :3, :4)';
                 
        BEGIN
            EXECUTE IMMEDIATE v_sql USING 
                v_doc_title || ' [Part ' || v_num || ']', 
                v_chunk, 
                v_embedding, 
                v_doc_category;
                
            v_chunks_inserted := v_chunks_inserted + 1;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                RAISE_APPLICATION_ERROR(-20013, 'Error inserting chunk ' || v_num || ' in ' || v_table_name || ': ' || SQLERRM);
        END;
        
        -- Avanzar posición respetando el overlap
        v_pos := v_pos + v_chunk_sz - v_overlap;
        v_num := v_num + 1;
    END LOOP;
    
    COMMIT;
    
    -- Retornar mensaje de éxito legible en APEX (Dynamic detailed RAG message)
    v_msg := 'Knowledge base updated successfully. ';
    IF v_table_created THEN
        v_msg := v_msg || 'Table "' || v_table_name || '" was created. ';
    ELSE
        IF v_write_mode = 'REPLACE' THEN
            v_msg := v_msg || 'Existing chunks in "' || v_table_name || '" were replaced (REPLACE mode). ';
        ELSE
            v_msg := v_msg || 'New chunks were appended to "' || v_table_name || '" (APPEND mode). ';
        END IF;
    END IF;
    v_msg := v_msg || v_chunks_inserted || ' chunks were automatically created and vectorized.';
    
    p_result.success_message := v_msg;

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END e_execute_loader;
