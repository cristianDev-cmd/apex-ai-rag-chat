/**
 * PLUGIN CHAT AI - CLIENT SIDE SCRIPT
 * Desarrollado con soporte completo nativo para Oracle APEX.
 * Autor: Cristian Alcántara
 * Licencia: Gratis / Open Source
 */

function mendobotChatInit(pRegionId, pAjaxIdentifier, pInternalRegionId) {
    // Register the region in APEX region registry
    apex.region.create("mendobot-chat-container-" + pRegionId, {
        type: "MendobotChat",
        widget: function() {
            return apex.jQuery("#mendobot-chat-container-" + pRegionId);
        }
    });

    const toggleBtn = document.getElementById('mendobot-chat-toggle-' + pRegionId);
    const closeBtn = document.getElementById('mendobot-chat-close-' + pRegionId);
    const chatBox = document.getElementById('mendobot-chat-window-' + pRegionId);
    const chatInput = document.getElementById('mendobot-chat-input-' + pRegionId);
    const sendBtn = document.getElementById('mendobot-chat-send-' + pRegionId);
    const chatBody = document.getElementById('mendobot-chat-messages-' + pRegionId);

    if (!toggleBtn || !chatBox) return;

    // Manejo de eventos de apertura y cierre con foco dinámico
    toggleBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        chatBox.classList.toggle('mendobot-chat-hidden');
        if (!chatBox.classList.contains('mendobot-chat-hidden')) {
            chatInput.focus();
            scrollToBottom();
        }
    });

    closeBtn.addEventListener('click', function(e) {
        e.preventDefault();
        e.stopPropagation();
        chatBox.classList.add('mendobot-chat-hidden');
    });

    // Enviar mensaje en click o pulsar Enter
    sendBtn.addEventListener('click', function() {
        enviarMensaje();
    });

    chatInput.addEventListener('keydown', function(e) {
        if (e.key === 'Enter') {
            e.preventDefault();
            enviarMensaje();
        }
    });

    // Desplazamiento automático inteligente hacia el fondo del contenedor
    function scrollToBottom() {
        chatBody.scrollTop = chatBody.scrollHeight;
    }

    // Proceso asíncrono seguro integrado con APEX Server API
    function enviarMensaje() {
        const text = chatInput.value;
        if (!text || !text.trim()) return;

        // Deshabilitar entradas temporalmente para evitar peticiones duplicadas (double-submit)
        chatInput.value = '';
        chatInput.disabled = true;
        sendBtn.disabled = true;

        const vHora = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});

        // Renderizar burbuja del usuario escapando HTML para blindaje XSS total
        const userMsgDiv = document.createElement('div');
        userMsgDiv.className = 'mendobot-message mendobot-msg-user';
        userMsgDiv.innerHTML = `
            <div class="mendobot-msg-bubble">
                ${apex.util.escapeHTML(text)}
            </div>
            <span class="mendobot-msg-time">${vHora}</span>
        `;
        chatBody.appendChild(userMsgDiv);
        scrollToBottom();

        // Inyectar animador de escritura (Typing Indicator) para mejorar la UX/Aesthetics
        const loadingDiv = document.createElement('div');
        loadingDiv.className = 'mendobot-message mendobot-msg-bot mendobot-typing-indicator';
        loadingDiv.id = 'mendobot-typing-' + pRegionId;
        loadingDiv.innerHTML = `
            <div class="mendobot-msg-bubble">
                <span class="dot"></span>
                <span class="dot"></span>
                <span class="dot"></span>
            </div>
        `;
        chatBody.appendChild(loadingDiv);
        scrollToBottom();

        // Canal de conexión oficial asíncrono para Plugins en APEX
        apex.server.plugin(pAjaxIdentifier, {
            x01: text,
            x03: pInternalRegionId,
            p_dest_region_id: pInternalRegionId
        }, {
            target: document.getElementById("mendobot-chat-container-" + pRegionId),
            success: function(pData) {
                // Remover indicador de carga
                const typing = document.getElementById('mendobot-typing-' + pRegionId);
                if (typing) typing.remove();

                // Habilitar controles
                chatInput.disabled = false;
                sendBtn.disabled = false;
                chatInput.focus();

                if (pData.success) {
                    // Renderizar la respuesta formateada de la IA
                    const botMsgDiv = document.createElement('div');
                    botMsgDiv.className = 'mendobot-message mendobot-msg-bot';
                    botMsgDiv.innerHTML = `
                        <div class="mendobot-msg-bubble">
                            ${pData.respuesta}
                        </div>
                        <span class="mendobot-msg-time">${vHora}</span>
                    `;
                    chatBody.appendChild(botMsgDiv);
                    scrollToBottom();
                    
                    // Refrescar componente APEX
                    try {
                        apex.region(pRegionId).refresh();
                    } catch(e) {
                        // Silenciar error en caso de que no tenga elemento region contenedor
                    }
                } else {
                    // burbuja de error SaaS
                    const errorMsgDiv = document.createElement('div');
                    errorMsgDiv.className = 'mendobot-message mendobot-msg-error';
                    errorMsgDiv.innerHTML = `
                        <div class="mendobot-msg-bubble">
                            <strong>Error del Sistema:</strong><br>${apex.util.escapeHTML(pData.respuesta)}
                        </div>
                        <span class="mendobot-msg-time">${vHora}</span>
                    `;
                    chatBody.appendChild(errorMsgDiv);
                    scrollToBottom();
                }
            },
            error: function(xhr, status, error) {
                // Remover indicador y reactivar
                const typing = document.getElementById('mendobot-typing-' + pRegionId);
                if (typing) typing.remove();

                chatInput.disabled = false;
                sendBtn.disabled = false;
                chatInput.focus();

                const errorMsgDiv = document.createElement('div');
                errorMsgDiv.className = 'mendobot-message mendobot-msg-error';
                errorMsgDiv.innerHTML = `
                    <div class="mendobot-msg-bubble">
                        Error de comunicación de red al procesar el chat flotante. Intente más tarde.
                    </div>
                    <span class="mendobot-msg-time">${vHora}</span>
                `;
                chatBody.appendChild(errorMsgDiv);
                scrollToBottom();
            }
        });
    }
}
