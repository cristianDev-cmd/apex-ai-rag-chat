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
--     PLUGIN: 2585571389823303
--   Manifest End
--   Version:         26.1.0
--   Instance ID:     743364194531067
--

begin
  -- replace components
  wwv_flow_imp.g_mode := 'REPLACE';
end;
/
prompt --application/shared_components/plugins/region_type/com_mendobot_chat_ai
begin
wwv_flow_imp_shared.create_plugin(
 p_id=>wwv_flow_imp.id(2585571389823303)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.MENDOBOT.CHAT.AI'
,p_display_name=>'Plugin Chat AI'
,p_apexlang_name=>'botPluginChatAi'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- ============================================================',
'-- PLUGIN CHAT AI - PL/SQL Code (Plugin Inline)',
unistr('-- Autor: Cristian Alc\00E1ntara'),
'-- Licencia: Gratis / Open Source',
'-- ============================================================',
'-- IMPORTANTE: ',
'--   Render Function Name = e_render_chat',
'--   AJAX Function Name   = e_ajax_chat',
'-- ============================================================',
'-- ==========================================================',
unistr('-- 1. FUNCI\00D3N AUXILIAR: get_embedding'),
'--    Obtiene el vector embedding de un texto via Gemini API',
'-- ==========================================================',
'FUNCTION get_embedding(',
'    p_texto   IN VARCHAR2, ',
'    p_api_key IN VARCHAR2',
') RETURN VECTOR IS',
'    C_GEMINI_EMBED_URL CONSTANT VARCHAR2(500) := ''https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent'';',
'    C_EMBED_DIMS       CONSTANT NUMBER        := 3072;',
'    v_request   CLOB;',
'    v_response  CLOB;',
'    v_arr_str   CLOB;',
'    v_embedding VECTOR;',
'    v_first     BOOLEAN := TRUE;',
'BEGIN',
'    IF p_api_key IS NULL THEN',
unistr('        RAISE_APPLICATION_ERROR(-20003, ''La API Key de Gemini est\00E1 vac\00EDa o es nula. Por favor, ingrese su API Key en los Component Settings del Plugin en Shared Components > Plugins.'');'),
'    END IF;',
'    APEX_JSON.INITIALIZE_CLOB_OUTPUT;',
'    APEX_JSON.OPEN_OBJECT;',
'        APEX_JSON.OPEN_OBJECT(''content'');',
'            APEX_JSON.OPEN_ARRAY(''parts'');',
'                APEX_JSON.OPEN_OBJECT;',
'                    APEX_JSON.WRITE(''text'', p_texto);',
'                APEX_JSON.CLOSE_OBJECT;',
'            APEX_JSON.CLOSE_ARRAY;',
'        APEX_JSON.CLOSE_OBJECT;',
'    APEX_JSON.CLOSE_OBJECT;',
'    v_request := APEX_JSON.GET_CLOB_OUTPUT;',
'    APEX_JSON.FREE_OUTPUT;',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME  := ''Content-Type'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''application/json'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME  := ''x-goog-api-key'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_api_key;',
'    v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(',
'        p_url         => C_GEMINI_EMBED_URL || ''?key='' || p_api_key,',
'        p_http_method => ''POST'',',
'        p_body        => v_request',
'    );',
'    IF v_response LIKE ''%"error"%'' THEN',
'        RAISE_APPLICATION_ERROR(-20002, ''Gemini embedding error: '' || SUBSTR(v_response, 1, 500));',
'    END IF;',
'    DBMS_LOB.CREATETEMPORARY(v_arr_str, TRUE);',
'    FOR r IN (',
'        SELECT idx,',
'               REPLACE(TO_CHAR(val, ''FM999999990D9999999999999999''), '','', ''.'') AS val_clean',
'          FROM JSON_TABLE(v_response, ''$.embedding.values[*]''',
'               COLUMNS (idx FOR ORDINALITY, val VARCHAR2(100) PATH ''$''))',
'         ORDER BY idx',
'    ) LOOP',
'        IF v_first THEN',
'            DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH(r.val_clean), r.val_clean);',
'            v_first := FALSE;',
'        ELSE',
'            DBMS_LOB.WRITEAPPEND(v_arr_str, LENGTH('','' || r.val_clean), '','' || r.val_clean);',
'        END IF;',
'    END LOOP;',
'    v_embedding := TO_VECTOR(''['' || v_arr_str || '']'', C_EMBED_DIMS, FLOAT32);',
'    DBMS_LOB.FREETEMPORARY(v_arr_str);',
'    RETURN v_embedding;',
'EXCEPTION',
'    WHEN OTHERS THEN',
'        IF v_arr_str IS NOT NULL THEN',
'            DBMS_LOB.FREETEMPORARY(v_arr_str);',
'        END IF;',
'        RAISE;',
'END get_embedding;',
'-- ==========================================================',
unistr('-- 2. FUNCI\00D3N AUXILIAR: responder_pregunta'),
'--    Motor RAG: busca contexto vectorial y genera respuesta',
'-- ==========================================================',
'FUNCTION responder_pregunta(',
'    p_pregunta       IN VARCHAR2,',
'    p_api_key        IN VARCHAR2,',
'    p_tabla          IN VARCHAR2,',
'    p_col_id         IN VARCHAR2,',
'    p_col_embedding  IN VARCHAR2,',
'    p_col_contenido  IN VARCHAR2,',
'    p_col_titulo     IN VARCHAR2,',
'    p_col_categoria  IN VARCHAR2,',
'    p_categoria_val  IN VARCHAR2 DEFAULT NULL,',
'    p_system         IN CLOB     DEFAULT NULL,',
'    p_temperature    IN NUMBER   DEFAULT 0.2,',
'    p_max_tokens     IN NUMBER   DEFAULT 1024,',
'    p_model          IN VARCHAR2 DEFAULT NULL',
') RETURN CLOB IS',
'    v_model           VARCHAR2(100)  := NVL(p_model, ''gemini-2.5-flash'');',
'    v_gemini_chat_url VARCHAR2(1000) := ''https://generativelanguage.googleapis.com/v1beta/models/'' || v_model || '':generateContent'';',
'    v_embedding VECTOR;',
'    v_contexto  CLOB := '''';',
'    v_prompt    CLOB;',
'    v_request   CLOB;',
'    v_response  CLOB;',
'    v_respuesta CLOB;',
'    v_sql       VARCHAR2(32767);',
'    ',
'    TYPE t_rag_rec IS RECORD (titulo VARCHAR2(500), contenido CLOB);',
'    TYPE t_rag_cur IS REF CURSOR;',
'    c_rag       t_rag_cur;',
'    r_rag       t_rag_rec;',
'BEGIN',
'    v_embedding := get_embedding(p_pregunta, p_api_key);',
'    v_sql := ''SELECT '' || dbms_assert.enquote_name(p_col_titulo) || '', '' ',
'                       || dbms_assert.enquote_name(p_col_contenido) || ',
'             '' FROM ''  || dbms_assert.enquote_name(p_tabla) || ',
'             '' WHERE 1=1 '';',
'             ',
'    IF p_categoria_val IS NOT NULL AND p_col_categoria IS NOT NULL THEN',
'        v_sql := v_sql || '' AND '' || dbms_assert.enquote_name(p_col_categoria) || '' = :cat '';',
'    ELSE',
'        v_sql := v_sql || '' AND (1=1 OR :cat IS NULL) '';',
'    END IF;',
'    ',
'    v_sql := v_sql || '' ORDER BY VECTOR_DISTANCE('' || dbms_assert.enquote_name(p_col_embedding) || '', :embed, COSINE) ASC FETCH FIRST 5 ROWS ONLY'';',
'    OPEN c_rag FOR v_sql USING p_categoria_val, v_embedding;',
'    LOOP',
'        FETCH c_rag INTO r_rag;',
'        EXIT WHEN c_rag%NOTFOUND;',
'        v_contexto := v_contexto || ''### DOCUMENT: '' || r_rag.titulo || CHR(10) || ',
'                                    r_rag.contenido || CHR(10) || ''---'' || CHR(10);',
'    END LOOP;',
'    CLOSE c_rag;',
'    v_prompt := ''=== KNOWLEDGE CONTEXT (RAG) ==='' || CHR(10) || ',
'                NVL(v_contexto, ''No relevant contextual information available.'') || CHR(10) || ',
'                ''=== USER QUESTION ==='' || CHR(10) || p_pregunta;',
'    APEX_JSON.INITIALIZE_CLOB_OUTPUT;',
'    APEX_JSON.OPEN_OBJECT;',
'        APEX_JSON.OPEN_ARRAY(''contents'');',
'            APEX_JSON.OPEN_OBJECT;',
'                APEX_JSON.WRITE(''role'', ''user'');',
'                APEX_JSON.OPEN_ARRAY(''parts'');',
'                    APEX_JSON.OPEN_OBJECT;',
'                        APEX_JSON.WRITE(''text'', p_system || CHR(10) || CHR(10) || v_prompt);',
'                    APEX_JSON.CLOSE_OBJECT;',
'                APEX_JSON.CLOSE_ARRAY;',
'            APEX_JSON.CLOSE_OBJECT;',
'        APEX_JSON.CLOSE_ARRAY;',
'        APEX_JSON.OPEN_OBJECT(''generationConfig'');',
'            APEX_JSON.WRITE(''temperature'', p_temperature);',
'            APEX_JSON.WRITE(''maxOutputTokens'', p_max_tokens);',
'        APEX_JSON.CLOSE_OBJECT;',
'    APEX_JSON.CLOSE_OBJECT;',
'    v_request := APEX_JSON.GET_CLOB_OUTPUT;',
'    APEX_JSON.FREE_OUTPUT;',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS.DELETE;',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).NAME  := ''Content-Type'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(1).VALUE := ''application/json'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).NAME  := ''x-goog-api-key'';',
'    APEX_WEB_SERVICE.G_REQUEST_HEADERS(2).VALUE := p_api_key;',
'    v_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(',
'        p_url         => v_gemini_chat_url || ''?key='' || p_api_key,',
'        p_http_method => ''POST'',',
'        p_body        => v_request',
'    );',
'    SELECT JSON_VALUE(v_response, ''$.candidates[0].content.parts[0].text'')',
'      INTO v_respuesta FROM DUAL;',
unistr('    RETURN NVL(v_respuesta, ''Sin respuesta legible del motor de IA. Depuraci\00F3n de API: '' || SUBSTR(v_response, 1, 300));'),
'EXCEPTION',
'    WHEN OTHERS THEN ',
'        IF c_rag%ISOPEN THEN CLOSE c_rag; END IF;',
unistr('        RETURN ''Excepci\00F3n controlada en el Agente de IA: '' || SQLERRM || '' (L\00EDnea: '' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE || '')'';'),
'END responder_pregunta;',
'-- ============================================================',
'-- 3. CALLBACK: e_render_chat (Render Function)',
'--    Genera el HTML del widget de chat flotante',
'-- ============================================================',
'PROCEDURE e_render_chat (',
'    p_region              IN             apex_plugin.t_region,',
'    p_plugin              IN             apex_plugin.t_plugin,',
'    p_param               IN             apex_plugin.t_region_render_param,',
'    p_result              IN OUT NOCOPY  apex_plugin.t_region_render_result',
') IS',
'    v_escaped_region_id  VARCHAR2(100) := apex_escape.html_attribute(COALESCE(p_region.static_id, ''R'' || p_region.id));',
'    v_ajax_identifier    VARCHAR2(200) := apex_plugin.get_ajax_identifier;',
'    ',
'    v_bot_name           VARCHAR2(100) := NVL(p_region.attributes.get_varchar2(''bot_name''), ''AI Assistant'');',
'    v_bot_subtitle       VARCHAR2(100) := NVL(p_region.attributes.get_varchar2(''bot_subtitle''), ''Online'');',
'    v_welcome_msg        VARCHAR2(500) := NVL(p_region.attributes.get_varchar2(''welcome_message''), ''Hello! How can I help you today?'');',
'    v_primary_color      VARCHAR2(30)  := p_region.attributes.get_varchar2(''primary_color'');',
'    ',
unistr('    -- Dos im\00E1genes independientes'),
'    v_widget_icon_raw    VARCHAR2(500) := p_region.attributes.get_varchar2(''widget_icon_url'');',
'    v_chat_logo_raw      VARCHAR2(500) := p_region.attributes.get_varchar2(''chat_logo_url'');',
'    ',
'    v_widget_icon_src    VARCHAR2(1000);',
'    v_chat_logo_src      VARCHAR2(1000);',
'    v_fallback_svg       VARCHAR2(1000);',
'    v_first_letter       VARCHAR2(10);',
'BEGIN',
'    IF p_param.is_printer_friendly THEN',
'        RETURN;',
'    END IF;',
'    -- Resolver sustituciones APEX (#APP_FILES#, etc.) usando la API oficial',
'    IF v_widget_icon_raw IS NOT NULL THEN',
'        v_widget_icon_src := apex_plugin_util.replace_substitutions(p_value => v_widget_icon_raw, p_escape => FALSE);',
'    END IF;',
'    IF v_chat_logo_raw IS NOT NULL THEN',
'        v_chat_logo_src := apex_plugin_util.replace_substitutions(p_value => v_chat_logo_raw, p_escape => FALSE);',
'    END IF;',
'    ',
'    -- Fallback: si no hay logo de chat, usar el archivo por defecto del plugin',
'    IF v_chat_logo_src IS NULL THEN',
'        v_chat_logo_src := p_plugin.file_prefix || ''mendobot-logo.png'';',
'    END IF;',
'    ',
unistr('    -- SVG fallback din\00E1mico (primera letra del nombre del bot)'),
'    v_first_letter := UPPER(SUBSTR(v_bot_name, 1, 1));',
'    v_fallback_svg := ''data:image/svg+xml;utf8,<svg xmlns=%27http://www.w3.org/2000/svg%27 width=%2764%27 height=%2764%27 viewBox=%270 0 64 64%27><circle cx=%2732%27 cy=%2732%27 r=%2730%27 fill=%27'' || NVL(REPLACE(v_primary_color, ''#'', ''%23''), ''%2300'
||'66cc'') || ''%27/><text x=%2732%27 y=%2742%27 font-size=%2730%27 fill=%27white%27 text-anchor=%27middle%27 font-family=%27sans-serif%27 font-weight=%27bold%27>'' || v_first_letter || ''</text></svg>'';',
'    apex_css.add_file(',
'        p_name      => ''mendobot-chat'',',
'        p_directory => p_plugin.file_prefix',
'    );',
'    -- Inyectar override de color primario',
'    IF v_primary_color IS NOT NULL THEN',
'        sys.htp.prn(''<style id="mendobot-color-override-'' || v_escaped_region_id || ''">'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' {'');',
'        sys.htp.prn(''  --mendobot-primary: '' || apex_escape.html(v_primary_color) || '';'');',
'        sys.htp.prn(''  --mendobot-primary-light: '' || apex_escape.html(v_primary_color) || ''1a;'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' .mendobot-chat-header {'');',
'        sys.htp.prn(''  background: linear-gradient(135deg, '' || apex_escape.html(v_primary_color) || '' 0%, '' || apex_escape.html(v_primary_color) || ''cc 100%);'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' .mendobot-chat-send-btn:hover {'');',
'        sys.htp.prn(''  background-color: '' || apex_escape.html(v_primary_color) || ''cc;'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' .mendobot-chat-trigger {'');',
'        sys.htp.prn(''  box-shadow: 0 4px 14px '' || apex_escape.html(v_primary_color) || ''66;'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' .mendobot-chat-trigger:hover {'');',
'        sys.htp.prn(''  box-shadow: 0 6px 20px '' || apex_escape.html(v_primary_color) || ''80;'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''#mendobot-chat-container-'' || v_escaped_region_id || '' .mendobot-msg-user .mendobot-msg-bubble {'');',
'        sys.htp.prn(''  box-shadow: 0 2px 6px '' || apex_escape.html(v_primary_color) || ''26;'');',
'        sys.htp.prn(''}'');',
'        sys.htp.prn(''</style>'');',
'    END IF;',
'    -- Prevenir FOUC (Flash of Unstyled Content) ocultando la ventana del chat inmediatamente en el renderizado',
'    sys.htp.prn(''<style id="mendobot-fouc-prevent-'' || v_escaped_region_id || ''">'');',
'    sys.htp.prn(''  #mendobot-chat-window-'' || v_escaped_region_id || ''.mendobot-chat-hidden {'');',
'    sys.htp.prn(''    opacity: 0 !important;'');',
'    sys.htp.prn(''    visibility: hidden !important;'');',
'    sys.htp.prn(''    transform: scale(0.8) translateY(20px) !important;'');',
'    sys.htp.prn(''  }'');',
'    sys.htp.prn(''</style>'');',
'    sys.htp.prn(''<div id="mendobot-chat-container-'' || v_escaped_region_id || ''" style="display: none;" class="mendobot-chat-wrapper js-apex-region" data-apex-region-id="mendobot-chat-container-'' || v_escaped_region_id || ''">'');',
'    ',
'    -- ======= BOTON FLOTANTE (WIDGET) =======',
'    IF v_widget_icon_src IS NOT NULL THEN',
'        sys.htp.prn(''  <button type="button" id="mendobot-chat-toggle-'' || v_escaped_region_id || ''" class="mendobot-chat-trigger mendobot-trigger-custom" aria-label="Abrir chat con '' || apex_escape.html(v_bot_name) || ''">'');',
'        sys.htp.prn(''    <img src="'' || apex_escape.html_attribute(v_widget_icon_src) || ''" alt="'' || apex_escape.html(v_bot_name) || ''" class="mendobot-trigger-img" onerror="this.style.display=''''none'''';this.nextElementSibling.style.display=''''block'''''
||';this.parentElement.classList.remove(''''mendobot-trigger-custom'''');">'');',
'        sys.htp.prn(''    <svg style="display:none" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 '
||'2 0 0 1 2 2z"></path></svg>'');',
'    ELSE',
'        sys.htp.prn(''  <button type="button" id="mendobot-chat-toggle-'' || v_escaped_region_id || ''" class="mendobot-chat-trigger" aria-label="Abrir chat con '' || apex_escape.html(v_bot_name) || ''">'');',
'        sys.htp.prn(''    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-message-square"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2'
||' 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path></svg>'');',
'    END IF;',
'    sys.htp.prn(''  </button>'');',
'    ',
'    -- ======= VENTANA DE CHAT =======',
'    sys.htp.prn(''  <div id="mendobot-chat-window-'' || v_escaped_region_id || ''" class="mendobot-chat-box mendobot-chat-hidden">'');',
'    sys.htp.prn(''    <div class="mendobot-chat-header">'');',
'    sys.htp.prn(''      <div class="mendobot-header-info">'');',
'    sys.htp.prn(''        <div class="mendobot-avatar-container">'');',
'    IF v_chat_logo_raw IS NOT NULL THEN',
'        sys.htp.prn(''          <img src="'' || apex_escape.html_attribute(v_chat_logo_src) || ''" alt="Logo '' || apex_escape.html(v_bot_name) || ''" class="mendobot-avatar-logo mendobot-avatar-custom" onerror="this.src='''''' || v_fallback_svg || '''''';this.'
||'classList.remove(''''mendobot-avatar-custom'''');">'');',
'    ELSE',
'        sys.htp.prn(''          <img src="'' || apex_escape.html_attribute(v_chat_logo_src) || ''" alt="Logo '' || apex_escape.html(v_bot_name) || ''" class="mendobot-avatar-logo" onerror="this.src='''''' || v_fallback_svg || '''''';">'');',
'    END IF;',
'    sys.htp.prn(''        </div>'');',
'    sys.htp.prn(''        <div class="mendobot-header-title">'');',
'    sys.htp.prn(''          <h3>'' || apex_escape.html(v_bot_name) || ''</h3>'');',
'    sys.htp.prn(''          <span class="mendobot-online-status"><span class="status-dot"></span>'' || apex_escape.html(v_bot_subtitle) || ''</span>'');',
'    sys.htp.prn(''        </div>'');',
'    sys.htp.prn(''      </div>'');',
'    sys.htp.prn(''      <button type="button" id="mendobot-chat-close-'' || v_escaped_region_id || ''" class="mendobot-chat-close-btn" aria-label="Cerrar chat">&times;</button>'');',
'    sys.htp.prn(''    </div>'');',
'    ',
'    sys.htp.prn(''    <div id="mendobot-chat-messages-'' || v_escaped_region_id || ''" class="mendobot-chat-body">'');',
'    ',
'    -- Mensaje de bienvenida inicial',
'    sys.htp.prn(''      <div class="mendobot-message mendobot-msg-bot">'');',
'    sys.htp.prn(''        <div class="mendobot-msg-bubble">'');',
'    sys.htp.prn(''          '' || apex_escape.html(v_welcome_msg));',
'    sys.htp.prn(''        </div>'');',
'    sys.htp.prn(''        <span class="mendobot-msg-time">'' || TO_CHAR(SYSDATE, ''HH24:MI'') || ''</span>'');',
'    sys.htp.prn(''      </div>'');',
'    ',
unistr('    -- Cargar mensajes previos desde la colecci\00F3n si existen'),
'    IF apex_collection.collection_exists(''AI_CHAT_SESSION_MEMORIA'') THEN',
'        FOR r_hist IN (',
'            SELECT c001 AS preg, c002 AS resp, seq_id',
'              FROM apex_collections',
'             WHERE collection_name = ''AI_CHAT_SESSION_MEMORIA''',
'             ORDER BY seq_id ASC',
'        ) LOOP',
'            -- Burbuja del usuario',
'            sys.htp.prn(''      <div class="mendobot-message mendobot-msg-user">'');',
'            sys.htp.prn(''        <div class="mendobot-msg-bubble">'');',
'            sys.htp.prn(''          '' || apex_escape.html(r_hist.preg));',
'            sys.htp.prn(''        </div>'');',
'            sys.htp.prn(''        <span class="mendobot-msg-time">'' || TO_CHAR(SYSDATE, ''HH24:MI'') || ''</span>'');',
'            sys.htp.prn(''      </div>'');',
'            ',
'            -- Burbuja del bot',
'            sys.htp.prn(''      <div class="mendobot-message mendobot-msg-bot">'');',
'            sys.htp.prn(''        <div class="mendobot-msg-bubble">'');',
unistr('            sys.htp.prn(''          '' || r_hist.resp); -- La respuesta ya est\00E1 formateada o limpia del RAG'),
'            sys.htp.prn(''        </div>'');',
'            sys.htp.prn(''        <span class="mendobot-msg-time">'' || TO_CHAR(SYSDATE, ''HH24:MI'') || ''</span>'');',
'            sys.htp.prn(''      </div>'');',
'        END LOOP;',
'    END IF;',
'    ',
'    sys.htp.prn(''    </div>'');',
'    ',
'    sys.htp.prn(''    <div class="mendobot-chat-footer">'');',
'    sys.htp.prn(''      <input type="text" id="mendobot-chat-input-'' || v_escaped_region_id || ''" class="mendobot-chat-input-text" placeholder="Escribe tu mensaje..." autocomplete="off">'');',
'    sys.htp.prn(''      <button type="button" id="mendobot-chat-send-'' || v_escaped_region_id || ''" class="mendobot-chat-send-btn" aria-label="Enviar mensaje">'');',
'    sys.htp.prn(''        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-send"><line x1="22" y1="2" x2="11" y2="13"></line><polyg'
||'on points="22 2 15 22 11 13 2 9 22 2"></polygon></svg>'');',
'    sys.htp.prn(''      </button>'');',
'    sys.htp.prn(''    </div>'');',
'    sys.htp.prn(''  </div>'');',
'    sys.htp.prn(''</div>'');',
'    apex_javascript.add_library(',
'        p_name      => ''mendobot-chat'',',
'        p_directory => p_plugin.file_prefix',
'    );',
'    ',
'    apex_javascript.add_onload_code(',
'        p_code => ''mendobotChatInit('''''' || v_escaped_region_id || '''''', '''''' || v_ajax_identifier || '''''', '''''' || p_region.id || '''''');''',
'    );',
'END e_render_chat;',
'-- ============================================================',
'-- 4. CALLBACK: e_ajax_chat (AJAX Function)',
'--    Procesa las consultas del usuario y retorna respuesta IA',
'-- ============================================================',
'PROCEDURE e_ajax_chat (',
'    p_region              IN             apex_plugin.t_region,',
'    p_plugin              IN             apex_plugin.t_plugin,',
'    p_param               IN             apex_plugin.t_region_ajax_param,',
'    p_result              IN OUT NOCOPY  apex_plugin.t_region_ajax_result',
') IS',
'    v_pregunta       VARCHAR2(32767);',
'    v_respuesta      CLOB;',
'    v_resp_str       VARCHAR2(32767);',
'    v_coleccion      CONSTANT VARCHAR2(30) := ''AI_CHAT_SESSION_MEMORIA'';',
'    ',
'    v_api_key        VARCHAR2(200);',
'    v_chat_model     VARCHAR2(100);',
'    v_tabla          VARCHAR2(100);',
'    v_col_id         VARCHAR2(100);',
'    v_col_embed      VARCHAR2(100);',
'    v_col_cont       VARCHAR2(100);',
'    v_col_doc        VARCHAR2(100);',
'    v_col_cat        VARCHAR2(100);',
'    v_limite_chats   NUMBER;',
'    ',
'    v_bot_name       VARCHAR2(100);',
'    v_bot_role       CLOB;',
'    v_bot_tone       VARCHAR2(100);',
'    ',
'    v_cat_item_name  VARCHAR2(100);',
'    v_cat_val        VARCHAR2(255);',
'    v_historial_clob CLOB;',
'    v_system_prompt  CLOB;',
'    ',
'    v_debug_msg      VARCHAR2(4000);',
'BEGIN',
'    OWA_UTIL.MIME_HEADER(''application/json'', FALSE);',
'    HTP.P(''Cache-Control: no-cache'');',
'    OWA_UTIL.HTTP_HEADER_CLOSE;',
'    -- =====================================================',
unistr('    -- RECUPERACI\00D3N DE ATRIBUTOS (Static IDs del plugin)'),
'    -- =====================================================',
unistr('    -- Recuperar API Key (busca primero en Component Settings del Plugin, luego en la Regi\00F3n)'),
'    v_api_key      := NVL(p_plugin.attributes.get_varchar2(''api_key''), p_region.attributes.get_varchar2(''api_key''));',
'    ',
unistr('    -- Recuperar Modelo de Chat (busca en la Regi\00F3n, luego en Component Settings del Plugin, por defecto gemini-2.5-flash)'),
'    v_chat_model   := COALESCE(',
'                        p_region.attributes.get_varchar2(''chat_model''),',
'                        p_plugin.attributes.get_varchar2(''chat_model''),',
'                        ''gemini-2.5-flash''',
'                      );',
'    v_tabla        := p_region.attributes.get_varchar2(''rag_table'');',
'    v_col_id       := p_region.attributes.get_varchar2(''col_id'');',
'    v_col_embed    := p_region.attributes.get_varchar2(''col_embedding'');',
'    v_col_cont     := p_region.attributes.get_varchar2(''col_content'');',
'    v_col_doc      := p_region.attributes.get_varchar2(''col_title'');',
'    v_col_cat      := p_region.attributes.get_varchar2(''col_category'');',
'    v_limite_chats := NVL(p_region.attributes.get_number(''chat_limit''), 10);',
'    v_bot_name     := NVL(p_region.attributes.get_varchar2(''bot_name''), ''AI Assistant'');',
'    v_bot_role     := NVL(p_region.attributes.get_varchar2(''bot_role''), ''Intelligent virtual assistant.'');',
'    v_bot_tone     := NVL(p_region.attributes.get_varchar2(''bot_tone''), ''Professional and friendly'');',
'    v_cat_item_name := p_region.attributes.get_varchar2(''category_item'');',
'    v_pregunta := apex_application.g_x01;',
'    IF v_pregunta IS NULL OR TRIM(v_pregunta) = '''' THEN',
'        HTP.PRN(''{"success": false, "respuesta": "Por favor ingrese su consulta."}'');',
'        RETURN;',
'    END IF;',
'    -- =====================================================',
unistr('    -- VALIDACI\00D3N: Atributos obligatorios para RAG'),
'    -- =====================================================',
'    v_debug_msg := '''';',
'    IF v_api_key IS NULL THEN v_debug_msg := v_debug_msg || ''API Key (api_key), ''; END IF;',
'    IF v_tabla IS NULL THEN v_debug_msg := v_debug_msg || ''Tabla RAG (rag_table), ''; END IF;',
'    IF v_col_id IS NULL THEN v_debug_msg := v_debug_msg || ''Col ID (col_id), ''; END IF;',
'    IF v_col_embed IS NULL THEN v_debug_msg := v_debug_msg || ''Col Embedding (col_embedding), ''; END IF;',
'    IF v_col_cont IS NULL THEN v_debug_msg := v_debug_msg || ''Col Contenido (col_content), ''; END IF;',
'    IF v_col_doc IS NULL THEN v_debug_msg := v_debug_msg || ''Col Titulo (col_title), ''; END IF;',
'    IF v_debug_msg IS NOT NULL THEN',
unistr('        HTP.PRN(''{"success": false, "respuesta": "Error de Configuraci\00F3n: Los siguientes atributos del plugin est\00E1n vac\00EDos: '' || apex_escape.json(RTRIM(v_debug_msg, '', '')) || ''. Verifique la configuraci\00F3n de Custom Attributes en Shared Components > P')
||unistr('lugins y que cada atributo tenga un valor en la regi\00F3n del Page Designer o en Component Settings del Plugin."}'');'),
'        RETURN;',
'    END IF;',
unistr('    -- PASO A: RECUPERACI\00D3N DE MEMORIA SESI\00D3N (APEX_COLLECTION)'),
'    IF NOT apex_collection.collection_exists(v_coleccion) THEN',
'        apex_collection.create_collection(v_coleccion);',
'    END IF;',
'    FOR r_mem IN (',
'        SELECT c001 AS preg, c002 AS resp ',
'          FROM (',
'              SELECT c001, c002, seq_id ',
'                FROM apex_collections ',
'               WHERE collection_name = v_coleccion',
'               ORDER BY seq_id DESC',
'          )',
'         WHERE ROWNUM <= v_limite_chats',
'         ORDER BY seq_id ASC',
'    ) LOOP',
'        v_historial_clob := v_historial_clob || ''Usuario: '' || r_mem.preg || CHR(10) || ',
'                                                v_bot_name || '': '' || r_mem.resp || CHR(10) || ''---'' || CHR(10);',
'    END LOOP;',
'    -- STEP B: ASSEMBLE SYSTEM PROMPT WITH STRICT BUSINESS RULES',
'    v_system_prompt := ',
'        ''=== BOT IDENTITY ==='' || CHR(10) ||',
'        ''Name: '' || v_bot_name || CHR(10) ||',
'        ''Role and Goal: '' || v_bot_role || CHR(10) ||',
'        ''Tone: '' || v_bot_tone || CHR(10) || CHR(10) ||',
'        ''=== [CRITICAL RESPONSE RULES] ==='' || CHR(10) ||',
'        ''- Answer based ONLY on the attached KNOWLEDGE CONTEXT (RAG).'' || CHR(10) ||',
'        ''- If the provided context does not contain the information to answer the question, say exactly: "I am sorry, but I do not have official information in my knowledge base to answer your query." and stop immediately.'' || CHR(10) ||',
'        ''- PROHIBITED to use unnecessary introductory words like "Based on...", "According to the document...", etc.'' || CHR(10) ||',
'        ''- PROHIBITED to guess, assume or reference external information not provided in the RAG.'' || CHR(10) ||',
'        ''- Be direct and maintain a clean conversational flow.'' || CHR(10) || CHR(10) ||',
'        ''=== ACTIVE CONVERSATION MEMORY (Limit: '' || v_limite_chats || '' chats) ==='' || CHR(10) ||',
'        NVL(v_historial_clob, ''No previous interactions.'') || CHR(10) || ''---'';',
'    IF v_cat_item_name IS NOT NULL THEN',
'        v_cat_val := V(v_cat_item_name);',
'    END IF;',
unistr('    -- PASO C: LLAMAR AL MOTOR DE B\00DASQUEDA VECTORIAL E IA (RAG)'),
'    v_respuesta := responder_pregunta(',
'        p_pregunta      => v_pregunta,',
'        p_api_key       => v_api_key,',
'        p_tabla         => v_tabla,',
'        p_col_id        => v_col_id,',
'        p_col_embedding => v_col_embed,',
'        p_col_contenido => v_col_cont,',
'        p_col_titulo    => v_col_doc,',
'        p_col_categoria => v_col_cat,',
'        p_categoria_val => v_cat_val,',
'        p_system        => v_system_prompt,',
'        p_temperature   => 0.2,',
'        p_max_tokens    => 1024,',
'        p_model         => v_chat_model',
'    );',
'    v_resp_str := DBMS_LOB.SUBSTR(v_respuesta, 32000, 1);',
unistr('    -- PASO D: PERSISTENCIA EN MEMORIA DE SESI\00D3N Y AUDITOR\00CDA'),
'    apex_collection.add_member(',
'        p_collection_name => v_coleccion,',
'        p_c001            => v_pregunta,',
'        p_c002            => v_resp_str',
'    );',
'    -- Audit logging removed per user request (only using session collection memory)',
'    NULL;',
'    -- PASO E: RETORNAR RESPUESTA JSON SEGURA AL CLIENTE',
'    BEGIN ',
'        apex_json.free_output; ',
'    EXCEPTION ',
'        WHEN OTHERS THEN NULL; ',
'    END;',
'    HTP.PRN(''{"success": true, "respuesta": "'' || apex_escape.json(v_resp_str) || ''"}'');',
'    RETURN;',
'EXCEPTION',
'    WHEN OTHERS THEN',
unistr('        v_resp_str := ''Fallo cr\00EDtico inesperado en el componente de comunicaci\00F3n: '' || SQLERRM;'),
'        BEGIN apex_json.free_output; EXCEPTION WHEN OTHERS THEN NULL; END;',
'        HTP.PRN(''{"success": false, "respuesta": "'' || apex_escape.json(v_resp_str) || ''"}'');',
'        RETURN;',
'END e_ajax_chat;',
''))
,p_api_version=>3
,p_render_function=>'e_render_chat'
,p_ajax_function=>'e_ajax_chat'
,p_version_scn=>'SH256:Zvwj_8HY895ugIkEkcaPkY2LBfHY-nCwcBgo_HkFNBw'
,p_version_identifier=>'1.0'
,p_files_version=>2461186180142
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3544830017021298)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_static_id=>'api_key'
,p_prompt=>'Gemini API Key'
,p_apexlang_name=>'geminiApiKey'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_is_translatable=>false
,p_examples=>'AIzaSy... (Obtain yours for free at Google AI Studio).'
,p_help_text=>'The private Google Gemini API Key used to authenticate calls to the LLM and the embeddings engine.'
,p_attribute_comment=>'Se configura globalmente una sola vez en Component Settings.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2594256020865936)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_static_id=>'bot_name'
,p_prompt=>'Bot Name'
,p_apexlang_name=>'nombreDelBot'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'AI Assistant, Customer Support'
,p_help_text=>'The public name of the chatbot displayed in the header of the chat window.'
,p_attribute_comment=>'Nombre identificativo en la interfaz de usuario.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2594834860869235)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_static_id=>'bot_role'
,p_prompt=>'Bot Role'
,p_apexlang_name=>'rolobjetivoDelBot'
,p_attribute_type=>'TEXTAREA'
,p_is_required=>false
,p_default_value=>'Intelligent virtual assistant.'
,p_is_translatable=>false
,p_examples=>'You are an expert IT support engineer. Be polite, concise, and guide users step-by-step through network troubleshooting.'
,p_help_text=>'System instructions defining the AI''s persona, objectives, scope, and behavior. Act as the System Prompt.'
,p_attribute_comment=>'Establece las reglas del juego de comportamiento de la IA.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3553973405439399)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>20
,p_display_sequence=>200
,p_static_id=>'bot_subtitle'
,p_prompt=>'Bot Subtitle'
,p_apexlang_name=>'subttuloDelBot'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'Online, Support Team, Virtual Agent'
,p_help_text=>'Text displayed beneath the Bot Name in the chat header, next to the green status dot.'
,p_attribute_comment=>' Opcional, ideal para dar mayor realismo al chat.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3642964605635849)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>21
,p_display_sequence=>210
,p_static_id=>'bot_tone'
,p_prompt=>'Conversation Tone'
,p_apexlang_name=>'conversationTone'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_default_value=>'Professional and friendly'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_examples=>'Professional and friendly, Empathetic and conversational, Technical and concise'
,p_help_text=>'The writing style and emotional tone the AI chatbot will use when responding to user messages.'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3644841159648087)
,p_plugin_attribute_id=>wwv_flow_imp.id(3642964605635849)
,p_display_sequence=>20
,p_display_value=>'Empathetic and conversational'
,p_return_value=>'Empathetic and conversational'
,p_apexlang_name=>'empatheticAndConversational'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3643766336641759)
,p_plugin_attribute_id=>wwv_flow_imp.id(3642964605635849)
,p_display_sequence=>10
,p_display_value=>'Professional and friendly'
,p_return_value=>'Professional and friendly'
,p_apexlang_name=>'professionalAndFriendly'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3645656855649602)
,p_plugin_attribute_id=>wwv_flow_imp.id(3642964605635849)
,p_display_sequence=>30
,p_display_value=>'Technical and concise'
,p_return_value=>'Technical and concise'
,p_apexlang_name=>'technicalAndConcise'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2598696486888671)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_static_id=>'category_item'
,p_prompt=>'Category Filter (Page Item)'
,p_apexlang_name=>'pageItemDeCategoraFiltro'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'P1_CATEGORY'
,p_help_text=>'The name of the Page Item (e.g., a select list or text field) holding the category value to dynamically filter the RAG search.'
,p_attribute_comment=>unistr('Debe hacer referencia a un item v\00E1lido en la p\00E1gina actual.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2593697780863595)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_static_id=>'chat_limit'
,p_prompt=>'Chat Memory Limit'
,p_apexlang_name=>'lmiteDeChatsMemoria'
,p_attribute_type=>'INTEGER'
,p_is_required=>false
,p_default_value=>'3'
,p_is_translatable=>false
,p_examples=>'3, 5, 10'
,p_help_text=>'The maximum number of historical conversation turns (question/answer pairs) that the bot will remember to maintain context.'
,p_attribute_comment=>unistr('A mayor n\00FAmero, m\00E1s tokens consumir\00E1 el prompt. Un l\00EDmite entre 3 y 5 es \00F3ptimo para balancear velocidad y memoria.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3539185314593492)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>19
,p_display_sequence=>190
,p_static_id=>'chat_logo_url'
,p_prompt=>'Chat Avatar Logo (URL)'
,p_apexlang_name=>'logoDelChatUrl'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'#APP_FILES#bot-avatar-logo.png, https://myserver.com/avatar.png'
,p_help_text=>'The URL of the logo/avatar image displayed in the header of the chat box. Supports APEX static file strings.'
,p_attribute_comment=>unistr('Resoluci\00F3n recomendada: PNG transparente de 64x64px. Si se deja vac\00EDo, genera un fallback din\00E1mico con la inicial del bot.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3549195687071933)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'APPLICATION'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_static_id=>'chat_model'
,p_prompt=>'AI Model'
,p_apexlang_name=>'modeloIa'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>false
,p_default_value=>'gemini-2.5-flash'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_examples=>'gemini-2.5-flash (Recommended for speed and cost-efficiency), gemini-2.5-pro (For highly complex reasoning).'
,p_help_text=>'The default Gemini Generative AI Model to be used for processing user queries and generating RAG responses.'
,p_attribute_comment=>unistr('Se puede sobrescribir opcionalmente a nivel de regi\00F3n.')
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3549957355192520)
,p_plugin_attribute_id=>wwv_flow_imp.id(3549195687071933)
,p_display_sequence=>10
,p_display_value=>'Gemini 2.5 Flash'
,p_return_value=>'gemini-2.5-flash'
,p_apexlang_name=>'gemini25Flash'
);
wwv_flow_imp_shared.create_plugin_attr_value(
 p_id=>wwv_flow_imp.id(3550720753197979)
,p_plugin_attribute_id=>wwv_flow_imp.id(3549195687071933)
,p_display_sequence=>20
,p_display_value=>'Gemini 2.5 Pro'
,p_return_value=>'gemini-2.5-pro'
,p_apexlang_name=>'gemini25Pro'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2593055472860328)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_static_id=>'col_category'
,p_prompt=>'Category Column'
,p_apexlang_name=>'columnaCategora'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'category'
,p_is_translatable=>false
,p_examples=>'category'
,p_help_text=>'The database column name used to filter document chunks by a specific classification or context.'
,p_attribute_comment=>unistr('Permite limitar la b\00FAsqueda vectorial solo a la categor\00EDa seleccionada por el usuario.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2591869156856553)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_static_id=>'col_content'
,p_prompt=>'Content Column'
,p_apexlang_name=>'columnaContenidoClob'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'content'
,p_is_translatable=>false
,p_examples=>'content'
,p_help_text=>'The database column name (CLOB or VARCHAR2) storing the raw text segment of the document chunk.'
,p_attribute_comment=>unistr('Es la informaci\00F3n exacta que se inyectar\00E1 como contexto para responder la pregunta.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2591266145854389)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_static_id=>'col_embedding'
,p_prompt=>'Embedding Column'
,p_apexlang_name=>'columnaEmbeddingVector'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'embedding'
,p_is_translatable=>false
,p_examples=>'embedding, vector_content'
,p_help_text=>'The database column name storing the Oracle vector data (type VECTOR).'
,p_attribute_comment=>'Almacena el vector generado con modelos de embeddings como gemini-embedding-2.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2590604829852498)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_static_id=>'col_id'
,p_prompt=>'ID Column'
,p_apexlang_name=>'columnaId'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'id'
,p_is_translatable=>false
,p_examples=>'id, document_id'
,p_help_text=>'The primary key column name of the RAG knowledge table.'
,p_attribute_comment=>'Soporta tipos VARCHAR2 y NUMBER.'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2592475272858544)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_static_id=>'col_title'
,p_prompt=>'Title Column'
,p_apexlang_name=>'columnaTtulo'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'title'
,p_is_translatable=>false
,p_examples=>'title'
,p_help_text=>'The database column name storing the title or source name of the document chunk.'
,p_attribute_comment=>unistr('Ayuda al orden y la comprensi\00F3n lectora del modelo de lenguaje.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3533928748509738)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>17
,p_display_sequence=>170
,p_static_id=>'primary_color'
,p_prompt=>'Primary Color'
,p_apexlang_name=>'colorPrimario'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'#0066cc (Classic Blue), #ea580c (Orange), #059669 (Green), #7c3aed (Purple).'
,p_help_text=>'Hexadecimal (HEX) color code to customize the chatbot''s primary interface elements (header gradient, user bubbles, button hover, etc.).'
,p_attribute_comment=>unistr('El plugin calcula autom\00E1ticamente los matices claros y sombras a partir de este color.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2590069070850202)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_static_id=>'rag_table'
,p_prompt=>'RAG Table Name'
,p_apexlang_name=>'tablaDeConocimientoRag'
,p_attribute_type=>'TEXT'
,p_is_required=>true
,p_default_value=>'rag_documents'
,p_is_translatable=>false
,p_examples=>'rag_documents'
,p_help_text=>'The database table or view name containing the vectorized knowledge base for Retrieval-Augmented Generation (RAG).'
,p_attribute_comment=>'La tabla debe contener columnas de tipo VECTOR (nativo de Oracle 23c/23ai).'
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(2598025622885197)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_static_id=>'welcome_message'
,p_prompt=>'Welcome Message'
,p_apexlang_name=>'mensajeDeBienvenida'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'Hello! How can I help you today?'
,p_is_translatable=>false
,p_examples=>'Welcome to the Helpdesk! What can I help you with today?'
,p_help_text=>'The automatic greeting message displayed to the user as soon as the chat widget is opened for the first time.'
,p_attribute_comment=>unistr('Texto est\00E1tico de bienvenida.')
);
wwv_flow_imp_shared.create_plugin_attribute(
 p_id=>wwv_flow_imp.id(3538259303591382)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>18
,p_display_sequence=>180
,p_static_id=>'widget_icon_url'
,p_prompt=>'Widget Icon (URL)'
,p_apexlang_name=>'iconoDelWidgetUrl'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_is_translatable=>false
,p_examples=>'#APP_FILES#bot-widget-icon.png, https://myserver.com/icon.png'
,p_help_text=>'The URL of the image to display in the floating widget button. Supports APEX static file strings.'
,p_attribute_comment=>unistr('Resoluci\00F3n recomendada: PNG transparente de 128x128px. Si se deja vac\00EDo, usa un icono SVG est\00E1ndar.')
);
end;
/
begin
wwv_flow_imp.g_varchar2_table := wwv_flow_imp.empty_varchar2_table;
wwv_flow_imp.g_varchar2_table(1) := '2F2A2A0A202A20504C5547494E2043484154204149202D204D4F4445524E20474C4153534D4F52504849534D204353530A202A204175746F723A20437269737469616E20416C63C3A16E746172610A202A204C6963656E6369613A20477261746973202F';
wwv_flow_imp.g_varchar2_table(2) := '204F70656E20536F757263650A202A204169736C61646F206D656469616E7465206E6F6D656E636C61747572612070726566696A61646120706172612065766974617220636F6C6973696F6E65732E0A202A20496E7465677261646F20636F6E20656C20';
wwv_flow_imp.g_varchar2_table(3) := '73697374656D61206465206D6172636120626C616E6361206465204150455820556E6976657273616C205468656D652E0A202A2F0A3A726F6F74207B0A202020202D2D6D656E646F626F742D7072696D6172793A20766172282D2D612D70616C65747465';
wwv_flow_imp.g_varchar2_table(4) := '2D7072696D6172792C2023303036366363293B0A202020202D2D6D656E646F626F742D7072696D6172792D6C696768743A20766172282D2D612D70616C657474652D7072696D6172792D6C696768742C207267626128302C203130322C203230342C2030';
wwv_flow_imp.g_varchar2_table(5) := '2E3129293B0A202020202D2D6D656E646F626F742D62673A20766172282D2D612D63762D737572666163652D636F6C6F722C2023666666666666293B0A202020202D2D6D656E646F626F742D746578743A20766172282D2D612D63762D746578742D636F';
wwv_flow_imp.g_varchar2_table(6) := '6C6F722C2023316632393337293B0A202020202D2D6D656E646F626F742D626F726465723A20766172282D2D612D63762D626F726465722D636F6C6F722C2023653565376562293B0A202020202D2D6D656E646F626F742D736861646F773A2030203130';
wwv_flow_imp.g_varchar2_table(7) := '70782032357078202D357078207267626128302C20302C20302C20302E31292C2030203870782031307078202D367078207267626128302C20302C20302C20302E31293B0A202020202D2D6D656E646F626F742D666F6E743A20766172282D2D612D666F';
wwv_flow_imp.g_varchar2_table(8) := '6E742D66616D696C792C202D6170706C652D73797374656D2C20426C696E6B4D616353797374656D466F6E742C20225365676F65205549222C20526F626F746F2C2048656C7665746963612C20417269616C2C2073616E732D7365726966293B0A7D0A2E';
wwv_flow_imp.g_varchar2_table(9) := '6D656E646F626F742D636861742D77726170706572207B0A20202020706F736974696F6E3A2066697865643B0A20202020626F74746F6D3A20323470783B0A2020202072696768743A20323470783B0A202020207A2D696E6465783A20393939393B0A20';
wwv_flow_imp.g_varchar2_table(10) := '202020666F6E742D66616D696C793A20766172282D2D6D656E646F626F742D666F6E74293B0A20202020646973706C61793A20626C6F636B2021696D706F7274616E743B0A7D0A2F2A20426F74C3B36E20666C6F74616E74652064697370617261646F72';
wwv_flow_imp.g_varchar2_table(11) := '2064656C2063686174202A2F0A2E6D656E646F626F742D636861742D74726967676572207B0A2020202077696474683A20353670783B0A202020206865696768743A20353670783B0A20202020626F726465722D7261646975733A203530253B0A202020';
wwv_flow_imp.g_varchar2_table(12) := '206261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B0A20202020636F6C6F723A20236666666666663B0A20202020626F726465723A206E6F6E653B0A20202020637572736F723A20706F696E7465';
wwv_flow_imp.g_varchar2_table(13) := '723B0A20202020626F782D736861646F773A203020347078203134707820766172282D2D612D70616C657474652D7072696D6172792D6C696768742C207267626128302C203130322C203230342C20302E3429293B0A20202020646973706C61793A2066';
wwv_flow_imp.g_varchar2_table(14) := '6C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A202020206A7573746966792D636F6E74656E743A2063656E7465723B0A202020207472616E736974696F6E3A20616C6C20302E33732063756269632D62657A69657228302E34';
wwv_flow_imp.g_varchar2_table(15) := '2C20302C20302E322C2031293B0A7D0A2E6D656E646F626F742D636861742D747269676765723A686F766572207B0A202020207472616E73666F726D3A207363616C6528312E303829207472616E736C61746559282D327078293B0A20202020626F782D';
wwv_flow_imp.g_varchar2_table(16) := '736861646F773A203020367078203230707820766172282D2D612D70616C657474652D7072696D6172792D6C696768742C207267626128302C203130322C203230342C20302E3529293B0A7D0A2E6D656E646F626F742D636861742D747269676765723A';
wwv_flow_imp.g_varchar2_table(17) := '616374697665207B0A202020207472616E73666F726D3A207363616C6528302E3935293B0A7D0A2F2A20536F706F72746520706172612069636F6E6F20706572736F6E616C697A61646F3A20656C696D696E6120666F6E646F2C20736F6D6272612C2062';
wwv_flow_imp.g_varchar2_table(18) := '6F72646520792070736575646F2D656C656D656E746F732064656C2074656D61202A2F0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D2C0A2E6D656E646F626F742D636861742D74';
wwv_flow_imp.g_varchar2_table(19) := '7269676765722E6D656E646F626F742D747269676765722D637573746F6D3A686F7665722C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F6375732C0A2E6D656E646F626F';
wwv_flow_imp.g_varchar2_table(20) := '742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F6375732D76697369626C652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D';
wwv_flow_imp.g_varchar2_table(21) := '3A616374697665207B0A202020206261636B67726F756E643A207472616E73706172656E742021696D706F7274616E743B0A202020206261636B67726F756E642D636F6C6F723A207472616E73706172656E742021696D706F7274616E743B0A20202020';
wwv_flow_imp.g_varchar2_table(22) := '626F782D736861646F773A206E6F6E652021696D706F7274616E743B0A2020202070616464696E673A20302021696D706F7274616E743B0A20202020626F726465723A206E6F6E652021696D706F7274616E743B0A202020206F75746C696E653A206E6F';
wwv_flow_imp.g_varchar2_table(23) := '6E652021696D706F7274616E743B0A7D0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E64';
wwv_flow_imp.g_varchar2_table(24) := '6F626F742D747269676765722D637573746F6D3A3A61667465722C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A686F7665723A3A6265666F72652C0A2E6D656E646F626F742D';
wwv_flow_imp.g_varchar2_table(25) := '636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A686F7665723A3A61667465722C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F';
wwv_flow_imp.g_varchar2_table(26) := '6375733A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F6375733A3A61667465722C0A2E6D656E646F626F742D636861742D747269676765722E6D656E';
wwv_flow_imp.g_varchar2_table(27) := '646F626F742D747269676765722D637573746F6D3A6163746976653A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A6163746976653A3A6166746572207B0A';
wwv_flow_imp.g_varchar2_table(28) := '20202020646973706C61793A206E6F6E652021696D706F7274616E743B0A20202020636F6E74656E743A206E6F6E652021696D706F7274616E743B0A202020206261636B67726F756E643A207472616E73706172656E742021696D706F7274616E743B0A';
wwv_flow_imp.g_varchar2_table(29) := '202020206261636B67726F756E642D636F6C6F723A207472616E73706172656E742021696D706F7274616E743B0A20202020626F782D736861646F773A206E6F6E652021696D706F7274616E743B0A20202020626F726465723A206E6F6E652021696D70';
wwv_flow_imp.g_varchar2_table(30) := '6F7274616E743B0A7D0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D202E6D656E646F626F742D747269676765722D696D67207B0A2020202077696474683A20353670783B0A2020';
wwv_flow_imp.g_varchar2_table(31) := '20206865696768743A20353670783B0A202020206F626A6563742D6669743A20636F6E7461696E3B0A20202020626F726465722D7261646975733A20302021696D706F7274616E743B0A20202020626F726465723A206E6F6E652021696D706F7274616E';
wwv_flow_imp.g_varchar2_table(32) := '743B0A7D0A2F2A2056656E74616E61206465206368617420666C6F74616E74652028476C6173736D6F72706869736D29202A2F0A2E6D656E646F626F742D636861742D626F78207B0A20202020706F736974696F6E3A206162736F6C7574653B0A202020';
wwv_flow_imp.g_varchar2_table(33) := '20626F74746F6D3A20373270783B0A2020202072696768743A20303B0A2020202077696474683A2033383070783B0A202020206865696768743A2035323070783B0A202020206261636B67726F756E642D636F6C6F723A2072676261283235352C203235';
wwv_flow_imp.g_varchar2_table(34) := '352C203235352C20302E3935293B0A202020206261636B64726F702D66696C7465723A20626C75722831307078293B0A202020202D7765626B69742D6261636B64726F702D66696C7465723A20626C75722831307078293B0A20202020626F726465723A';
wwv_flow_imp.g_varchar2_table(35) := '2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B0A20202020626F726465722D7261646975733A20313670783B0A20202020626F782D736861646F773A20766172282D2D6D656E646F626F742D736861646F77293B0A';
wwv_flow_imp.g_varchar2_table(36) := '20202020646973706C61793A20666C65783B0A20202020666C65782D646972656374696F6E3A20636F6C756D6E3B0A202020206F766572666C6F773A2068696464656E3B0A202020207472616E736974696F6E3A20616C6C20302E33732063756269632D';
wwv_flow_imp.g_varchar2_table(37) := '62657A69657228302E342C20302C20302E322C2031293B0A202020207472616E73666F726D2D6F726967696E3A20626F74746F6D2072696768743B0A7D0A2E6D656E646F626F742D636861742D68696464656E207B0A202020206F7061636974793A2030';
wwv_flow_imp.g_varchar2_table(38) := '3B0A202020207669736962696C6974793A2068696464656E3B0A202020207472616E73666F726D3A207363616C6528302E3829207472616E736C617465592832307078293B0A20202020706F696E7465722D6576656E74733A206E6F6E653B0A7D0A2F2A';
wwv_flow_imp.g_varchar2_table(39) := '20456E636162657A61646F2064656C2043686174202A2F0A2E6D656E646F626F742D636861742D686561646572207B0A2020202070616464696E673A20313670783B0A202020206261636B67726F756E643A206C696E6561722D6772616469656E742831';
wwv_flow_imp.g_varchar2_table(40) := '33356465672C20766172282D2D6D656E646F626F742D7072696D617279292030252C207267626128302C2037372C203135332C20302E39292031303025293B0A20202020636F6C6F723A20236666666666663B0A20202020646973706C61793A20666C65';
wwv_flow_imp.g_varchar2_table(41) := '783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A202020206A7573746966792D636F6E74656E743A2073706163652D6265747765656E3B0A20202020626F782D736861646F773A2030203270782031307078207267626128302C302C';
wwv_flow_imp.g_varchar2_table(42) := '302C302E3035293B0A7D0A2E6D656E646F626F742D6865616465722D696E666F207B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A7D0A2E6D656E646F626F742D6176617461722D636F';
wwv_flow_imp.g_varchar2_table(43) := '6E7461696E6572207B0A20202020706F736974696F6E3A2072656C61746976653B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A7D0A2F2A20416E696D616369C3B36E20737574696C20';
wwv_flow_imp.g_varchar2_table(44) := '646520726573706972616369C3B36E207920726573706C616E646F72207061726120656C206C6F676F202A2F0A406B65796672616D657320626F7450756C7365207B0A202020203025207B207472616E73666F726D3A207363616C652831293B2066696C';
wwv_flow_imp.g_varchar2_table(45) := '7465723A2064726F702D736861646F7728302030203270782072676261283235352C3235352C3235352C302E3229293B207D0A20202020353025207B207472616E73666F726D3A207363616C6528312E3035293B2066696C7465723A2064726F702D7368';
wwv_flow_imp.g_varchar2_table(46) := '61646F7728302030203870782072676261283235352C3235352C3235352C302E3729293B207D0A2020202031303025207B207472616E73666F726D3A207363616C652831293B2066696C7465723A2064726F702D736861646F7728302030203270782072';
wwv_flow_imp.g_varchar2_table(47) := '676261283235352C3235352C3235352C302E3229293B207D0A7D0A2E6D656E646F626F742D6176617461722D6C6F676F207B0A2020202077696474683A20333270783B0A202020206865696768743A20333270783B0A20202020626F726465722D726164';
wwv_flow_imp.g_varchar2_table(48) := '6975733A203530253B0A202020206F626A6563742D6669743A20636F7665723B0A20202020626F726465723A2032707820736F6C69642072676261283235352C3235352C3235352C302E38293B0A20202020616E696D6174696F6E3A20626F7450756C73';
wwv_flow_imp.g_varchar2_table(49) := '652031307320696E66696E69746520656173652D696E2D6F75743B0A202020206D617267696E2D72696768743A20313270783B0A7D0A2F2A20536F706F7274652070617261206C6F676F206465206368617420706572736F6E616C697A61646F3A20656C';
wwv_flow_imp.g_varchar2_table(50) := '696D696E6120626F72646520626C616E636F2C20616E696D616369C3B36E2079207265646F6E64616D69656E746F202A2F0A2E6D656E646F626F742D6176617461722D6C6F676F2E6D656E646F626F742D6176617461722D637573746F6D207B0A202020';
wwv_flow_imp.g_varchar2_table(51) := '20626F726465723A206E6F6E652021696D706F7274616E743B0A20202020626F726465722D7261646975733A20302021696D706F7274616E743B0A20202020616E696D6174696F6E3A206E6F6E652021696D706F7274616E743B0A20202020626F782D73';
wwv_flow_imp.g_varchar2_table(52) := '6861646F773A206E6F6E652021696D706F7274616E743B0A202020206F626A6563742D6669743A20636F6E7461696E2021696D706F7274616E743B0A7D0A2E6D656E646F626F742D6865616465722D7469746C65206833207B0A202020206D617267696E';
wwv_flow_imp.g_varchar2_table(53) := '3A20303B0A20202020666F6E742D73697A653A20313570783B0A20202020666F6E742D7765696768743A203630303B0A202020206C65747465722D73706163696E673A20302E3370783B0A20202020636F6C6F723A20236666666666663B0A7D0A2E6D65';
wwv_flow_imp.g_varchar2_table(54) := '6E646F626F742D6F6E6C696E652D737461747573207B0A20202020666F6E742D73697A653A20313170783B0A202020206F7061636974793A20302E38353B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063';
wwv_flow_imp.g_varchar2_table(55) := '656E7465723B0A202020206D617267696E2D746F703A203270783B0A7D0A2E7374617475732D646F74207B0A2020202077696474683A203670783B0A202020206865696768743A203670783B0A202020206261636B67726F756E642D636F6C6F723A2023';
wwv_flow_imp.g_varchar2_table(56) := '3130623938313B0A20202020626F726465722D7261646975733A203530253B0A202020206D617267696E2D72696768743A203670783B0A20202020646973706C61793A20696E6C696E652D626C6F636B3B0A7D0A2E6D656E646F626F742D636861742D63';
wwv_flow_imp.g_varchar2_table(57) := '6C6F73652D62746E207B0A202020206261636B67726F756E643A206E6F6E653B0A20202020626F726465723A206E6F6E653B0A20202020636F6C6F723A20236666666666663B0A20202020666F6E742D73697A653A20323470783B0A2020202063757273';
wwv_flow_imp.g_varchar2_table(58) := '6F723A20706F696E7465723B0A202020206C696E652D6865696768743A20313B0A202020206F7061636974793A20302E383B0A202020207472616E736974696F6E3A206F70616369747920302E32733B0A7D0A2E6D656E646F626F742D636861742D636C';
wwv_flow_imp.g_varchar2_table(59) := '6F73652D62746E3A686F766572207B0A202020206F7061636974793A20313B0A7D0A2F2A2043756572706F2064656C204368617420284D656E73616A657329202A2F0A2E6D656E646F626F742D636861742D626F6479207B0A20202020666C65783A2031';
wwv_flow_imp.g_varchar2_table(60) := '3B0A2020202070616464696E673A20313670783B0A202020206F766572666C6F772D793A206175746F3B0A202020206261636B67726F756E642D636F6C6F723A2072676261283234392C203235302C203235312C20302E37293B0A20202020646973706C';
wwv_flow_imp.g_varchar2_table(61) := '61793A20666C65783B0A20202020666C65782D646972656374696F6E3A20636F6C756D6E3B0A202020206761703A20313670783B0A7D0A2F2A204D656E73616A657320792042757262756A6173202A2F0A2E6D656E646F626F742D6D657373616765207B';
wwv_flow_imp.g_varchar2_table(62) := '0A20202020646973706C61793A20666C65783B0A20202020666C65782D646972656374696F6E3A20636F6C756D6E3B0A202020206D61782D77696474683A203830253B0A20202020616E696D6174696F6E3A20736C696465496E20302E33732065617365';
wwv_flow_imp.g_varchar2_table(63) := '2D6F75743B0A7D0A406B65796672616D657320736C696465496E207B0A2020202066726F6D207B206F7061636974793A20303B207472616E73666F726D3A207472616E736C6174655928387078293B207D0A20202020746F207B206F7061636974793A20';
wwv_flow_imp.g_varchar2_table(64) := '313B207472616E73666F726D3A207472616E736C617465592830293B207D0A7D0A2E6D656E646F626F742D6D73672D75736572207B0A20202020616C69676E2D73656C663A20666C65782D656E643B0A7D0A2E6D656E646F626F742D6D73672D626F7420';
wwv_flow_imp.g_varchar2_table(65) := '7B0A20202020616C69676E2D73656C663A20666C65782D73746172743B0A7D0A2E6D656E646F626F742D6D73672D627562626C65207B0A2020202070616464696E673A203130707820313470783B0A20202020626F726465722D7261646975733A203134';
wwv_flow_imp.g_varchar2_table(66) := '70783B0A20202020666F6E742D73697A653A2031332E3570783B0A202020206C696E652D6865696768743A20312E353B0A20202020776F72642D627265616B3A20627265616B2D776F72643B0A7D0A2E6D656E646F626F742D6D73672D75736572202E6D';
wwv_flow_imp.g_varchar2_table(67) := '656E646F626F742D6D73672D627562626C65207B0A202020206261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B0A20202020636F6C6F723A20236666666666663B0A20202020626F726465722D62';
wwv_flow_imp.g_varchar2_table(68) := '6F74746F6D2D72696768742D7261646975733A203270783B0A20202020626F782D736861646F773A20302032707820367078207267626128302C203130322C203230342C20302E3135293B0A7D0A2E6D656E646F626F742D6D73672D626F74202E6D656E';
wwv_flow_imp.g_varchar2_table(69) := '646F626F742D6D73672D627562626C65207B0A202020206261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D6267293B0A20202020636F6C6F723A20766172282D2D6D656E646F626F742D74657874293B0A20202020626F';
wwv_flow_imp.g_varchar2_table(70) := '726465723A2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B0A20202020626F726465722D626F74746F6D2D6C6566742D7261646975733A203270783B0A20202020626F782D736861646F773A203020327078203670';
wwv_flow_imp.g_varchar2_table(71) := '78207267626128302C20302C20302C20302E3032293B0A7D0A2E6D656E646F626F742D6D73672D6572726F72202E6D656E646F626F742D6D73672D627562626C65207B0A202020206261636B67726F756E642D636F6C6F723A20236665663266323B0A20';
wwv_flow_imp.g_varchar2_table(72) := '202020636F6C6F723A20233939316231623B0A20202020626F726465723A2031707820736F6C696420236665653265323B0A20202020626F726465722D7261646975733A20313470783B0A7D0A2E6D656E646F626F742D6D73672D74696D65207B0A2020';
wwv_flow_imp.g_varchar2_table(73) := '2020666F6E742D73697A653A20313070783B0A20202020636F6C6F723A20233963613361663B0A202020206D617267696E2D746F703A203470783B0A20202020616C69676E2D73656C663A20666C65782D656E643B0A7D0A2E6D656E646F626F742D6D73';
wwv_flow_imp.g_varchar2_table(74) := '672D626F74202E6D656E646F626F742D6D73672D74696D65207B0A20202020616C69676E2D73656C663A20666C65782D73746172743B0A7D0A2F2A2050696520646520436861742028466F6F746572202F20496E70757429202A2F0A2E6D656E646F626F';
wwv_flow_imp.g_varchar2_table(75) := '742D636861742D666F6F746572207B0A2020202070616464696E673A203132707820313670783B0A202020206261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D6267293B0A20202020626F726465722D746F703A203170';
wwv_flow_imp.g_varchar2_table(76) := '7820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A202020206761703A20313270783B0A7D0A2E6D656E646F62';
wwv_flow_imp.g_varchar2_table(77) := '6F742D636861742D696E7075742D74657874207B0A20202020666C65783A20313B0A202020206865696768743A20333870783B0A20202020626F726465723A2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B0A2020';
wwv_flow_imp.g_varchar2_table(78) := '2020626F726465722D7261646975733A20323070783B0A2020202070616464696E673A203020313670783B0A20202020666F6E742D73697A653A20313370783B0A202020206261636B67726F756E642D636F6C6F723A20236639666166623B0A20202020';
wwv_flow_imp.g_varchar2_table(79) := '636F6C6F723A20766172282D2D6D656E646F626F742D74657874293B0A202020206F75746C696E653A206E6F6E653B0A202020207472616E736974696F6E3A20616C6C20302E32733B0A7D0A2E6D656E646F626F742D636861742D696E7075742D746578';
wwv_flow_imp.g_varchar2_table(80) := '743A666F637573207B0A20202020626F726465722D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B0A202020206261636B67726F756E642D636F6C6F723A20236666666666663B0A20202020626F782D736861646F773A20';
wwv_flow_imp.g_varchar2_table(81) := '30203020302032707820766172282D2D6D656E646F626F742D7072696D6172792D6C69676874293B0A7D0A2E6D656E646F626F742D636861742D73656E642D62746E207B0A2020202077696474683A20333870783B0A202020206865696768743A203338';
wwv_flow_imp.g_varchar2_table(82) := '70783B0A20202020626F726465722D7261646975733A203530253B0A202020206261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B0A20202020636F6C6F723A20236666666666663B0A2020202062';
wwv_flow_imp.g_varchar2_table(83) := '6F726465723A206E6F6E653B0A20202020637572736F723A20706F696E7465723B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A202020206A7573746966792D636F6E74656E743A2063';
wwv_flow_imp.g_varchar2_table(84) := '656E7465723B0A202020207472616E736974696F6E3A20616C6C20302E32733B0A7D0A2E6D656E646F626F742D636861742D73656E642D62746E3A686F766572207B0A202020206261636B67726F756E642D636F6C6F723A207267626128302C2037372C';
wwv_flow_imp.g_varchar2_table(85) := '203135332C20302E39293B0A7D0A2E6D656E646F626F742D636861742D73656E642D62746E3A64697361626C6564207B0A202020206261636B67726F756E642D636F6C6F723A20236431643564623B0A20202020637572736F723A206E6F742D616C6C6F';
wwv_flow_imp.g_varchar2_table(86) := '7765643B0A7D0A2E6D656E646F626F742D636861742D696E7075742D746578743A64697361626C6564207B0A202020206261636B67726F756E642D636F6C6F723A20236633663466363B0A20202020636F6C6F723A20233963613361663B0A2020202063';
wwv_flow_imp.g_varchar2_table(87) := '7572736F723A206E6F742D616C6C6F7765643B0A7D0A2F2A20496E64696361646F722064652065736372697475726120616E696D61646F2028547970696E6720496E64696361746F7229202A2F0A2E6D656E646F626F742D747970696E672D696E646963';
wwv_flow_imp.g_varchar2_table(88) := '61746F72202E6D656E646F626F742D6D73672D627562626C65207B0A2020202070616464696E673A203132707820313670783B0A20202020646973706C61793A20666C65783B0A20202020616C69676E2D6974656D733A2063656E7465723B0A20202020';
wwv_flow_imp.g_varchar2_table(89) := '6761703A203470783B0A20202020626F726465722D7261646975733A20313470783B0A20202020626F726465722D626F74746F6D2D6C6566742D7261646975733A203270783B0A7D0A2E6D656E646F626F742D747970696E672D696E64696361746F7220';
wwv_flow_imp.g_varchar2_table(90) := '2E646F74207B0A2020202077696474683A203670783B0A202020206865696768743A203670783B0A202020206261636B67726F756E642D636F6C6F723A20233963613361663B0A20202020626F726465722D7261646975733A203530253B0A2020202064';
wwv_flow_imp.g_varchar2_table(91) := '6973706C61793A20696E6C696E652D626C6F636B3B0A20202020616E696D6174696F6E3A206A756D7020312E347320696E66696E69746520656173652D696E2D6F757420626F74683B0A7D0A2E6D656E646F626F742D747970696E672D696E6469636174';
wwv_flow_imp.g_varchar2_table(92) := '6F72202E646F743A6E74682D6368696C64283129207B0A20202020616E696D6174696F6E2D64656C61793A202D302E3332733B0A7D0A2E6D656E646F626F742D747970696E672D696E64696361746F72202E646F743A6E74682D6368696C64283229207B';
wwv_flow_imp.g_varchar2_table(93) := '0A20202020616E696D6174696F6E2D64656C61793A202D302E3136733B0A7D0A406B65796672616D6573206A756D70207B0A2020202030252C203830252C2031303025207B207472616E73666F726D3A207363616C652830293B207D0A20202020343025';
wwv_flow_imp.g_varchar2_table(94) := '207B207472616E73666F726D3A207363616C65283129207472616E736C61746559282D367078293B207D0A7D0A2F2A20416A757374657320526573706F6E7369766F7320706172612050616E74616C6C6173205065717565C3B16173202A2F0A406D6564';
wwv_flow_imp.g_varchar2_table(95) := '696120286D61782D77696474683A20343830707829207B0A202020202E6D656E646F626F742D636861742D77726170706572207B0A2020202020202020626F74746F6D3A20313670783B0A202020202020202072696768743A20313670783B0A20202020';
wwv_flow_imp.g_varchar2_table(96) := '7D0A202020202E6D656E646F626F742D636861742D626F78207B0A202020202020202077696474683A2063616C63283130307677202D2033327078293B0A20202020202020206865696768743A2063616C63283130307668202D203132307078293B0A20';
wwv_flow_imp.g_varchar2_table(97) := '20202020202020626F74746F6D3A20363470783B0A202020207D0A7D0A';
null;
end;
/
begin
wwv_flow_imp_shared.create_plugin_file(
 p_id=>wwv_flow_imp.id(2586623976831924)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_file_name=>'mendobot-chat.css'
,p_mime_type=>'text/css'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_imp.varchar2_to_blob(wwv_flow_imp.g_varchar2_table)
);
end;
/
begin
wwv_flow_imp.g_varchar2_table := wwv_flow_imp.empty_varchar2_table;
wwv_flow_imp.g_varchar2_table(1) := '2F2A2A0A202A20504C5547494E2043484154204149202D20434C49454E542053494445205343524950540A202A204465736172726F6C6C61646F20636F6E20736F706F72746520636F6D706C65746F206E617469766F2070617261204F7261636C652041';
wwv_flow_imp.g_varchar2_table(2) := '5045582E0A202A204175746F723A20437269737469616E20416C63C3A16E746172610A202A204C6963656E6369613A20477261746973202F204F70656E20536F757263650A202A2F0A66756E6374696F6E206D656E646F626F7443686174496E69742870';
wwv_flow_imp.g_varchar2_table(3) := '526567696F6E49642C2070416A61784964656E7469666965722C2070496E7465726E616C526567696F6E496429207B0A202020202F2F2052656769737465722074686520726567696F6E20696E204150455820726567696F6E2072656769737472790A20';
wwv_flow_imp.g_varchar2_table(4) := '202020617065782E726567696F6E2E63726561746528226D656E646F626F742D636861742D636F6E7461696E65722D22202B2070526567696F6E49642C207B0A2020202020202020747970653A20224D656E646F626F7443686174222C0A202020202020';
wwv_flow_imp.g_varchar2_table(5) := '20207769646765743A2066756E6374696F6E2829207B0A20202020202020202020202072657475726E20617065782E6A51756572792822236D656E646F626F742D636861742D636F6E7461696E65722D22202B2070526567696F6E4964293B0A20202020';
wwv_flow_imp.g_varchar2_table(6) := '202020207D0A202020207D293B0A20202020636F6E737420746F67676C6542746E203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D636861742D746F67676C652D27202B2070526567696F6E4964293B0A2020';
wwv_flow_imp.g_varchar2_table(7) := '2020636F6E737420636C6F736542746E203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D636861742D636C6F73652D27202B2070526567696F6E4964293B0A20202020636F6E73742063686174426F78203D20';
wwv_flow_imp.g_varchar2_table(8) := '646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D636861742D77696E646F772D27202B2070526567696F6E4964293B0A20202020636F6E73742063686174496E707574203D20646F63756D656E742E676574456C656D';
wwv_flow_imp.g_varchar2_table(9) := '656E744279496428276D656E646F626F742D636861742D696E7075742D27202B2070526567696F6E4964293B0A20202020636F6E73742073656E6442746E203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D63';
wwv_flow_imp.g_varchar2_table(10) := '6861742D73656E642D27202B2070526567696F6E4964293B0A20202020636F6E73742063686174426F6479203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D636861742D6D657373616765732D27202B207052';
wwv_flow_imp.g_varchar2_table(11) := '6567696F6E4964293B0A202020206966202821746F67676C6542746E207C7C202163686174426F78292072657475726E3B0A202020202F2F204D616E656A6F206465206576656E746F7320646520617065727475726120792063696572726520636F6E20';
wwv_flow_imp.g_varchar2_table(12) := '666F636F2064696EC3A16D69636F0A20202020746F67676C6542746E2E6164644576656E744C697374656E65722827636C69636B272C2066756E6374696F6E286529207B0A2020202020202020652E70726576656E7444656661756C7428293B0A202020';
wwv_flow_imp.g_varchar2_table(13) := '2020202020652E73746F7050726F7061676174696F6E28293B0A202020202020202063686174426F782E636C6173734C6973742E746F67676C6528276D656E646F626F742D636861742D68696464656E27293B0A20202020202020206966202821636861';
wwv_flow_imp.g_varchar2_table(14) := '74426F782E636C6173734C6973742E636F6E7461696E7328276D656E646F626F742D636861742D68696464656E272929207B0A20202020202020202020202063686174496E7075742E666F63757328293B0A2020202020202020202020207363726F6C6C';
wwv_flow_imp.g_varchar2_table(15) := '546F426F74746F6D28293B0A20202020202020207D0A202020207D293B0A20202020636C6F736542746E2E6164644576656E744C697374656E65722827636C69636B272C2066756E6374696F6E286529207B0A2020202020202020652E70726576656E74';
wwv_flow_imp.g_varchar2_table(16) := '44656661756C7428293B0A2020202020202020652E73746F7050726F7061676174696F6E28293B0A202020202020202063686174426F782E636C6173734C6973742E61646428276D656E646F626F742D636861742D68696464656E27293B0A202020207D';
wwv_flow_imp.g_varchar2_table(17) := '293B0A202020202F2F20456E76696172206D656E73616A6520656E20636C69636B206F2070756C73617220456E7465720A2020202073656E6442746E2E6164644576656E744C697374656E65722827636C69636B272C2066756E6374696F6E2829207B0A';
wwv_flow_imp.g_varchar2_table(18) := '2020202020202020656E766961724D656E73616A6528293B0A202020207D293B0A2020202063686174496E7075742E6164644576656E744C697374656E657228276B6579646F776E272C2066756E6374696F6E286529207B0A2020202020202020696620';
wwv_flow_imp.g_varchar2_table(19) := '28652E6B6579203D3D3D2027456E7465722729207B0A202020202020202020202020652E70726576656E7444656661756C7428293B0A202020202020202020202020656E766961724D656E73616A6528293B0A20202020202020207D0A202020207D293B';
wwv_flow_imp.g_varchar2_table(20) := '0A202020202F2F20446573706C617A616D69656E746F206175746F6DC3A17469636F20696E74656C6967656E746520686163696120656C20666F6E646F2064656C20636F6E74656E65646F720A2020202066756E6374696F6E207363726F6C6C546F426F';
wwv_flow_imp.g_varchar2_table(21) := '74746F6D2829207B0A202020202020202063686174426F64792E7363726F6C6C546F70203D2063686174426F64792E7363726F6C6C4865696768743B0A202020207D0A202020202F2F2050726F6365736F206173C3AD6E63726F6E6F2073656775726F20';
wwv_flow_imp.g_varchar2_table(22) := '696E7465677261646F20636F6E204150455820536572766572204150490A2020202066756E6374696F6E20656E766961724D656E73616A652829207B0A2020202020202020636F6E73742074657874203D2063686174496E7075742E76616C75653B0A20';
wwv_flow_imp.g_varchar2_table(23) := '20202020202020696620282174657874207C7C2021746578742E7472696D2829292072657475726E3B0A20202020202020202F2F20446573686162696C6974617220656E7472616461732074656D706F72616C6D656E7465207061726120657669746172';
wwv_flow_imp.g_varchar2_table(24) := '207065746963696F6E6573206475706C6963616461732028646F75626C652D7375626D6974290A202020202020202063686174496E7075742E76616C7565203D2027273B0A202020202020202063686174496E7075742E64697361626C6564203D207472';
wwv_flow_imp.g_varchar2_table(25) := '75653B0A202020202020202073656E6442746E2E64697361626C6564203D20747275653B0A2020202020202020636F6E73742076486F7261203D206E6577204461746528292E746F4C6F63616C6554696D65537472696E67285B5D2C207B686F75723A20';
wwv_flow_imp.g_varchar2_table(26) := '27322D6469676974272C206D696E7574653A27322D6469676974277D293B0A20202020202020202F2F2052656E646572697A61722062757262756A612064656C207573756172696F206573636170616E646F2048544D4C207061726120626C696E64616A';
wwv_flow_imp.g_varchar2_table(27) := '652058535320746F74616C0A2020202020202020636F6E737420757365724D7367446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0A2020202020202020757365724D73674469762E636C6173734E616D65203D';
wwv_flow_imp.g_varchar2_table(28) := '20276D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D75736572273B0A2020202020202020757365724D73674469762E696E6E657248544D4C203D20600A2020202020202020202020203C64697620636C6173733D226D656E64';
wwv_flow_imp.g_varchar2_table(29) := '6F626F742D6D73672D627562626C65223E0A20202020202020202020202020202020247B617065782E7574696C2E65736361706548544D4C2874657874297D0A2020202020202020202020203C2F6469763E0A2020202020202020202020203C7370616E';
wwv_flow_imp.g_varchar2_table(30) := '20636C6173733D226D656E646F626F742D6D73672D74696D65223E247B76486F72617D3C2F7370616E3E0A2020202020202020603B0A202020202020202063686174426F64792E617070656E644368696C6428757365724D7367446976293B0A20202020';
wwv_flow_imp.g_varchar2_table(31) := '202020207363726F6C6C546F426F74746F6D28293B0A20202020202020202F2F20496E79656374617220616E696D61646F72206465206573637269747572612028547970696E6720496E64696361746F72292070617261206D656A6F726172206C612055';
wwv_flow_imp.g_varchar2_table(32) := '582F416573746865746963730A2020202020202020636F6E7374206C6F6164696E67446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0A20202020202020206C6F6164696E674469762E636C6173734E616D6520';
wwv_flow_imp.g_varchar2_table(33) := '3D20276D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D626F74206D656E646F626F742D747970696E672D696E64696361746F72273B0A20202020202020206C6F6164696E674469762E6964203D20276D656E646F626F742D74';
wwv_flow_imp.g_varchar2_table(34) := '7970696E672D27202B2070526567696F6E49643B0A20202020202020206C6F6164696E674469762E696E6E657248544D4C203D20600A2020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E0A';
wwv_flow_imp.g_varchar2_table(35) := '202020202020202020202020202020203C7370616E20636C6173733D22646F74223E3C2F7370616E3E0A202020202020202020202020202020203C7370616E20636C6173733D22646F74223E3C2F7370616E3E0A20202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(36) := '3C7370616E20636C6173733D22646F74223E3C2F7370616E3E0A2020202020202020202020203C2F6469763E0A2020202020202020603B0A202020202020202063686174426F64792E617070656E644368696C64286C6F6164696E67446976293B0A2020';
wwv_flow_imp.g_varchar2_table(37) := '2020202020207363726F6C6C546F426F74746F6D28293B0A20202020202020202F2F2043616E616C20646520636F6E657869C3B36E206F66696369616C206173C3AD6E63726F6E6F207061726120506C7567696E7320656E20415045580A202020202020';
wwv_flow_imp.g_varchar2_table(38) := '2020617065782E7365727665722E706C7567696E2870416A61784964656E7469666965722C207B0A2020202020202020202020207830313A20746578742C0A2020202020202020202020207830333A2070496E7465726E616C526567696F6E49642C0A20';
wwv_flow_imp.g_varchar2_table(39) := '2020202020202020202020705F646573745F726567696F6E5F69643A2070496E7465726E616C526567696F6E49640A20202020202020207D2C207B0A2020202020202020202020207461726765743A20646F63756D656E742E676574456C656D656E7442';
wwv_flow_imp.g_varchar2_table(40) := '79496428226D656E646F626F742D636861742D636F6E7461696E65722D22202B2070526567696F6E4964292C0A202020202020202020202020737563636573733A2066756E6374696F6E28704461746129207B0A20202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(41) := '2F2F2052656D6F76657220696E64696361646F722064652063617267610A20202020202020202020202020202020636F6E737420747970696E67203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D747970696E';
wwv_flow_imp.g_varchar2_table(42) := '672D27202B2070526567696F6E4964293B0A2020202020202020202020202020202069662028747970696E672920747970696E672E72656D6F766528293B0A202020202020202020202020202020202F2F20486162696C6974617220636F6E74726F6C65';
wwv_flow_imp.g_varchar2_table(43) := '730A2020202020202020202020202020202063686174496E7075742E64697361626C6564203D2066616C73653B0A2020202020202020202020202020202073656E6442746E2E64697361626C6564203D2066616C73653B0A202020202020202020202020';
wwv_flow_imp.g_varchar2_table(44) := '2020202063686174496E7075742E666F63757328293B0A202020202020202020202020202020206966202870446174612E7375636365737329207B0A20202020202020202020202020202020202020202F2F2052656E646572697A6172206C6120726573';
wwv_flow_imp.g_varchar2_table(45) := '70756573746120666F726D617465616461206465206C612049410A2020202020202020202020202020202020202020636F6E737420626F744D7367446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0A20202020';
wwv_flow_imp.g_varchar2_table(46) := '20202020202020202020202020202020626F744D73674469762E636C6173734E616D65203D20276D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D626F74273B0A2020202020202020202020202020202020202020626F744D73';
wwv_flow_imp.g_varchar2_table(47) := '674469762E696E6E657248544D4C203D20600A2020202020202020202020202020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E0A2020202020202020202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(48) := '2020202020247B70446174612E7265737075657374617D0A2020202020202020202020202020202020202020202020203C2F6469763E0A2020202020202020202020202020202020202020202020203C7370616E20636C6173733D226D656E646F626F74';
wwv_flow_imp.g_varchar2_table(49) := '2D6D73672D74696D65223E247B76486F72617D3C2F7370616E3E0A2020202020202020202020202020202020202020603B0A202020202020202020202020202020202020202063686174426F64792E617070656E644368696C6428626F744D7367446976';
wwv_flow_imp.g_varchar2_table(50) := '293B0A20202020202020202020202020202020202020207363726F6C6C546F426F74746F6D28293B0A20202020202020202020202020202020202020200A20202020202020202020202020202020202020202F2F2052656672657363617220636F6D706F';
wwv_flow_imp.g_varchar2_table(51) := '6E656E746520415045580A2020202020202020202020202020202020202020747279207B0A202020202020202020202020202020202020202020202020617065782E726567696F6E2870526567696F6E4964292E7265667265736828293B0A2020202020';
wwv_flow_imp.g_varchar2_table(52) := '2020202020202020202020202020207D206361746368286529207B0A2020202020202020202020202020202020202020202020202F2F2053696C656E63696172206572726F7220656E206361736F20646520717565206E6F2074656E676120656C656D65';
wwv_flow_imp.g_varchar2_table(53) := '6E746F20726567696F6E20636F6E74656E65646F720A20202020202020202020202020202020202020207D0A202020202020202020202020202020207D20656C7365207B0A20202020202020202020202020202020202020202F2F2062757262756A6120';
wwv_flow_imp.g_varchar2_table(54) := '6465206572726F7220536161530A2020202020202020202020202020202020202020636F6E7374206572726F724D7367446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0A202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(55) := '20202020206572726F724D73674469762E636C6173734E616D65203D20276D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D6572726F72273B0A20202020202020202020202020202020202020206572726F724D73674469762E';
wwv_flow_imp.g_varchar2_table(56) := '696E6E657248544D4C203D20600A2020202020202020202020202020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E0A20202020202020202020202020202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(57) := '3C7374726F6E673E4572726F722064656C2053697374656D613A3C2F7374726F6E673E3C62723E247B617065782E7574696C2E65736361706548544D4C2870446174612E726573707565737461297D0A2020202020202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(58) := '202020203C2F6469763E0A2020202020202020202020202020202020202020202020203C7370616E20636C6173733D226D656E646F626F742D6D73672D74696D65223E247B76486F72617D3C2F7370616E3E0A2020202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(59) := '202020603B0A202020202020202020202020202020202020202063686174426F64792E617070656E644368696C64286572726F724D7367446976293B0A20202020202020202020202020202020202020207363726F6C6C546F426F74746F6D28293B0A20';
wwv_flow_imp.g_varchar2_table(60) := '2020202020202020202020202020207D0A2020202020202020202020207D2C0A2020202020202020202020206572726F723A2066756E6374696F6E287868722C207374617475732C206572726F7229207B0A202020202020202020202020202020202F2F';
wwv_flow_imp.g_varchar2_table(61) := '2052656D6F76657220696E64696361646F722079207265616374697661720A20202020202020202020202020202020636F6E737420747970696E67203D20646F63756D656E742E676574456C656D656E744279496428276D656E646F626F742D74797069';
wwv_flow_imp.g_varchar2_table(62) := '6E672D27202B2070526567696F6E4964293B0A2020202020202020202020202020202069662028747970696E672920747970696E672E72656D6F766528293B0A2020202020202020202020202020202063686174496E7075742E64697361626C6564203D';
wwv_flow_imp.g_varchar2_table(63) := '2066616C73653B0A2020202020202020202020202020202073656E6442746E2E64697361626C6564203D2066616C73653B0A2020202020202020202020202020202063686174496E7075742E666F63757328293B0A202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(64) := '20636F6E7374206572726F724D7367446976203D20646F63756D656E742E637265617465456C656D656E74282764697627293B0A202020202020202020202020202020206572726F724D73674469762E636C6173734E616D65203D20276D656E646F626F';
wwv_flow_imp.g_varchar2_table(65) := '742D6D657373616765206D656E646F626F742D6D73672D6572726F72273B0A202020202020202020202020202020206572726F724D73674469762E696E6E657248544D4C203D20600A20202020202020202020202020202020202020203C64697620636C';
wwv_flow_imp.g_varchar2_table(66) := '6173733D226D656E646F626F742D6D73672D627562626C65223E0A2020202020202020202020202020202020202020202020204572726F7220646520636F6D756E6963616369C3B36E2064652072656420616C2070726F636573617220656C2063686174';
wwv_flow_imp.g_varchar2_table(67) := '20666C6F74616E74652E20496E74656E7465206DC3A1732074617264652E0A20202020202020202020202020202020202020203C2F6469763E0A20202020202020202020202020202020202020203C7370616E20636C6173733D226D656E646F626F742D';
wwv_flow_imp.g_varchar2_table(68) := '6D73672D74696D65223E247B76486F72617D3C2F7370616E3E0A20202020202020202020202020202020603B0A2020202020202020202020202020202063686174426F64792E617070656E644368696C64286572726F724D7367446976293B0A20202020';
wwv_flow_imp.g_varchar2_table(69) := '2020202020202020202020207363726F6C6C546F426F74746F6D28293B0A2020202020202020202020207D0A20202020202020207D293B0A202020207D0A7D0A';
null;
end;
/
begin
wwv_flow_imp_shared.create_plugin_file(
 p_id=>wwv_flow_imp.id(2586996405831942)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_file_name=>'mendobot-chat.js'
,p_mime_type=>'text/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_imp.varchar2_to_blob(wwv_flow_imp.g_varchar2_table)
);
end;
/
begin
wwv_flow_imp.g_varchar2_table := wwv_flow_imp.empty_varchar2_table;
wwv_flow_imp.g_varchar2_table(1) := '3A726F6F74207B2D2D6D656E646F626F742D7072696D6172793A20766172282D2D612D70616C657474652D7072696D6172792C2023303036366363293B2D2D6D656E646F626F742D7072696D6172792D6C696768743A20766172282D2D612D70616C6574';
wwv_flow_imp.g_varchar2_table(2) := '74652D7072696D6172792D6C696768742C207267626128302C203130322C203230342C20302E3129293B2D2D6D656E646F626F742D62673A20766172282D2D612D63762D737572666163652D636F6C6F722C2023666666666666293B2D2D6D656E646F62';
wwv_flow_imp.g_varchar2_table(3) := '6F742D746578743A20766172282D2D612D63762D746578742D636F6C6F722C2023316632393337293B2D2D6D656E646F626F742D626F726465723A20766172282D2D612D63762D626F726465722D636F6C6F722C2023653565376562293B2D2D6D656E64';
wwv_flow_imp.g_varchar2_table(4) := '6F626F742D736861646F773A203020313070782032357078202D357078207267626128302C20302C20302C20302E31292C2030203870782031307078202D367078207267626128302C20302C20302C20302E31293B2D2D6D656E646F626F742D666F6E74';
wwv_flow_imp.g_varchar2_table(5) := '3A20766172282D2D612D666F6E742D66616D696C792C202D6170706C652D73797374656D2C20426C696E6B4D616353797374656D466F6E742C20225365676F65205549222C20526F626F746F2C2048656C7665746963612C20417269616C2C2073616E73';
wwv_flow_imp.g_varchar2_table(6) := '2D7365726966293B7D2E6D656E646F626F742D636861742D77726170706572207B706F736974696F6E3A2066697865643B626F74746F6D3A20323470783B72696768743A20323470783B7A2D696E6465783A20393939393B666F6E742D66616D696C793A';
wwv_flow_imp.g_varchar2_table(7) := '20766172282D2D6D656E646F626F742D666F6E74293B646973706C61793A20626C6F636B2021696D706F7274616E743B7D2E6D656E646F626F742D636861742D74726967676572207B77696474683A20353670783B6865696768743A20353670783B626F';
wwv_flow_imp.g_varchar2_table(8) := '726465722D7261646975733A203530253B6261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B636F6C6F723A20236666666666663B626F726465723A206E6F6E653B637572736F723A20706F696E74';
wwv_flow_imp.g_varchar2_table(9) := '65723B626F782D736861646F773A203020347078203134707820766172282D2D612D70616C657474652D7072696D6172792D6C696768742C207267626128302C203130322C203230342C20302E3429293B646973706C61793A20666C65783B616C69676E';
wwv_flow_imp.g_varchar2_table(10) := '2D6974656D733A2063656E7465723B6A7573746966792D636F6E74656E743A2063656E7465723B7472616E736974696F6E3A20616C6C20302E33732063756269632D62657A69657228302E342C20302C20302E322C2031293B7D2E6D656E646F626F742D';
wwv_flow_imp.g_varchar2_table(11) := '636861742D747269676765723A686F766572207B7472616E73666F726D3A207363616C6528312E303829207472616E736C61746559282D327078293B626F782D736861646F773A203020367078203230707820766172282D2D612D70616C657474652D70';
wwv_flow_imp.g_varchar2_table(12) := '72696D6172792D6C696768742C207267626128302C203130322C203230342C20302E3529293B7D2E6D656E646F626F742D636861742D747269676765723A616374697665207B7472616E73666F726D3A207363616C6528302E3935293B7D2E6D656E646F';
wwv_flow_imp.g_varchar2_table(13) := '626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D2C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A686F7665722C0A2E6D656E';
wwv_flow_imp.g_varchar2_table(14) := '646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F6375732C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F63';
wwv_flow_imp.g_varchar2_table(15) := '75732D76697369626C652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A616374697665207B6261636B67726F756E643A207472616E73706172656E742021696D706F7274616E';
wwv_flow_imp.g_varchar2_table(16) := '743B6261636B67726F756E642D636F6C6F723A207472616E73706172656E742021696D706F7274616E743B626F782D736861646F773A206E6F6E652021696D706F7274616E743B70616464696E673A20302021696D706F7274616E743B626F726465723A';
wwv_flow_imp.g_varchar2_table(17) := '206E6F6E652021696D706F7274616E743B6F75746C696E653A206E6F6E652021696D706F7274616E743B7D2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A3A6265666F72652C0A2E';
wwv_flow_imp.g_varchar2_table(18) := '6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A3A61667465722C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D';
wwv_flow_imp.g_varchar2_table(19) := '3A686F7665723A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A686F7665723A3A61667465722C0A2E6D656E646F626F742D636861742D747269676765722E';
wwv_flow_imp.g_varchar2_table(20) := '6D656E646F626F742D747269676765722D637573746F6D3A666F6375733A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A666F6375733A3A61667465722C0A';
wwv_flow_imp.g_varchar2_table(21) := '2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D3A6163746976653A3A6265666F72652C0A2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D7472696767';
wwv_flow_imp.g_varchar2_table(22) := '65722D637573746F6D3A6163746976653A3A6166746572207B646973706C61793A206E6F6E652021696D706F7274616E743B636F6E74656E743A206E6F6E652021696D706F7274616E743B6261636B67726F756E643A207472616E73706172656E742021';
wwv_flow_imp.g_varchar2_table(23) := '696D706F7274616E743B6261636B67726F756E642D636F6C6F723A207472616E73706172656E742021696D706F7274616E743B626F782D736861646F773A206E6F6E652021696D706F7274616E743B626F726465723A206E6F6E652021696D706F727461';
wwv_flow_imp.g_varchar2_table(24) := '6E743B7D2E6D656E646F626F742D636861742D747269676765722E6D656E646F626F742D747269676765722D637573746F6D202E6D656E646F626F742D747269676765722D696D67207B77696474683A20353670783B6865696768743A20353670783B6F';
wwv_flow_imp.g_varchar2_table(25) := '626A6563742D6669743A20636F6E7461696E3B626F726465722D7261646975733A20302021696D706F7274616E743B626F726465723A206E6F6E652021696D706F7274616E743B7D2E6D656E646F626F742D636861742D626F78207B706F736974696F6E';
wwv_flow_imp.g_varchar2_table(26) := '3A206162736F6C7574653B626F74746F6D3A20373270783B72696768743A20303B77696474683A2033383070783B6865696768743A2035323070783B6261636B67726F756E642D636F6C6F723A2072676261283235352C203235352C203235352C20302E';
wwv_flow_imp.g_varchar2_table(27) := '3935293B6261636B64726F702D66696C7465723A20626C75722831307078293B2D7765626B69742D6261636B64726F702D66696C7465723A20626C75722831307078293B626F726465723A2031707820736F6C696420766172282D2D6D656E646F626F74';
wwv_flow_imp.g_varchar2_table(28) := '2D626F72646572293B626F726465722D7261646975733A20313670783B626F782D736861646F773A20766172282D2D6D656E646F626F742D736861646F77293B646973706C61793A20666C65783B666C65782D646972656374696F6E3A20636F6C756D6E';
wwv_flow_imp.g_varchar2_table(29) := '3B6F766572666C6F773A2068696464656E3B7472616E736974696F6E3A20616C6C20302E33732063756269632D62657A69657228302E342C20302C20302E322C2031293B7472616E73666F726D2D6F726967696E3A20626F74746F6D2072696768743B7D';
wwv_flow_imp.g_varchar2_table(30) := '2E6D656E646F626F742D636861742D68696464656E207B6F7061636974793A20303B7669736962696C6974793A2068696464656E3B7472616E73666F726D3A207363616C6528302E3829207472616E736C617465592832307078293B706F696E7465722D';
wwv_flow_imp.g_varchar2_table(31) := '6576656E74733A206E6F6E653B7D2E6D656E646F626F742D636861742D686561646572207B70616464696E673A20313670783B6261636B67726F756E643A206C696E6561722D6772616469656E74283133356465672C20766172282D2D6D656E646F626F';
wwv_flow_imp.g_varchar2_table(32) := '742D7072696D617279292030252C207267626128302C2037372C203135332C20302E39292031303025293B636F6C6F723A20236666666666663B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E7465723B6A7573746966792D';
wwv_flow_imp.g_varchar2_table(33) := '636F6E74656E743A2073706163652D6265747765656E3B626F782D736861646F773A2030203270782031307078207267626128302C302C302C302E3035293B7D2E6D656E646F626F742D6865616465722D696E666F207B646973706C61793A20666C6578';
wwv_flow_imp.g_varchar2_table(34) := '3B616C69676E2D6974656D733A2063656E7465723B7D2E6D656E646F626F742D6176617461722D636F6E7461696E6572207B706F736974696F6E3A2072656C61746976653B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E74';
wwv_flow_imp.g_varchar2_table(35) := '65723B7D406B65796672616D657320626F7450756C7365207B3025207B207472616E73666F726D3A207363616C652831293B2066696C7465723A2064726F702D736861646F7728302030203270782072676261283235352C3235352C3235352C302E3229';
wwv_flow_imp.g_varchar2_table(36) := '293B207D353025207B207472616E73666F726D3A207363616C6528312E3035293B2066696C7465723A2064726F702D736861646F7728302030203870782072676261283235352C3235352C3235352C302E3729293B207D31303025207B207472616E7366';
wwv_flow_imp.g_varchar2_table(37) := '6F726D3A207363616C652831293B2066696C7465723A2064726F702D736861646F7728302030203270782072676261283235352C3235352C3235352C302E3229293B207D7D2E6D656E646F626F742D6176617461722D6C6F676F207B77696474683A2033';
wwv_flow_imp.g_varchar2_table(38) := '3270783B6865696768743A20333270783B626F726465722D7261646975733A203530253B6F626A6563742D6669743A20636F7665723B626F726465723A2032707820736F6C69642072676261283235352C3235352C3235352C302E38293B616E696D6174';
wwv_flow_imp.g_varchar2_table(39) := '696F6E3A20626F7450756C73652031307320696E66696E69746520656173652D696E2D6F75743B6D617267696E2D72696768743A20313270783B7D2E6D656E646F626F742D6176617461722D6C6F676F2E6D656E646F626F742D6176617461722D637573';
wwv_flow_imp.g_varchar2_table(40) := '746F6D207B626F726465723A206E6F6E652021696D706F7274616E743B626F726465722D7261646975733A20302021696D706F7274616E743B616E696D6174696F6E3A206E6F6E652021696D706F7274616E743B626F782D736861646F773A206E6F6E65';
wwv_flow_imp.g_varchar2_table(41) := '2021696D706F7274616E743B6F626A6563742D6669743A20636F6E7461696E2021696D706F7274616E743B7D2E6D656E646F626F742D6865616465722D7469746C65206833207B6D617267696E3A20303B666F6E742D73697A653A20313570783B666F6E';
wwv_flow_imp.g_varchar2_table(42) := '742D7765696768743A203630303B6C65747465722D73706163696E673A20302E3370783B636F6C6F723A20236666666666663B7D2E6D656E646F626F742D6F6E6C696E652D737461747573207B666F6E742D73697A653A20313170783B6F706163697479';
wwv_flow_imp.g_varchar2_table(43) := '3A20302E38353B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E7465723B6D617267696E2D746F703A203270783B7D2E7374617475732D646F74207B77696474683A203670783B6865696768743A203670783B6261636B6772';
wwv_flow_imp.g_varchar2_table(44) := '6F756E642D636F6C6F723A20233130623938313B626F726465722D7261646975733A203530253B6D617267696E2D72696768743A203670783B646973706C61793A20696E6C696E652D626C6F636B3B7D2E6D656E646F626F742D636861742D636C6F7365';
wwv_flow_imp.g_varchar2_table(45) := '2D62746E207B6261636B67726F756E643A206E6F6E653B626F726465723A206E6F6E653B636F6C6F723A20236666666666663B666F6E742D73697A653A20323470783B637572736F723A20706F696E7465723B6C696E652D6865696768743A20313B6F70';
wwv_flow_imp.g_varchar2_table(46) := '61636974793A20302E383B7472616E736974696F6E3A206F70616369747920302E32733B7D2E6D656E646F626F742D636861742D636C6F73652D62746E3A686F766572207B6F7061636974793A20313B7D2E6D656E646F626F742D636861742D626F6479';
wwv_flow_imp.g_varchar2_table(47) := '207B666C65783A20313B70616464696E673A20313670783B6F766572666C6F772D793A206175746F3B6261636B67726F756E642D636F6C6F723A2072676261283234392C203235302C203235312C20302E37293B646973706C61793A20666C65783B666C';
wwv_flow_imp.g_varchar2_table(48) := '65782D646972656374696F6E3A20636F6C756D6E3B6761703A20313670783B7D2E6D656E646F626F742D6D657373616765207B646973706C61793A20666C65783B666C65782D646972656374696F6E3A20636F6C756D6E3B6D61782D77696474683A2038';
wwv_flow_imp.g_varchar2_table(49) := '30253B616E696D6174696F6E3A20736C696465496E20302E337320656173652D6F75743B7D406B65796672616D657320736C696465496E207B66726F6D207B206F7061636974793A20303B207472616E73666F726D3A207472616E736C61746559283870';
wwv_flow_imp.g_varchar2_table(50) := '78293B207D746F207B206F7061636974793A20313B207472616E73666F726D3A207472616E736C617465592830293B207D7D2E6D656E646F626F742D6D73672D75736572207B616C69676E2D73656C663A20666C65782D656E643B7D2E6D656E646F626F';
wwv_flow_imp.g_varchar2_table(51) := '742D6D73672D626F74207B616C69676E2D73656C663A20666C65782D73746172743B7D2E6D656E646F626F742D6D73672D627562626C65207B70616464696E673A203130707820313470783B626F726465722D7261646975733A20313470783B666F6E74';
wwv_flow_imp.g_varchar2_table(52) := '2D73697A653A2031332E3570783B6C696E652D6865696768743A20312E353B776F72642D627265616B3A20627265616B2D776F72643B7D2E6D656E646F626F742D6D73672D75736572202E6D656E646F626F742D6D73672D627562626C65207B6261636B';
wwv_flow_imp.g_varchar2_table(53) := '67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B636F6C6F723A20236666666666663B626F726465722D626F74746F6D2D72696768742D7261646975733A203270783B626F782D736861646F773A20302032';
wwv_flow_imp.g_varchar2_table(54) := '707820367078207267626128302C203130322C203230342C20302E3135293B7D2E6D656E646F626F742D6D73672D626F74202E6D656E646F626F742D6D73672D627562626C65207B6261636B67726F756E642D636F6C6F723A20766172282D2D6D656E64';
wwv_flow_imp.g_varchar2_table(55) := '6F626F742D6267293B636F6C6F723A20766172282D2D6D656E646F626F742D74657874293B626F726465723A2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B626F726465722D626F74746F6D2D6C6566742D726164';
wwv_flow_imp.g_varchar2_table(56) := '6975733A203270783B626F782D736861646F773A20302032707820367078207267626128302C20302C20302C20302E3032293B7D2E6D656E646F626F742D6D73672D6572726F72202E6D656E646F626F742D6D73672D627562626C65207B6261636B6772';
wwv_flow_imp.g_varchar2_table(57) := '6F756E642D636F6C6F723A20236665663266323B636F6C6F723A20233939316231623B626F726465723A2031707820736F6C696420236665653265323B626F726465722D7261646975733A20313470783B7D2E6D656E646F626F742D6D73672D74696D65';
wwv_flow_imp.g_varchar2_table(58) := '207B666F6E742D73697A653A20313070783B636F6C6F723A20233963613361663B6D617267696E2D746F703A203470783B616C69676E2D73656C663A20666C65782D656E643B7D2E6D656E646F626F742D6D73672D626F74202E6D656E646F626F742D6D';
wwv_flow_imp.g_varchar2_table(59) := '73672D74696D65207B616C69676E2D73656C663A20666C65782D73746172743B7D2E6D656E646F626F742D636861742D666F6F746572207B70616464696E673A203132707820313670783B6261636B67726F756E642D636F6C6F723A20766172282D2D6D';
wwv_flow_imp.g_varchar2_table(60) := '656E646F626F742D6267293B626F726465722D746F703A2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E7465723B6761703A2031327078';
wwv_flow_imp.g_varchar2_table(61) := '3B7D2E6D656E646F626F742D636861742D696E7075742D74657874207B666C65783A20313B6865696768743A20333870783B626F726465723A2031707820736F6C696420766172282D2D6D656E646F626F742D626F72646572293B626F726465722D7261';
wwv_flow_imp.g_varchar2_table(62) := '646975733A20323070783B70616464696E673A203020313670783B666F6E742D73697A653A20313370783B6261636B67726F756E642D636F6C6F723A20236639666166623B636F6C6F723A20766172282D2D6D656E646F626F742D74657874293B6F7574';
wwv_flow_imp.g_varchar2_table(63) := '6C696E653A206E6F6E653B7472616E736974696F6E3A20616C6C20302E32733B7D2E6D656E646F626F742D636861742D696E7075742D746578743A666F637573207B626F726465722D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D61';
wwv_flow_imp.g_varchar2_table(64) := '7279293B6261636B67726F756E642D636F6C6F723A20236666666666663B626F782D736861646F773A2030203020302032707820766172282D2D6D656E646F626F742D7072696D6172792D6C69676874293B7D2E6D656E646F626F742D636861742D7365';
wwv_flow_imp.g_varchar2_table(65) := '6E642D62746E207B77696474683A20333870783B6865696768743A20333870783B626F726465722D7261646975733A203530253B6261636B67726F756E642D636F6C6F723A20766172282D2D6D656E646F626F742D7072696D617279293B636F6C6F723A';
wwv_flow_imp.g_varchar2_table(66) := '20236666666666663B626F726465723A206E6F6E653B637572736F723A20706F696E7465723B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E7465723B6A7573746966792D636F6E74656E743A2063656E7465723B7472616E';
wwv_flow_imp.g_varchar2_table(67) := '736974696F6E3A20616C6C20302E32733B7D2E6D656E646F626F742D636861742D73656E642D62746E3A686F766572207B6261636B67726F756E642D636F6C6F723A207267626128302C2037372C203135332C20302E39293B7D2E6D656E646F626F742D';
wwv_flow_imp.g_varchar2_table(68) := '636861742D73656E642D62746E3A64697361626C6564207B6261636B67726F756E642D636F6C6F723A20236431643564623B637572736F723A206E6F742D616C6C6F7765643B7D2E6D656E646F626F742D636861742D696E7075742D746578743A646973';
wwv_flow_imp.g_varchar2_table(69) := '61626C6564207B6261636B67726F756E642D636F6C6F723A20236633663466363B636F6C6F723A20233963613361663B637572736F723A206E6F742D616C6C6F7765643B7D2E6D656E646F626F742D747970696E672D696E64696361746F72202E6D656E';
wwv_flow_imp.g_varchar2_table(70) := '646F626F742D6D73672D627562626C65207B70616464696E673A203132707820313670783B646973706C61793A20666C65783B616C69676E2D6974656D733A2063656E7465723B6761703A203470783B626F726465722D7261646975733A20313470783B';
wwv_flow_imp.g_varchar2_table(71) := '626F726465722D626F74746F6D2D6C6566742D7261646975733A203270783B7D2E6D656E646F626F742D747970696E672D696E64696361746F72202E646F74207B77696474683A203670783B6865696768743A203670783B6261636B67726F756E642D63';
wwv_flow_imp.g_varchar2_table(72) := '6F6C6F723A20233963613361663B626F726465722D7261646975733A203530253B646973706C61793A20696E6C696E652D626C6F636B3B616E696D6174696F6E3A206A756D7020312E347320696E66696E69746520656173652D696E2D6F757420626F74';
wwv_flow_imp.g_varchar2_table(73) := '683B7D2E6D656E646F626F742D747970696E672D696E64696361746F72202E646F743A6E74682D6368696C64283129207B616E696D6174696F6E2D64656C61793A202D302E3332733B7D2E6D656E646F626F742D747970696E672D696E64696361746F72';
wwv_flow_imp.g_varchar2_table(74) := '202E646F743A6E74682D6368696C64283229207B616E696D6174696F6E2D64656C61793A202D302E3136733B7D406B65796672616D6573206A756D70207B30252C203830252C2031303025207B207472616E73666F726D3A207363616C652830293B207D';
wwv_flow_imp.g_varchar2_table(75) := '343025207B207472616E73666F726D3A207363616C65283129207472616E736C61746559282D367078293B207D7D406D6564696120286D61782D77696474683A20343830707829207B2E6D656E646F626F742D636861742D77726170706572207B626F74';
wwv_flow_imp.g_varchar2_table(76) := '746F6D3A20313670783B72696768743A20313670783B7D2E6D656E646F626F742D636861742D626F78207B77696474683A2063616C63283130307677202D2033327078293B6865696768743A2063616C63283130307668202D203132307078293B626F74';
wwv_flow_imp.g_varchar2_table(77) := '746F6D3A20363470783B7D7D';
null;
end;
/
begin
wwv_flow_imp_shared.create_plugin_file(
 p_id=>wwv_flow_imp.id(3542136966719801)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_file_name=>'mendobot-chat.min.css'
,p_mime_type=>'text/css'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_imp.varchar2_to_blob(wwv_flow_imp.g_varchar2_table)
);
end;
/
begin
wwv_flow_imp.g_varchar2_table := wwv_flow_imp.empty_varchar2_table;
wwv_flow_imp.g_varchar2_table(1) := '66756E6374696F6E206D656E646F626F7443686174496E697428652C6E2C74297B617065782E726567696F6E2E63726561746528226D656E646F626F742D636861742D636F6E7461696E65722D222B652C7B747970653A224D656E646F626F7443686174';
wwv_flow_imp.g_varchar2_table(2) := '222C7769646765743A66756E6374696F6E28297B72657475726E20617065782E6A51756572792822236D656E646F626F742D636861742D636F6E7461696E65722D222B65297D7D293B636F6E7374206F3D646F63756D656E742E676574456C656D656E74';
wwv_flow_imp.g_varchar2_table(3) := '4279496428226D656E646F626F742D636861742D746F67676C652D222B65292C733D646F63756D656E742E676574456C656D656E744279496428226D656E646F626F742D636861742D636C6F73652D222B65292C643D646F63756D656E742E676574456C';
wwv_flow_imp.g_varchar2_table(4) := '656D656E744279496428226D656E646F626F742D636861742D77696E646F772D222B65292C613D646F63756D656E742E676574456C656D656E744279496428226D656E646F626F742D636861742D696E7075742D222B65292C633D646F63756D656E742E';
wwv_flow_imp.g_varchar2_table(5) := '676574456C656D656E744279496428226D656E646F626F742D636861742D73656E642D222B65292C6D3D646F63756D656E742E676574456C656D656E744279496428226D656E646F626F742D636861742D6D657373616765732D222B65293B66756E6374';
wwv_flow_imp.g_varchar2_table(6) := '696F6E206928297B6D2E7363726F6C6C546F703D6D2E7363726F6C6C4865696768747D66756E6374696F6E206C28297B636F6E7374206F3D612E76616C75653B696628216F7C7C216F2E7472696D28292972657475726E3B612E76616C75653D22222C61';
wwv_flow_imp.g_varchar2_table(7) := '2E64697361626C65643D21302C632E64697361626C65643D21303B636F6E737420733D286E65772044617465292E746F4C6F63616C6554696D65537472696E67285B5D2C7B686F75723A22322D6469676974222C6D696E7574653A22322D646967697422';
wwv_flow_imp.g_varchar2_table(8) := '7D292C643D646F63756D656E742E637265617465456C656D656E74282264697622293B642E636C6173734E616D653D226D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D75736572222C642E696E6E657248544D4C3D605C6E20';
wwv_flow_imp.g_varchar2_table(9) := '20202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E5C6E20202020202020202020202020202020247B617065782E7574696C2E65736361706548544D4C286F297D5C6E20202020202020202020';
wwv_flow_imp.g_varchar2_table(10) := '20203C2F6469763E5C6E2020202020202020202020203C7370616E20636C6173733D226D656E646F626F742D6D73672D74696D65223E247B737D3C2F7370616E3E5C6E2020202020202020602C6D2E617070656E644368696C642864292C6928293B636F';
wwv_flow_imp.g_varchar2_table(11) := '6E7374206C3D646F63756D656E742E637265617465456C656D656E74282264697622293B6C2E636C6173734E616D653D226D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D626F74206D656E646F626F742D747970696E672D69';
wwv_flow_imp.g_varchar2_table(12) := '6E64696361746F72222C6C2E69643D226D656E646F626F742D747970696E672D222B652C6C2E696E6E657248544D4C3D275C6E2020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E5C6E2020';
wwv_flow_imp.g_varchar2_table(13) := '20202020202020202020202020203C7370616E20636C6173733D22646F74223E3C2F7370616E3E5C6E202020202020202020202020202020203C7370616E20636C6173733D22646F74223E3C2F7370616E3E5C6E20202020202020202020202020202020';
wwv_flow_imp.g_varchar2_table(14) := '3C7370616E20636C6173733D22646F74223E3C2F7370616E3E5C6E2020202020202020202020203C2F6469763E5C6E2020202020202020272C6D2E617070656E644368696C64286C292C6928292C617065782E7365727665722E706C7567696E286E2C7B';
wwv_flow_imp.g_varchar2_table(15) := '7830313A6F2C7830333A742C705F646573745F726567696F6E5F69643A747D2C7B7461726765743A646F63756D656E742E676574456C656D656E744279496428226D656E646F626F742D636861742D636F6E7461696E65722D222B65292C737563636573';
wwv_flow_imp.g_varchar2_table(16) := '733A66756E6374696F6E286E297B636F6E737420743D646F63756D656E742E676574456C656D656E744279496428226D656E646F626F742D747970696E672D222B65293B696628742626742E72656D6F766528292C612E64697361626C65643D21312C63';
wwv_flow_imp.g_varchar2_table(17) := '2E64697361626C65643D21312C612E666F63757328292C6E2E73756363657373297B636F6E737420743D646F63756D656E742E637265617465456C656D656E74282264697622293B742E636C6173734E616D653D226D656E646F626F742D6D6573736167';
wwv_flow_imp.g_varchar2_table(18) := '65206D656E646F626F742D6D73672D626F74222C742E696E6E657248544D4C3D605C6E2020202020202020202020202020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E5C6E202020202020';
wwv_flow_imp.g_varchar2_table(19) := '20202020202020202020202020202020202020202020247B6E2E7265737075657374617D5C6E2020202020202020202020202020202020202020202020203C2F6469763E5C6E2020202020202020202020202020202020202020202020203C7370616E20';
wwv_flow_imp.g_varchar2_table(20) := '636C6173733D226D656E646F626F742D6D73672D74696D65223E247B737D3C2F7370616E3E5C6E2020202020202020202020202020202020202020602C6D2E617070656E644368696C642874292C6928293B7472797B617065782E726567696F6E286529';
wwv_flow_imp.g_varchar2_table(21) := '2E7265667265736828297D63617463682865297B7D7D656C73657B636F6E737420653D646F63756D656E742E637265617465456C656D656E74282264697622293B652E636C6173734E616D653D226D656E646F626F742D6D657373616765206D656E646F';
wwv_flow_imp.g_varchar2_table(22) := '626F742D6D73672D6572726F72222C652E696E6E657248544D4C3D605C6E2020202020202020202020202020202020202020202020203C64697620636C6173733D226D656E646F626F742D6D73672D627562626C65223E5C6E2020202020202020202020';
wwv_flow_imp.g_varchar2_table(23) := '20202020202020202020202020202020203C7374726F6E673E4572726F722064656C2053697374656D613A3C2F7374726F6E673E3C62723E247B617065782E7574696C2E65736361706548544D4C286E2E726573707565737461297D5C6E202020202020';
wwv_flow_imp.g_varchar2_table(24) := '2020202020202020202020202020202020203C2F6469763E5C6E2020202020202020202020202020202020202020202020203C7370616E20636C6173733D226D656E646F626F742D6D73672D74696D65223E247B737D3C2F7370616E3E5C6E2020202020';
wwv_flow_imp.g_varchar2_table(25) := '202020202020202020202020202020602C6D2E617070656E644368696C642865292C6928297D7D2C6572726F723A66756E6374696F6E286E2C742C6F297B636F6E737420643D646F63756D656E742E676574456C656D656E744279496428226D656E646F';
wwv_flow_imp.g_varchar2_table(26) := '626F742D747970696E672D222B65293B642626642E72656D6F766528292C612E64697361626C65643D21312C632E64697361626C65643D21312C612E666F63757328293B636F6E7374206C3D646F63756D656E742E637265617465456C656D656E742822';
wwv_flow_imp.g_varchar2_table(27) := '64697622293B6C2E636C6173734E616D653D226D656E646F626F742D6D657373616765206D656E646F626F742D6D73672D6572726F72222C6C2E696E6E657248544D4C3D605C6E20202020202020202020202020202020202020203C64697620636C6173';
wwv_flow_imp.g_varchar2_table(28) := '733D226D656E646F626F742D6D73672D627562626C65223E5C6E2020202020202020202020202020202020202020202020204572726F7220646520636F6D756E6963616369C3B36E2064652072656420616C2070726F636573617220656C206368617420';
wwv_flow_imp.g_varchar2_table(29) := '666C6F74616E74652E20496E74656E7465206DC3A1732074617264652E5C6E20202020202020202020202020202020202020203C2F6469763E5C6E20202020202020202020202020202020202020203C7370616E20636C6173733D226D656E646F626F74';
wwv_flow_imp.g_varchar2_table(30) := '2D6D73672D74696D65223E247B737D3C2F7370616E3E5C6E20202020202020202020202020202020602C6D2E617070656E644368696C64286C292C6928297D7D297D6F2626642626286F2E6164644576656E744C697374656E65722822636C69636B222C';
wwv_flow_imp.g_varchar2_table(31) := '66756E6374696F6E2865297B652E70726576656E7444656661756C7428292C652E73746F7050726F7061676174696F6E28292C642E636C6173734C6973742E746F67676C6528226D656E646F626F742D636861742D68696464656E22292C642E636C6173';
wwv_flow_imp.g_varchar2_table(32) := '734C6973742E636F6E7461696E7328226D656E646F626F742D636861742D68696464656E22297C7C28612E666F63757328292C692829297D292C732E6164644576656E744C697374656E65722822636C69636B222C66756E6374696F6E2865297B652E70';
wwv_flow_imp.g_varchar2_table(33) := '726576656E7444656661756C7428292C652E73746F7050726F7061676174696F6E28292C642E636C6173734C6973742E61646428226D656E646F626F742D636861742D68696464656E22297D292C632E6164644576656E744C697374656E65722822636C';
wwv_flow_imp.g_varchar2_table(34) := '69636B222C66756E6374696F6E28297B6C28297D292C612E6164644576656E744C697374656E657228226B6579646F776E222C66756E6374696F6E2865297B22456E746572223D3D3D652E6B6579262628652E70726576656E7444656661756C7428292C';
wwv_flow_imp.g_varchar2_table(35) := '6C2829297D29297D';
null;
end;
/
begin
wwv_flow_imp_shared.create_plugin_file(
 p_id=>wwv_flow_imp.id(2587862460833503)
,p_plugin_id=>wwv_flow_imp.id(2585571389823303)
,p_file_name=>'mendobot-chat.min.js'
,p_mime_type=>'text/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_imp.varchar2_to_blob(wwv_flow_imp.g_varchar2_table)
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
