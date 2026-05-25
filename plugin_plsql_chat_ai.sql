-- ============================================================
-- PLUGIN CHAT AI - PL/SQL Code (Plugin Inline)
-- Autor: Cristian Alcántara
-- Licencia: Gratis / Open Source
-- ============================================================
-- IMPORTANTE: 
--   Render Function Name = e_render_chat
--   AJAX Function Name   = e_ajax_chat
-- ============================================================

-- ==========================================================
-- 1. FUNCIÓN AUXILIAR: get_embedding
--    Obtiene el vector embedding de un texto via Gemini API
-- ==========================================================
FUNCTION get_embedding(
    p_texto   IN VARCHAR2, 
    p_api_key IN VARCHAR2
) RETURN VECTOR IS
    C_GEMINI_EMBED_URL CONSTANT VARCHAR2(500) := 'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent';
    C_EMBED_DIMS       CONSTANT NUMBER        := 3072;
    v_request   CLOB;
    v_response  CLOB;
    v_arr_str   CLOB;
    v_embedding VECTOR;
    v_first     BOOLEAN := TRUE;
BEGIN
    IF p_api_key IS NULL THEN
        RAISE_APPLICATION_ERROR(-20003, 'La API Key de Gemini está vacía o es nula. Por favor, ingrese su API Key en los Component Settings del Plugin en Shared Components > Plugins.');
    END IF;

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
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_api_key;

    v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url         => C_GEMINI_EMBED_URL || '?key=' || p_api_key,
        p_http_method => 'POST',
        p_body        => v_request
    );

    IF v_response LIKE '%"error"%' THEN
        RAISE_APPLICATION_ERROR(-20002, 'Gemini embedding error: ' || SUBSTR(v_response, 1, 500));
    END IF;

    DBMS_LOB.CREATETEMPORARY(v_arr_str, TRUE);

    FOR r IN (
        SELECT idx,
               REPLACE(TO_CHAR(val, 'FM999999990D9999999999999999'), ',', '.') AS val_clean
          FROM JSON_TABLE(v_response, '$.embedding.values[*]'
               COLUMNS (idx FOR ORDINALITY, val VARCHAR2(100) PATH '$'))
         ORDER BY idx
    ) LOOP
        IF v_first THEN
            DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(r.val_clean), r.val_clean);
            v_first := FALSE;
        ELSE
            DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(',' || r.val_clean), ',' || r.val_clean);
        END IF;
    END LOOP;

    v_embedding := TO_VECTOR('[' || v_arr_str || ']', C_EMBED_DIMS, FLOAT32);
    DBMS_LOB.FREETEMPORARY(v_arr_str);
    RETURN v_embedding;
EXCEPTION
    WHEN OTHERS THEN
        IF v_arr_str IS NOT NULL THEN
            DBMS_LOB.FREETEMPORARY(v_arr_str);
        END IF;
        RAISE;
END get_embedding;

-- ==========================================================
-- 2. FUNCIÓN AUXILIAR: responder_pregunta
--    Motor RAG: busca contexto vectorial y genera respuesta
-- ==========================================================
FUNCTION responder_pregunta(
    p_pregunta       IN VARCHAR2,
    p_api_key        IN VARCHAR2,
    p_tabla          IN VARCHAR2,
    p_col_id         IN VARCHAR2,
    p_col_embedding  IN VARCHAR2,
    p_col_contenido  IN VARCHAR2,
    p_col_titulo     IN VARCHAR2,
    p_col_categoria  IN VARCHAR2,
    p_categoria_val  IN VARCHAR2 DEFAULT NULL,
    p_system         IN CLOB     DEFAULT NULL,
    p_temperature    IN NUMBER   DEFAULT 0.2,
    p_max_tokens     IN NUMBER   DEFAULT 1024,
    p_model          IN VARCHAR2 DEFAULT NULL
) RETURN CLOB IS
    v_model           VARCHAR2(100)  := NVL(p_model, 'gemini-2.5-flash');
    v_gemini_chat_url VARCHAR2(1000) := 'https://generativelanguage.googleapis.com/v1beta/models/' || v_model || ':generateContent';
    v_embedding VECTOR;
    v_contexto  CLOB := '';
    v_prompt    CLOB;
    v_request   CLOB;
    v_response  CLOB;
    v_respuesta CLOB;
    v_sql       VARCHAR2(32767);
    
    TYPE t_rag_rec IS RECORD (titulo VARCHAR2(500), contenido CLOB);
    TYPE t_rag_cur IS REF CURSOR;
    c_rag       t_rag_cur;
    r_rag       t_rag_rec;
