prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- Oracle APEX export file
--
-- You should run this script using a SQL client connected to the database as
-- the owner (parsing schema) of the application or as a database user with the
-- APEX_ADMINISTRATOR_ROLE role.
--
-- This export file has been automatically generated. Modifying this file is not
-- supported by Oracle and can lead to unexpected application and/or instance
-- behavior now or in the future.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_imp.import_begin (
 p_version_yyyy_mm_dd=>'2026.03.30'
,p_release=>'26.1.0'
,p_default_workspace_id=>5822828758157964
,p_default_application_id=>103
,p_default_id_offset=>0
,p_default_owner=>'TEST'
);
end;
/
 
prompt APPLICATION 103 - Agente ia
--
-- Application Export:
--   Application:     103
--   Name:            Agente ia
--   Date and Time:   20:27 Monday May 25, 2026
--   Exported By:     CRISTIAN
--   Flashback:       0
--   Export Type:     Component Export
--   Manifest
--     PLUGIN: 3574063400042527
--   Manifest End
--   Version:         26.1.0
--   Instance ID:     743364194531067
--

begin
  -- replace components
  wwv_flow_imp.g_mode := 'REPLACE';
end;
/
prompt --application/shared_components/plugins/process_type/com_cristian_rag_dataloader
begin
wwv_flow_imp_shared.create_plugin(
 p_id=>wwv_flow_imp.id(3574063400042527)
,p_plugin_type=>'PROCESS TYPE'
,p_name=>'COM.CRISTIAN.RAG.DATALOADER'
,p_display_name=>'AI RAG Data Loader'
,p_apexlang_name=>'aiRagDataLoader'
,p_supported_component_types=>'APEX_APPLICATION_PAGE_PROC:APEX_APPL_AUTOMATION_ACTIONS:APEX_APPL_TASKDEF_ACTIONS:APEX_APPL_WORKFLOW_ACTIVITIES'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- ============================================================',
'-- PLUGIN AI RAG DATA LOADER - PL/SQL Code (Plugin Process Inline)',
unistr('-- Author: Cristian Alc\00E1ntara'),
'-- License: Open Source',
'-- ============================================================',
'-- IMPORTANTE: ',
'--   Execution Function Name = e_execute_loader',
'-- ============================================================',
'-- ============================================================',
unistr('-- 1. FUNCI\00D3N PRINCIPAL DE EJECUCI\00D3N (Process Plugin Callback)'),
'-- ============================================================',
'PROCEDURE e_execute_loader (',
'    p_process             IN             apex_plugin.t_process,',
'    p_plugin              IN             apex_plugin.t_plugin,',
'    p_result              IN OUT NOCOPY  apex_plugin.t_process_exec_result',
') ',
'IS',
'    ',
'    -- Variables del Plugin',
'    v_api_key            VARCHAR2(200);',
'    v_table_raw          VARCHAR2(100);',
'    v_table_name         VARCHAR2(100);',
'    v_write_mode         VARCHAR2(20);',
'    v_existing_count     NUMBER := 0;',
'    ',
'    -- Mapeo de columnas (con fallbacks estandarizados)',
'    v_col_id             VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2(''col_id''), ''id''));',
'    v_col_title          VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2(''col_title''), ''title''));',
'    v_col_content        VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2(''col_content''), ''content''));',
'    v_col_embedding      VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2(''col_embedding''), ''embedding''));',
'    v_col_category       VARCHAR2(100) := UPPER(NVL(p_process.attributes.get_varchar2(''col_category''), ''category''));',
'    ',
'    -- Page Items de origen',
'    v_item_title         VARCHAR2(100);',
'    v_item_content       VARCHAR2(100);',
'    v_item_category      VARCHAR2(100);',
'    ',
unistr('    -- Par\00E1metros de Chunking'),
'    v_chunk_sz           NUMBER := NVL(p_process.attributes.get_number(''chunk_size''), 1500);',
'    v_overlap            NUMBER := NVL(p_process.attributes.get_number(''chunk_overlap''), 200);',
'    ',
unistr('    -- Valores recuperados del formulario de la p\00E1gina'),
'    v_doc_title          VARCHAR2(500);',
'    v_doc_content        CLOB;',
'    v_doc_category       VARCHAR2(255);',
'    ',
'    -- Variables de control',
'    v_table_exists       NUMBER;',
'    v_table_created      BOOLEAN := FALSE;',
'    v_msg                VARCHAR2(32767);',
'    v_len                NUMBER;',
'    v_pos                NUMBER := 1;',
'    v_num                NUMBER := 1;',
'    v_chunk              VARCHAR2(4000);',
'    v_embedding          VECTOR;',
'    v_chunks_inserted    NUMBER := 0;',
'    ',
'    v_sql                VARCHAR2(32767);',
'    ',
'    -- ============================================================',
unistr('    -- FUNCI\00D3N INTERNA: get_embedding (Llamada Gemini Embeddings API)'),
'    -- ============================================================',
'    FUNCTION get_embedding(p_texto IN VARCHAR2, p_key IN VARCHAR2) RETURN VECTOR IS',
'        C_GEMINI_EMBED_URL CONSTANT VARCHAR2(500) := ''https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent'';',
'        v_request   CLOB;',
'        v_response  CLOB;',
'        v_arr_str   CLOB;',
'        v_embedding VECTOR;',
'        v_first     BOOLEAN := TRUE;',
'    BEGIN',
'        IF p_key IS NULL THEN',
unistr('            RAISE_APPLICATION_ERROR(-20003, ''La API Key de Gemini est\00E1 vac\00EDa. Ingrese su API Key en Shared Components > Plugins > AI RAG Data Loader > Component Settings.'');'),
'        END IF;',
'        -- Generar request JSON',
'        APEX_JSON.INITIALIZE_CLOB_OUTPUT;',
'        APEX_JSON.OPEN_OBJECT;',
'            APEX_JSON.OPEN_OBJECT(''content'');',
'                APEX_JSON.OPEN_ARRAY(''parts'');',
'                    APEX_JSON.OPEN_OBJECT;',
'                        APEX_JSON.WRITE(''text'', p_texto);',
'                    APEX_JSON.CLOSE_OBJECT;',
'                APEX_JSON.CLOSE_ARRAY;',
'            APEX_JSON.CLOSE_OBJECT;',
'        APEX_JSON.CLOSE_OBJECT;',
'        v_request := APEX_JSON.GET_CLOB_OUTPUT;',
'        APEX_JSON.FREE_OUTPUT;',
'        APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;',
'        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME  := ''Content-Type'';',
'        APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''application/json'';',
'        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME  := ''x-goog-api-key'';',
'        APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_key;',
'        v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(',
'            p_url         => C_GEMINI_EMBED_URL || ''?key='' || p_key,',
'            p_http_method => ''POST'',',
'            p_body        => v_request',
'        );',
'        IF v_response LIKE ''%"error"%'' THEN',
'            RAISE_APPLICATION_ERROR(-20002, ''Gemini embedding error: '' || SUBSTR(v_response, 1, 500));',
'        END IF;',
'        DBMS_LOB.CREATETEMPORARY(v_arr_str, TRUE);',
'        FOR r IN (',
'            SELECT idx,',
'                   TO_CHAR(TO_NUMBER(TRIM(val)), ''FM999999990D9999999999999999'', ',
'                           ''NLS_NUMERIC_CHARACTERS=.,'') AS val_clean',
'              FROM JSON_TABLE(v_response, ''$.embedding.values[*]''',
'                   COLUMNS (idx FOR ORDINALITY, val VARCHAR2(60) PATH ''$''))',
'             ORDER BY idx',
'        ) LOOP',
'            IF v_first THEN',
'                DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(r.val_clean), r.val_clean);',
'                v_first := FALSE;',
'            ELSE',
'                DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH('','' || r.val_clean), '','' || r.val_clean);',
'            END IF;',
'        END LOOP;',
'        v_embedding := TO_VECTOR(''['' || v_arr_str || '']'', 3072, FLOAT32);',
'        DBMS_LOB.FREETEMPORARY(v_arr_str);',
'        RETURN v_embedding;',
'    EXCEPTION',
'        WHEN OTHERS THEN',
'            IF DBMS_LOB.ISTEMPORARY(v_arr_str) = 1 THEN',
'                DBMS_LOB.FREETEMPORARY(v_arr_str);',
'            END IF;',
'            RAISE_APPLICATION_ERROR(-20001, ''Fallo al generar embedding: '' || SQLERRM || '' | Resp API: '' || SUBSTR(v_response, 1, 200));',
'    END get_embedding;',
'BEGIN',
'    -- 1. RECUPERAR API KEY DESDE COMPONENT SETTINGS (Shared Components)',
'    v_api_key := p_plugin.attributes.get_varchar2(''api_key'');',
'    ',
unistr('    -- 2. RECUPERAR CONFIGURACI\00D3N DE TABLA Y PAGE ITEMS'),
'    v_table_raw     := p_process.attributes.get_varchar2(''target_table'');',
'    v_write_mode    := UPPER(NVL(p_process.attributes.get_varchar2(''write_mode''), ''REPLACE''));',
'    v_item_title    := p_process.attributes.get_varchar2(''item_title'');',
'    v_item_content  := p_process.attributes.get_varchar2(''item_content'');',
'    v_item_category := p_process.attributes.get_varchar2(''item_category'');',
'    ',
'    IF v_table_raw IS NULL OR v_item_title IS NULL OR v_item_content IS NULL THEN',
unistr('        RAISE_APPLICATION_ERROR(-20010, ''Faltan par\00E1metros obligatorios en el Proceso. Verifique Tabla Destino, Item T\00EDtulo e Item Contenido.'');'),
'    END IF;',
'    ',
'    v_table_name := UPPER(TRIM(v_table_raw));',
'    ',
'    -- 3. RECUPERAR VALORES DE LOS PAGE ITEMS DE APEX',
'    v_doc_title    := V(v_item_title);',
'    v_doc_content  := apex_session_state.get_clob(p_item => v_item_content);',
'    IF v_item_category IS NOT NULL THEN',
'        v_doc_category := V(v_item_category);',
'    END IF;',
'    ',
'    IF v_doc_title IS NULL OR v_doc_content IS NULL OR DBMS_LOB.GETLENGTH(v_doc_content) = 0 THEN',
unistr('        RAISE_APPLICATION_ERROR(-20011, ''El t\00EDtulo o el contenido del documento est\00E1n vac\00EDos en el formulario.'');'),
'    END IF;',
unistr('    -- 4. VERIFICAR SI LA TABLA EXISTE EN EL ESQUEMA. SI NO EXISTE, SE CREA AUTOM\00C1TICAMENTE'),
'    SELECT COUNT(*)',
'      INTO v_table_exists',
'      FROM user_tables',
'     WHERE table_name = v_table_name;',
'     ',
'    IF v_table_exists = 0 THEN',
'        BEGIN',
'            v_sql := ''CREATE TABLE '' || dbms_assert.enquote_name(v_table_name) || '' ('' ||',
'                     dbms_assert.enquote_name(v_col_id)        || '' NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, '' ||',
'                     dbms_assert.enquote_name(v_col_title)     || '' VARCHAR2(500), '' ||',
'                     dbms_assert.enquote_name(v_col_content)   || '' CLOB, '' ||',
'                     dbms_assert.enquote_name(v_col_embedding) || '' VECTOR(3072, FLOAT32), '' ||',
'                     dbms_assert.enquote_name(v_col_category)  || '' VARCHAR2(255) '' ||',
'                     '')'';',
'            EXECUTE IMMEDIATE v_sql;',
'            v_table_created := TRUE;',
'        EXCEPTION',
'            WHEN OTHERS THEN',
unistr('                RAISE_APPLICATION_ERROR(-20012, ''No se pudo crear la tabla RAG autom\00E1ticamente ('' || v_table_name || ''): '' || SQLERRM);'),
'        END;',
'    END IF;',
'    -- 4.5. AUTOMATIC CLEANUP OF PREVIOUS CHUNKS OR CONTINUATION CALCULATION (Auto-Update RAG)',
'    IF v_write_mode = ''REPLACE'' THEN',
'        -- Replace Mode: If chunks already exist, we delete them before inserting the new version.',
'        BEGIN',
'            v_sql := ''DELETE FROM '' || dbms_assert.enquote_name(v_table_name) || ',
'                     '' WHERE '' || dbms_assert.enquote_name(v_col_title) || '' = :1 '' ||',
'                     ''    OR '' || dbms_assert.enquote_name(v_col_title) || '' LIKE :2'';',
'            EXECUTE IMMEDIATE v_sql USING v_doc_title, v_doc_title || '' [Part %'';',
'        EXCEPTION',
'            WHEN OTHERS THEN',
'                NULL;',
'        END;',
'    ELSE',
'        -- Append Mode: Calculate how many parts already exist to continue the v_num counter correctly',
'        BEGIN',
'            v_sql := ''SELECT COUNT(*) FROM '' || dbms_assert.enquote_name(v_table_name) || ',
'                     '' WHERE '' || dbms_assert.enquote_name(v_col_title) || '' = :1 '' ||',
'                     ''    OR '' || dbms_assert.enquote_name(v_col_title) || '' LIKE :2'';',
'            EXECUTE IMMEDIATE v_sql INTO v_existing_count USING v_doc_title, v_doc_title || '' [Part %'';',
'            v_num := v_existing_count + 1;',
'        EXCEPTION',
'            WHEN OTHERS THEN',
'                v_num := 1;',
'        END;',
'    END IF;',
unistr('    -- 5. CHUNKING DIN\00C1MICO Y CARGA DE VECTORES'),
'    v_len := DBMS_LOB.GETLENGTH(v_doc_content);',
'    ',
'    WHILE v_pos <= v_len LOOP',
'        -- Obtener fragmento (chunk)',
'        v_chunk := DBMS_LOB.SUBSTR(v_doc_content, v_chunk_sz, v_pos);',
'        ',
'        -- Obtener vector de Gemini embeddings',
'        v_embedding := get_embedding(v_chunk, v_api_key);',
'        ',
unistr('        -- Insertar en la tabla mapeada de forma din\00E1mica y segura'),
'        v_sql := ''INSERT INTO '' || dbms_assert.enquote_name(v_table_name) || '' ('' ||',
'                 dbms_assert.enquote_name(v_col_title)     || '', '' ||',
'                 dbms_assert.enquote_name(v_col_content)   || '', '' ||',
'                 dbms_assert.enquote_name(v_col_embedding) || '', '' ||',
'                 dbms_assert.enquote_name(v_col_category)  || '') VALUES (:1, :2, :3, :4)'';',
'                 ',
'        BEGIN',
'            EXECUTE IMMEDIATE v_sql USING ',
'                v_doc_title || '' [Part '' || v_num || '']'', ',
'                v_chunk, ',
'                v_embedding, ',
'                v_doc_category;',
'                ',
'            v_chunks_inserted := v_chunks_inserted + 1;',
'        EXCEPTION',
'            WHEN OTHERS THEN',
'                ROLLBACK;',
'                RAISE_APPLICATION_ERROR(-20013, ''Error inserting chunk '' || v_num || '' in '' || v_table_name || '': '' || SQLERRM);',
'        END;',
'        ',
unistr('        -- Avanzar posici\00F3n respetando el overlap'),
'        v_pos := v_pos + v_chunk_sz - v_overlap;',
'        v_num := v_num + 1;',
'    END LOOP;',
'    ',
'    COMMIT;',
'    ',
unistr('    -- Retornar mensaje de \00E9xito legible en APEX (Dynamic detailed RAG message)'),
'    v_msg := ''Knowledge base updated successfully. '';',
'    IF v_table_created THEN',
'        v_msg := v_msg || ''Table "'' || v_table_name || ''" was created. '';',
'    ELSE',
'        IF v_write_mode = ''REPLACE'' THEN',
'            v_msg := v_msg || ''Existing chunks in "'' || v_table_name || ''" were replaced (REPLACE mode). '';',
'        ELSE',
'            v_msg := v_msg || ''New chunks were appended to "'' || v_table_name || ''" (APPEND mode). '';',
'        END IF;',
'    END IF;',
'    v_msg := v_msg || v_chunks_inserted || '' chunks were automatically created and vectorized.'';',
'    ',
'    p_result.success_message := v_msg;',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        ROLLBACK;',
'        RAISE;',
'END e_execute_loader;',
''))
,p_api_version=>3
,p_execution_function=>'e_execute_loader'
,p_version_scn=>'SH256:-T1IuTcpc7s9KR44CDJE-qbOws3haCYR4Ati3IeXWX0'
,p_version_identifier=>'1.0'
,p_files_version=>2461184190732
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3574428946048951)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_static_id=>'api_key'
,p_prompt=>'Gemini API Key'
,p_apexlang_name=>'apiKey'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'AIzaSy... (Obtain yours for free at Google AI Studio).'
,p_help_text=>'The Google Gemini API Key used to authenticate requests to the gemini-embedding-2 model for vector generation.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3578310747071284)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_static_id=>'chunk_overlap'
,p_prompt=>'Chunk Overlap (Characters)'
,p_apexlang_name=>'solapamientoOverlap'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'200'
,p_is_translatable=>false
,p_examples=>'100, 200, 300'
,p_help_text=>'The number of overlapping characters shared between consecutive chunks to ensure context continuity.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3577704428068333)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_static_id=>'chunk_size'
,p_prompt=>'Chunk Size (Characters)'
,p_apexlang_name=>'tamaoDelFragmento'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'1500'
,p_is_translatable=>false
,p_examples=>'1000, 1500, 2000'
,p_help_text=>'The character limit of each text fragment (chunk) that will be generated and vectorized.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3577164382064385)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_static_id=>'item_category'
,p_prompt=>'Document Category (Page Item)'
,p_apexlang_name=>'pageItemDeCategora'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'P2_CATEGORY, P15_DEPARTMENT_ID'
,p_help_text=>'The name of the Page Item holding the category or tag value for the document (useful for selective RAG searches).'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3576557856062067)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_static_id=>'item_content'
,p_prompt=>'Document Content (Page Item)'
,p_apexlang_name=>'pageItemDelContenido'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_default_value=>'content'
,p_is_translatable=>false
,p_examples=>'P2_DOCUMENT_CONTENT, P15_CLOB_DATA'
,p_help_text=>'The name of the Page Item (Rich Text, Textarea, or File Browser) holding the CLOB content of the document to be parsed.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3575974218058185)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_static_id=>'item_title'
,p_prompt=>'Document Title (Page Item)'
,p_apexlang_name=>'pageItemDelTtulo'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_default_value=>'title'
,p_is_translatable=>false
,p_examples=>'P2_DOCUMENT_TITLE'
,p_help_text=>'The name of the Page Item holding the title, file name, or source identifier for the document being processed.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3575371503054763)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_static_id=>'target_table'
,p_prompt=>'Target Table Name'
,p_apexlang_name=>'tablaDestinoRag'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_default_value=>'rag_documents'
,p_is_translatable=>false
,p_examples=>'rag_documents'
,p_help_text=>'The database table name to load the chunks and vectors into. If the table does not exist, the plugin will automatically create it using a standardized schema.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3588625927571877)
,p_plugin_id=>wwv_flow_imp.id(3574063400042527)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_static_id=>'write_mode'
,p_prompt=>'Write Mode'
,p_apexlang_name=>'modoDeEscrituraCarga'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'REPLACE'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_examples=>'REPLACE (To overwrite modified manuals), APPEND (To continually log chat transcribing).'
,p_help_text=>'Determines the database loading behavior. REPLACE deletes any pre-existing chunks matching the document title before uploading. APPEND keeps existing chunks and continues the chunk count sequentially.'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3590288628575328)
,p_plugin_attribute_id=>wwv_flow_imp.id(3588625927571877)
,p_display_sequence=>20
,p_display_value=>'Append (Keep previous chunks)'
,p_return_value=>'APPEND'
,p_apexlang_name=>'anexarMantenerPrevios'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3589419863573587)
,p_plugin_attribute_id=>wwv_flow_imp.id(3588625927571877)
,p_display_sequence=>10
,p_display_value=>'Replace (Delete previous chunks)'
,p_return_value=>'REPLACE'
,p_apexlang_name=>'reemplazarEliminarPrevios'
);
end;
/
prompt --application/end_environment
begin
wwv_flow_imp.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false)
);
commit;
end;
/
set verify on feedback on define on
prompt  ...done