BEGIN
    v_embedding := get_embedding(p_pregunta, p_api_key);

    v_sql := 'SELECT ' || dbms_assert.enquote_name(p_col_titulo) || ', ' 
                       || dbms_assert.enquote_name(p_col_contenido) || 
             ' FROM '  || dbms_assert.enquote_name(p_tabla) || 
             ' WHERE 1=1 ';
             
    IF p_categoria_val IS NOT NULL AND p_col_categoria IS NOT NULL THEN
        v_sql := v_sql || ' AND ' || dbms_assert.enquote_name(p_col_categoria) || ' = :cat ';
    ELSE
        v_sql := v_sql || ' AND (1=1 OR :cat IS NULL) ';
    END IF;
    
    v_sql := v_sql || ' ORDER BY VECTOR_DISTANCE(' || dbms_assert.enquote_name(p_col_embedding) || ', :embed, COSINE) ASC FETCH FIRST 5 ROWS ONLY';

    OPEN c_rag FOR v_sql USING p_categoria_val, v_embedding;
    LOOP
        FETCH c_rag INTO r_rag;
        EXIT WHEN c_rag%NOTFOUND;
        v_contexto := v_contexto || '### DOCUMENT: ' || r_rag.titulo || CHR(10) || 
                                    r_rag.contenido || CHR(10) || '---' || CHR(10);
    END LOOP;
    CLOSE c_rag;

    v_prompt := '=== KNOWLEDGE CONTEXT (RAG) ===' || CHR(10) || 
                NVL(v_contexto, 'No relevant contextual information available.') || CHR(10) || 
                '=== USER QUESTION ===' || CHR(10) || p_pregunta;

    APEX_JSON.INITIALIZE_CLOB_OUTPUT;
    APEX_JSON.OPEN_OBJECT;
        APEX_JSON.OPEN_ARRAY('contents');
            APEX_JSON.OPEN_OBJECT;
                APEX_JSON.WRITE('role', 'user');
                APEX_JSON.OPEN_ARRAY('parts');
                    APEX_JSON.OPEN_OBJECT;
                        APEX_JSON.WRITE('text', p_system || CHR(10) || CHR(10) || v_prompt);
                    APEX_JSON.CLOSE_OBJECT;
                APEX_JSON.CLOSE_ARRAY;
            APEX_JSON.CLOSE_OBJECT;
        APEX_JSON.CLOSE_ARRAY;
        APEX_JSON.OPEN_OBJECT('generationConfig');
            APEX_JSON.WRITE('temperature', p_temperature);
            APEX_JSON.WRITE('maxOutputTokens', p_max_tokens);
        APEX_JSON.CLOSE_OBJECT;
    APEX_JSON.CLOSE_OBJECT;
    v_request := APEX_JSON.GET_CLOB_OUTPUT;
    APEX_JSON.FREE_OUTPUT;

    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME  := 'Content-Type';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := 'application/json';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME  := 'x-goog-api-key';
    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_api_key;

    v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
        p_url         => v_gemini_chat_url || '?key=' || p_api_key,
        p_http_method => 'POST',
        p_body        => v_request
    );

    SELECT JSON_VALUE(v_response, '$.candidates[0].content.parts[0].text')
      INTO v_respuesta FROM DUAL;

    RETURN NVL(v_respuesta, 'Sin respuesta legible del motor de IA. Depuración de API: ' || SUBSTR(v_response, 1, 300));
EXCEPTION
    WHEN OTHERS THEN 
        IF c_rag%ISOPEN THEN CLOSE c_rag; END IF;
        RETURN 'Excepción controlada en el Agente de IA: ' || SQLERRM || ' (Línea: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE || ')';
END responder_pregunta;

-- ============================================================
-- 3. CALLBACK: e_render_chat (Render Function)
--    Genera el HTML del widget de chat flotante
-- ============================================================
PROCEDURE e_render_chat (
    p_region              IN             apex_plugin.t_region,
    p_plugin              IN             apex_plugin.t_plugin,
    p_param               IN             apex_plugin.t_region_render_param,
    p_result              IN OUT NOCOPY  apex_plugin.t_region_render_result
) IS
    v_escaped_region_id  VARCHAR2(100) := apex_escape.html_attribute(COALESCE(p_region.static_id, 'R' || p_region.id));
    v_ajax_identifier    VARCHAR2(200) := apex_plugin.get_ajax_identifier;
    
    v_bot_name           VARCHAR2(100) := NVL(p_region.attributes.get_varchar2('bot_name'), 'AI Assistant');
    v_bot_subtitle       VARCHAR2(100) := NVL(p_region.attributes.get_varchar2('bot_subtitle'), 'Online');
    v_welcome_msg        VARCHAR2(500) := NVL(p_region.attributes.get_varchar2('welcome_message'), 'Hello! How can I help you today?');
    v_primary_color      VARCHAR2(30)  := p_region.attributes.get_varchar2('primary_color');
    
    -- Dos imágenes independientes
    v_widget_icon_raw    VARCHAR2(500) := p_region.attributes.get_varchar2('widget_icon_url');
    v_chat_logo_raw      VARCHAR2(500) := p_region.attributes.get_varchar2('chat_logo_url');
    
    v_widget_icon_src    VARCHAR2(1000);
    v_chat_logo_src      VARCHAR2(1000);
    v_fallback_svg       VARCHAR2(1000);
    v_first_letter       VARCHAR2(10);
BEGIN
    IF p_param.is_printer_friendly THEN
        RETURN;
    END IF;

    -- Resolver sustituciones APEX (#APP_FILES#, etc.) usando la API oficial
    IF v_widget_icon_raw IS NOT NULL THEN
        v_widget_icon_src := apex_plugin_util.replace_substitutions(p_value => v_widget_icon_raw, p_escape => FALSE);
    END IF;
    IF v_chat_logo_raw IS NOT NULL THEN
        v_chat_logo_src := apex_plugin_util.replace_substitutions(p_value => v_chat_logo_raw, p_escape => FALSE);
    END IF;
    
    -- Fallback: si no hay logo de chat, usar el archivo por defecto del plugin
    IF v_chat_logo_src IS NULL THEN
        v_chat_logo_src := p_plugin.file_prefix || 'mendobot-logo.png';
    END IF;
    
    -- SVG fallback dinámico (primera letra del nombre del bot)
    v_first_letter := UPPER(SUBSTR(v_bot_name, 1, 1));
    v_fallback_svg := 'data:image/svg+xml;utf8,<svg xmlns=%27http://www.w3.org/2000/svg%27 width=%2764%27 height=%2764%27 viewBox=%270 0 64 64%27><circle cx=%2732%27 cy=%2732%27 r=%2730%27 fill=%27' || NVL(REPLACE(v_primary_color, '#', '%23'), '%230066cc') || '%27/><text x=%2732%27 y=%2742%27 font-size=%2730%27 fill=%27white%27 text-anchor=%27middle%27 font-family=%27sans-serif%27 font-weight=%27bold%27>' || v_first_letter || '</text></svg>';

    apex_css.add_file(
        p_name      => 'mendobot-chat',
        p_directory => p_plugin.file_prefix
    );

    -- Inyectar override de color primario
    IF v_primary_color IS NOT NULL THEN
        sys.htp.prn('<style id="mendobot-color-override-' || v_escaped_region_id || '">');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' {');
        sys.htp.prn('  --mendobot-primary: ' || apex_escape.html(v_primary_color) || ';');
        sys.htp.prn('  --mendobot-primary-light: ' || apex_escape.html(v_primary_color) || '1a;');
        sys.htp.prn('}');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' .mendobot-chat-header {');
        sys.htp.prn('  background: linear-gradient(135deg, ' || apex_escape.html(v_primary_color) || ' 0%, ' || apex_escape.html(v_primary_color) || 'cc 100%);');
        sys.htp.prn('}');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' .mendobot-chat-send-btn:hover {');
        sys.htp.prn('  background-color: ' || apex_escape.html(v_primary_color) || 'cc;');
        sys.htp.prn('}');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' .mendobot-chat-trigger {');
        sys.htp.prn('  box-shadow: 0 4px 14px ' || apex_escape.html(v_primary_color) || '66;');
        sys.htp.prn('}');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' .mendobot-chat-trigger:hover {');
        sys.htp.prn('  box-shadow: 0 6px 20px ' || apex_escape.html(v_primary_color) || '80;');
        sys.htp.prn('}');
        sys.htp.prn('#mendobot-chat-container-' || v_escaped_region_id || ' .mendobot-msg-user .mendobot-msg-bubble {');
        sys.htp.prn('  box-shadow: 0 2px 6px ' || apex_escape.html(v_primary_color) || '26;');
        sys.htp.prn('}');
        sys.htp.prn('</style>');
    END IF;



    -- Prevenir FOUC (Flash of Unstyled Content) ocultando la ventana del chat inmediatamente en el renderizado
    sys.htp.prn('<style id="mendobot-fouc-prevent-' || v_escaped_region_id || '">');
    sys.htp.prn('  #mendobot-chat-window-' || v_escaped_region_id || '.mendobot-chat-hidden {');
    sys.htp.prn('    opacity: 0 !important;');
    sys.htp.prn('    visibility: hidden !important;');
    sys.htp.prn('    transform: scale(0.8) translateY(20px) !important;');
    sys.htp.prn('  }');
    sys.htp.prn('</style>');

    sys.htp.prn('<div id="mendobot-chat-container-' || v_escaped_region_id || '" style="display: none;" class="mendobot-chat-wrapper js-apex-region" data-apex-region-id="mendobot-chat-container-' || v_escaped_region_id || '">');
    
    -- ======= BOTON FLOTANTE (WIDGET) =======
    IF v_widget_icon_src IS NOT NULL THEN
        sys.htp.prn('  <button type="button" id="mendobot-chat-toggle-' || v_escaped_region_id || '" class="mendobot-chat-trigger mendobot-trigger-custom" aria-label="Abrir chat con ' || apex_escape.html(v_bot_name) || '">');
        sys.htp.prn('    <img src="' || apex_escape.html_attribute(v_widget_icon_src) || '" alt="' || apex_escape.html(v_bot_name) || '" class="mendobot-trigger-img" onerror="this.style.display=''none'';this.nextElementSibling.style.display=''block'';this.parentElement.classList.remove(''mendobot-trigger-custom'');">');
        sys.htp.prn('    <svg style="display:none" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>');
    ELSE
        sys.htp.prn('  <button type="button" id="mendobot-chat-toggle-' || v_escaped_region_id || '" class="mendobot-chat-trigger" aria-label="Abrir chat con ' || apex_escape.html(v_bot_name) || '">');
        sys.htp.prn('    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-message-square"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>');
    END IF;
    sys.htp.prn('  </button>');
    
    -- ======= VENTANA DE CHAT =======
    sys.htp.prn('  <div id="mendobot-chat-window-' || v_escaped_region_id || '" class="mendobot-chat-box mendobot-chat-hidden">');
    sys.htp.prn('    <div class="mendobot-chat-header">');
    sys.htp.prn('      <div class="mendobot-header-info">');
    sys.htp.prn('        <div class="mendobot-avatar-container">');
    IF v_chat_logo_raw IS NOT NULL THEN
        sys.htp.prn('          <img src="' || apex_escape.html_attribute(v_chat_logo_src) || '" alt="Logo ' || apex_escape.html(v_bot_name) || '" class="mendobot-avatar-logo mendobot-avatar-custom" onerror="this.src=''' || v_fallback_svg || ''';this.classList.remove(''mendobot-avatar-custom'');">');
    ELSE
        sys.htp.prn('          <img src="' || apex_escape.html_attribute(v_chat_logo_src) || '" alt="Logo ' || apex_escape.html(v_bot_name) || '" class="mendobot-avatar-logo" onerror="this.src=''' || v_fallback_svg || ''';">');
    END IF;
    sys.htp.prn('        </div>');
    sys.htp.prn('        <div class="mendobot-header-title">');
    sys.htp.prn('          <h3>' || apex_escape.html(v_bot_name) || '</h3>');
    sys.htp.prn('          <span class="mendobot-online-status"><span class="status-dot"></span>' || apex_escape.html(v_bot_subtitle) || '</span>');
    sys.htp.prn('        </div>');
    sys.htp.prn('      </div>');
    sys.htp.prn('      <button type="button" id="mendobot-chat-close-' || v_escaped_region_id || '" class="mendobot-chat-close-btn" aria-label="Cerrar chat">&times;</button>');
    sys.htp.prn('    </div>');
    
    sys.htp.prn('    <div id="mendobot-chat-messages-' || v_escaped_region_id || '" class="mendobot-chat-body">');
    sys.htp.prn('      <div class="mendobot-message mendobot-msg-bot">');
    sys.htp.prn('        <div class="mendobot-msg-bubble">');
    sys.htp.prn('          ' || apex_escape.html(v_welcome_msg));
    sys.htp.prn('        </div>');
    sys.htp.prn('        <span class="mendobot-msg-time">' || TO_CHAR(SYSDATE, 'HH24:MI') || '</span>');
    sys.htp.prn('      </div>');
    sys.htp.prn('    </div>');
    
    sys.htp.prn('    <div class="mendobot-chat-footer">');
    sys.htp.prn('      <input type="text" id="mendobot-chat-input-' || v_escaped_region_id || '" class="mendobot-chat-input-text" placeholder="Escribe tu mensaje..." autocomplete="off">');
    sys.htp.prn('      <button type="button" id="mendobot-chat-send-' || v_escaped_region_id || '" class="mendobot-chat-send-btn" aria-label="Enviar mensaje">');
    sys.htp.prn('        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-send"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>');
    sys.htp.prn('      </button>');
    sys.htp.prn('    </div>');
    sys.htp.prn('  </div>');
    sys.htp.prn('</div>');

    apex_javascript.add_library(
        p_name      => 'mendobot-chat',
        p_directory => p_plugin.file_prefix
    );
    
    apex_javascript.add_onload_code(
        p_code => 'mendobotChatInit(''' || v_escaped_region_id || ''', ''' || v_ajax_identifier || ''', ''' || p_region.id || ''');'
    );
END e_render_chat;


-- ============================================================
-- 4. CALLBACK: e_ajax_chat (AJAX Function)
--    Procesa las consultas del usuario y retorna respuesta IA
-- ============================================================
PROCEDURE e_ajax_chat (
    p_region              IN             apex_plugin.t_region,
    p_plugin              IN             apex_plugin.t_plugin,
    p_param               IN             apex_plugin.t_region_ajax_param,
    p_result              IN OUT NOCOPY  apex_plugin.t_region_ajax_result
) IS
    v_pregunta       VARCHAR2(32767);
    v_respuesta      CLOB;
    v_resp_str       VARCHAR2(32767);
    v_coleccion      CONSTANT VARCHAR2(30) := 'AI_CHAT_SESSION_MEMORIA';
    
    v_api_key        VARCHAR2(200);
    v_chat_model     VARCHAR2(100);
    v_tabla          VARCHAR2(100);
    v_col_id         VARCHAR2(100);
    v_col_embed      VARCHAR2(100);
    v_col_cont       VARCHAR2(100);
    v_col_doc        VARCHAR2(100);
    v_col_cat        VARCHAR2(100);
    v_limite_chats   NUMBER;
    
    v_bot_name       VARCHAR2(100);
    v_bot_role       CLOB;
    v_bot_tone       VARCHAR2(100);
    
    v_cat_item_name  VARCHAR2(100);

    v_cat_val        VARCHAR2(255);
    v_historial_clob CLOB;
    v_system_prompt  CLOB;
    
    v_debug_msg      VARCHAR2(4000);
BEGIN
    OWA_UTIL.MIME_HEADER('application/json', FALSE);
    HTP.P('Cache-Control: no-cache');
    OWA_UTIL.HTTP_HEADER_CLOSE;

    -- =====================================================
    -- RECUPERACIÓN DE ATRIBUTOS (Static IDs del plugin)
    -- =====================================================
    -- Recuperar API Key (busca primero en Component Settings del Plugin, luego en la Región)
    v_api_key      := NVL(p_plugin.attributes.get_varchar2('api_key'), p_region.attributes.get_varchar2('api_key'));
    
    -- Recuperar Modelo de Chat (busca en la Región, luego en Component Settings del Plugin, por defecto gemini-2.5-flash)
    v_chat_model   := COALESCE(
                        p_region.attributes.get_varchar2('chat_model'),
                        p_plugin.attributes.get_varchar2('chat_model'),
                        'gemini-2.5-flash'
                      );
    v_tabla        := p_region.attributes.get_varchar2('rag_table');
    v_col_id       := p_region.attributes.get_varchar2('col_id');
    v_col_embed    := p_region.attributes.get_varchar2('col_embedding');
    v_col_cont     := p_region.attributes.get_varchar2('col_content');
    v_col_doc      := p_region.attributes.get_varchar2('col_title');
    v_col_cat      := p_region.attributes.get_varchar2('col_category');
    v_limite_chats := NVL(p_region.attributes.get_number('chat_limit'), 10);
    v_bot_name     := NVL(p_region.attributes.get_varchar2('bot_name'), 'AI Assistant');
    v_bot_role     := NVL(p_region.attributes.get_varchar2('bot_role'), 'Intelligent virtual assistant.');
    v_bot_tone     := NVL(p_region.attributes.get_varchar2('bot_tone'), 'Professional and friendly');
    v_cat_item_name := p_region.attributes.get_varchar2('category_item');

    v_pregunta := apex_application.g_x01;

    IF v_pregunta IS NULL OR TRIM(v_pregunta) = '' THEN
        HTP.PRN('{"success": false, "respuesta": "Por favor ingrese su consulta."}');
        RETURN;
    END IF;

    -- =====================================================
    -- VALIDACIÓN: Atributos obligatorios para RAG
    -- =====================================================
    v_debug_msg := '';
    IF v_api_key IS NULL THEN v_debug_msg := v_debug_msg || 'API Key (api_key), '; END IF;
    IF v_tabla IS NULL THEN v_debug_msg := v_debug_msg || 'Tabla RAG (rag_table), '; END IF;
    IF v_col_id IS NULL THEN v_debug_msg := v_debug_msg || 'Col ID (col_id), '; END IF;
    IF v_col_embed IS NULL THEN v_debug_msg := v_debug_msg || 'Col Embedding (col_embedding), '; END IF;
    IF v_col_cont IS NULL THEN v_debug_msg := v_debug_msg || 'Col Contenido (col_content), '; END IF;
    IF v_col_doc IS NULL THEN v_debug_msg := v_debug_msg || 'Col Titulo (col_title), '; END IF;

    IF v_debug_msg IS NOT NULL THEN
        HTP.PRN('{"success": false, "respuesta": "Error de Configuración: Los siguientes atributos del plugin están vacíos: ' || apex_escape.json(RTRIM(v_debug_msg, ', ')) || '. Verifique la configuración de Custom Attributes en Shared Components > Plugins y que cada atributo tenga un valor en la región del Page Designer o en Component Settings del Plugin."}');
        RETURN;
    END IF;

    -- PASO A: RECUPERACIÓN DE MEMORIA SESIÓN (APEX_COLLECTION)
    IF NOT apex_collection.collection_exists(v_coleccion) THEN
        apex_collection.create_collection(v_coleccion);
    END IF;

    FOR r_mem IN (
        SELECT c001 AS preg, c002 AS resp 
          FROM (
              SELECT c001, c002, seq_id 
                FROM apex_collections 
               WHERE collection_name = v_coleccion
               ORDER BY seq_id DESC
          )
         WHERE ROWNUM <= v_limite_chats
         ORDER BY seq_id ASC
    ) LOOP
        v_historial_clob := v_historial_clob || 'Usuario: ' || r_mem.preg || CHR(10) || 
                                                v_bot_name || ': ' || r_mem.resp || CHR(10) || '---' || CHR(10);
    END LOOP;

    -- STEP B: ASSEMBLE SYSTEM PROMPT WITH STRICT BUSINESS RULES
    v_system_prompt := 
        '=== BOT IDENTITY ===' || CHR(10) ||
        'Name: ' || v_bot_name || CHR(10) ||
        'Role and Goal: ' || v_bot_role || CHR(10) ||
        'Tone: ' || v_bot_tone || CHR(10) || CHR(10) ||
        '=== [CRITICAL RESPONSE RULES] ===' || CHR(10) ||
        '- Answer based ONLY on the attached KNOWLEDGE CONTEXT (RAG).' || CHR(10) ||
        '- If the provided context does not contain the information to answer the question, say exactly: "I am sorry, but I do not have official information in my knowledge base to answer your query." and stop immediately.' || CHR(10) ||
        '- PROHIBITED to use unnecessary introductory words like "Based on...", "According to the document...", etc.' || CHR(10) ||
        '- PROHIBITED to guess, assume or reference external information not provided in the RAG.' || CHR(10) ||
        '- Be direct and maintain a clean conversational flow.' || CHR(10) || CHR(10) ||
        '=== ACTIVE CONVERSATION MEMORY (Limit: ' || v_limite_chats || ' chats) ===' || CHR(10) ||
        NVL(v_historial_clob, 'No previous interactions.') || CHR(10) || '---';

    IF v_cat_item_name IS NOT NULL THEN
        v_cat_val := V(v_cat_item_name);
    END IF;

    -- PASO C: LLAMAR AL MOTOR DE BÚSQUEDA VECTORIAL E IA (RAG)
    v_respuesta := responder_pregunta(
        p_pregunta      => v_pregunta,
        p_api_key       => v_api_key,
        p_tabla         => v_tabla,
        p_col_id        => v_col_id,
        p_col_embedding => v_col_embed,
        p_col_contenido => v_col_cont,
        p_col_titulo    => v_col_doc,
        p_col_categoria => v_col_cat,
        p_categoria_val => v_cat_val,
        p_system        => v_system_prompt,
        p_temperature   => 0.2,
        p_max_tokens    => 1024,
        p_model         => v_chat_model
    );

    v_resp_str := DBMS_LOB.SUBSTR(v_respuesta, 32000, 1);

    -- PASO D: PERSISTENCIA EN MEMORIA DE SESIÓN Y AUDITORÍA
    apex_collection.add_member(
        p_collection_name => v_coleccion,
        p_c001            => v_pregunta,
        p_c002            => v_resp_str
    );

    BEGIN
        INSERT INTO ai_chat_historial (usuario, pregunta, respuesta)
        VALUES (NVL(V('APP_USER'), 'ANONYMOUS'), v_pregunta, v_resp_str);
    EXCEPTION
        WHEN OTHERS THEN
            APEX_DEBUG.ERROR('No se pudo guardar la auditoría física del chat: ' || SQLERRM);
    END;

    -- PASO E: RETORNAR RESPUESTA JSON SEGURA AL CLIENTE
    BEGIN 
        apex_json.free_output; 
    EXCEPTION 
        WHEN OTHERS THEN NULL; 
    END;

    HTP.PRN('{"success": true, "respuesta": "' || apex_escape.json(v_resp_str) || '"}');
    RETURN;
EXCEPTION
    WHEN OTHERS THEN
        v_resp_str := 'Fallo crítico inesperado en el componente de comunicación: ' || SQLERRM;
        BEGIN apex_json.free_output; EXCEPTION WHEN OTHERS THEN NULL; END;
        HTP.PRN('{"success": false, "respuesta": "' || apex_escape.json(v_resp_str) || '"}');
        RETURN;
END e_ajax_chat;
