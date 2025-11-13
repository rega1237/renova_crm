import { Controller } from "@hotwired/stimulus"

// Handles click-to-call flow with Twilio via API
export default class extends Controller {
  static targets = ["button", "status", "selection"]
  // Compatibilidad: clientId/clientName siguen funcionando para clientes.
  // Generalización: entityType, entityId y preparePath permiten usar este controlador con otros modelos.
  static values = { clientId: Number, toNumber: String, clientName: String, entityType: String, entityId: Number, preparePath: String }

  csrfToken() {
    const el = document.querySelector('meta[name="csrf-token"]')
    return el ? el.getAttribute('content') : null
  }

  async parseResponse(r) {
    const contentType = r.headers.get('Content-Type') || ""
    const isJson = contentType.includes('application/json')
    try {
      const data = isJson ? await r.json() : await r.text()
      return { ok: r.ok, status: r.status, data, isJson }
    } catch (e) {
      // Evitar "Unexpected end of JSON input" cuando la respuesta no es JSON
      return { ok: r.ok, status: r.status, data: null, isJson }
    }
  }

  async start(event) {
    event.preventDefault()
    const btn = this.buttonTarget || this.element
    this.setLoading(btn, true)
    this.setStatus("Preparando llamada…", "text-yellow-700")

    try {
      const endpoint = this.preparePathValue || "/api/voice/prepare"
      const r = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin",
        body: JSON.stringify(this.buildPreparePayload())
      })
      const { ok, data, status, isJson } = await this.parseResponse(r)
      if (!ok) {
        if (status === 401) {
          this.setStatus("No autorizado. Inicia sesión para realizar llamadas.", "text-red-700")
        } else {
          this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
        }
        return
      }
      if (data.need_selection) {
        this.renderSelection(data.alternatives, data.client_state)
        this.setLoading(btn, false)
        this.setStatus("Selecciona un número de origen", "text-blue-700")
        return
      }

      // WebRTC: conectar navegador ↔ cliente
      await this.connectViaWebrtc({
        from: data.selected_number,
        to: data.to_number || this.toNumberValue,
        clientId: this.currentEntityId()
      })
    } catch (err) {
      console.error(err)
      this.setStatus("Error de red al preparar la llamada", "text-red-700")
    } finally {
      this.setLoading(btn, false)
    }
  }

  async selectNumber(event) {
    const fromNumber = event.params.phone
    const btn = this.buttonTarget || this.element
    this.setLoading(btn, true)
    this.setStatus("Preparando…", "text-yellow-700")
    try {
      const endpoint = this.preparePathValue || "/api/voice/prepare"
      const r = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin",
        body: JSON.stringify(this.buildPreparePayload(fromNumber))
      })
      const { ok, data, status, isJson } = await this.parseResponse(r)
      if (!ok) {
        if (status === 401) {
          this.setStatus("No autorizado. Inicia sesión para realizar llamadas.", "text-red-700")
        } else {
          this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
        }
        return
      }
      if (data.success) {
        this.selectionTarget.innerHTML = ""
        this.selectionTarget.classList.add("hidden")
        await this.connectViaWebrtc({
          from: data.selected_number,
          to: data.to_number || this.toNumberValue,
          clientId: this.currentEntityId()
        })
      } else {
        this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
      }
    } catch (err) {
      console.error(err)
      this.setStatus("Error de red al preparar la llamada", "text-red-700")
    } finally {
      this.setLoading(btn, false)
    }
  }

  // Construye el payload para /api/.../prepare según la entidad
  buildPreparePayload(fromNumber = null) {
    const payload = {
      to_number: this.toNumberValue
    }

    // Enviar la llave correcta según el tipo de entidad
    const type = (this.entityTypeValue || "client").toString()
    const id = this.currentEntityId()
    if (type === "contact_list") {
      payload.contact_list_id = id
    } else {
      // Compatibilidad con clientes
      payload.client_id = id || this.clientIdValue
    }

    if (fromNumber) payload.from_number = fromNumber
    return payload
  }

  // Obtiene el ID de la entidad actual, ya sea entityId o clientId (fallback)
  currentEntityId() {
    return this.entityIdValue || this.clientIdValue || null
  }

  renderSelection(alternatives, clientState = null) {
    const container = this.selectionTarget
    container.classList.remove("hidden")
    
    let headerText = "Selecciona el número de origen:"
    if (clientState) {
      headerText += ` Cliente en ${clientState}, no hay números coincidentes.`
    }
    
    container.innerHTML = `
      <div class="mt-2 p-2 border rounded-md bg-gray-50">
        <p class="text-xs text-gray-600 mb-1">${headerText}</p>
        <div class="flex flex-wrap gap-2">
          ${alternatives.map(a => `
            <button data-action="click->call#selectNumber" data-call-phone-param="${a.phone_number}" class="px-2 py-1 text-xs rounded-md bg-blue-600 text-white hover:bg-blue-700">
              ${a.formatted || `${a.phone_number} (${a.state})`}
            </button>
          `).join('')}
        </div>
      </div>
    `
  }

  setLoading(btn, loading) {
    if (!btn) return
    btn.disabled = loading
    btn.classList.toggle("opacity-60", loading)
  }

  setStatus(text, colorClass) {
    if (!this.statusTarget) return
    this.statusTarget.textContent = text
    this.statusTarget.className = `text-xs font-poppins ${colorClass}`
  }

  async connectViaWebrtc({ from, to, clientId }) {
    // SDK v2: el archivo twilio-voice.min.js expone Twilio.Device en window
    if (!window.Twilio || !window.Twilio.Device) {
      this.setStatus("SDK de Twilio (v2) no cargado", "text-red-700")
      return
    }

    this.setStatus("Conectando…", "text-yellow-700")

    // Pre-solicitar permiso de micrófono para evitar fallos del primer intento.
    try {
      const gumStream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true }
      })
      // Cerramos inmediatamente las pistas para no dejar el micro abierto.
      gumStream.getTracks().forEach(t => t.stop())
    } catch (e) {
      this.setStatus(`Permiso de micrófono requerido: ${e.message || e}`, "text-red-700")
      return
    }

    // Obtener token
    const r = await fetch("/api/twilio/voice/token", {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin"
    })
    const { ok, data } = await this.parseResponse(r)
    if (!ok || !data?.token) {
      this.setStatus((data && data.error) ? data.error : "No se pudo obtener el token", "text-red-700")
      return
    }

    // Inicializar dispositivo (reutiliza si ya existe)
    if (!this.device) {
      // Crear el Device y esperar a que esté listo antes de conectar.
      // Twilio Voice SDK v2
      this.device = new window.Twilio.Device(data.token, {
        logLevel: "info",
        enableRingingState: true
        // Nota: a partir de v2.15 se usa setCodecPreferences en el objeto Call.
        // Evitamos codecPreferences aquí para compatibilidad futura.
      })

      // SDK v2: muchas integraciones usan registro explícito.
      // Esto ayuda a establecer conectividad con los servicios de Twilio y dispara eventos de estado.
      if (typeof this.device.register === "function") {
        try { this.device.register() } catch (_) {}
      }

      // Eventos de estado (v2)
      this.device.on("ready", () => this.setStatus("SDK inicializado", "text-green-700"))
      this.device.on("registered", () => this.setStatus("Registrado con Twilio", "text-green-700"))
      this.device.on("unregistered", () => this.setStatus("No registrado", "text-red-700"))
      this.device.on("error", (e) => {
        console.error("Twilio.Device error", e)
        this.setStatus(`Error de dispositivo: ${e.message || e}`, "text-red-700")
      })
      this.device.on("warning", (e) => this.setStatus(`Advertencia del dispositivo: ${e.message || e}`, "text-yellow-700"))
      this.device.on("offline", () => this.setStatus("Desconectado", "text-red-700"))
      this.device.on("connect", () => this.setStatus("Conectado", "text-green-700"))
      this.device.on("disconnect", () => {
        this.setStatus("Llamada finalizada", "text-gray-700")
        this.teardownDevice()
      })

      try {
        await this.waitForDeviceReady(this.device)
      } catch (e) {
        // En v2, algunos entornos no emiten "ready"/"registered" a tiempo.
        // No bloqueamos la conexión: continuamos e intentamos conectar.
        console.warn("Twilio.Device tardó en inicializarse: continuando con connect", e)
        this.setStatus(`Inicializando lentamente (continuando): ${e.message || e}`, "text-yellow-700")
      }
    } else {
      // Actualiza el token para sesiones previas y continúa.
      // Si el dispositivo está destruido o updateToken falla, lo recreamos.
      if (typeof this.device.updateToken === "function") {
        try {
          this.device.updateToken(data.token)
        } catch (e) {
          console.warn("updateToken falló; recreando Twilio.Device", e)
          try { this.device?.destroy?.() } catch (_) {}
          this.device = new window.Twilio.Device(data.token, {
            logLevel: "info",
            enableRingingState: true
          })
          if (typeof this.device.register === "function") {
            try { this.device.register() } catch (_) {}
          }
          this.device.on("ready", () => this.setStatus("SDK inicializado", "text-green-700"))
          this.device.on("registered", () => this.setStatus("Registrado con Twilio", "text-green-700"))
          this.device.on("unregistered", () => this.setStatus("No registrado", "text-red-700"))
          this.device.on("error", (e) => {
            console.error("Twilio.Device error", e)
            this.setStatus(`Error de dispositivo: ${e.message || e}`, "text-red-700")
          })
          this.device.on("warning", (e) => this.setStatus(`Advertencia del dispositivo: ${e.message || e}`, "text-yellow-700"))
          this.device.on("offline", () => this.setStatus("Desconectado", "text-red-700"))
          this.device.on("connect", () => this.setStatus("Conectado", "text-green-700"))
          this.device.on("disconnect", () => {
            this.setStatus("Llamada finalizada", "text-gray-700")
            this.teardownDevice()
          })
          try {
            await this.waitForDeviceReady(this.device)
          } catch (e2) {
            console.warn("Twilio.Device tardó en inicializarse tras recreación: continuando", e2)
            this.setStatus(`Inicializando lentamente (continuando): ${e2.message || e2}`, "text-yellow-700")
          }
        }
      } else {
        // Si no existe updateToken, recreamos por seguridad.
        try { this.device?.destroy?.() } catch (_) {}
        this.device = new window.Twilio.Device(data.token, {
          logLevel: "info",
          enableRingingState: true
        })
        if (typeof this.device.register === "function") {
          try { this.device.register() } catch (_) {}
        }
        this.device.on("ready", () => this.setStatus("SDK inicializado", "text-green-700"))
        this.device.on("registered", () => this.setStatus("Registrado con Twilio", "text-green-700"))
        this.device.on("unregistered", () => this.setStatus("No registrado", "text-red-700"))
        this.device.on("error", (e) => {
          console.error("Twilio.Device error", e)
          this.setStatus(`Error de dispositivo: ${e.message || e}`, "text-red-700")
        })
        this.device.on("warning", (e) => this.setStatus(`Advertencia del dispositivo: ${e.message || e}`, "text-yellow-700"))
        this.device.on("offline", () => this.setStatus("Desconectado", "text-red-700"))
        this.device.on("connect", () => this.setStatus("Conectado", "text-green-700"))
        this.device.on("disconnect", () => {
          this.setStatus("Llamada finalizada", "text-gray-700")
          this.teardownDevice()
        })
        try {
          await this.waitForDeviceReady(this.device)
        } catch (e2) {
          console.warn("Twilio.Device tardó en inicializarse tras recreación: continuando", e2)
          this.setStatus(`Inicializando lentamente (continuando): ${e2.message || e2}`, "text-yellow-700")
        }
      }
    }

    // Conectar: los parámetros se enviarán al webhook /twilio/voice/connect
    // Si hay una conexión previa, asegúrate de cerrarla antes de iniciar otra.
    if (this.connection && typeof this.connection.disconnect === "function") {
      try { this.connection.disconnect() } catch (_) {}
      this.connection = null
    }

    // En SDK v2, Device.connect no garantiza devolver el objeto de llamada.
    // En su lugar, escuchamos el evento 'connect' del Device y recibimos el Call.
    const handleConnect = (call) => {
      this.connection = call
      // Exponer conexión global para la UI de llamada
      window.activeConnection = call
      // Actualizar estado global
      window.CallState = Object.assign({
        inCall: true,
        clientName: this.clientNameValue || null,
        phone: to
      }, window.CallState || {})
      // Eventos de la llamada (Call)
      if (typeof call.on === "function") {
        call.on("accept", () => this.setStatus("Cliente respondió", "text-green-700"))
        // Feedback auditivo: detener ringback al ser aceptada
        call.on("accept", () => window.dispatchEvent(new CustomEvent("call:ui:accepted")))
        // Ringback: indicar que la llamada está sonando
        call.on("ringing", () => {
          this.setStatus("Sonando…", "text-yellow-700")
          window.dispatchEvent(new CustomEvent("call:ui:ringing"))
        })
        call.on("cancel", () => this.setStatus("Llamada cancelada", "text-gray-700"))
        // En cancel/error también detener audio y ocultar UI
        call.on("cancel", () => {
          window.dispatchEvent(new CustomEvent("call:ui:stop-audio"))
          window.dispatchEvent(new CustomEvent("call:ui:hide"))
          this.restoreCallButton()
          window.CallState = Object.assign({}, window.CallState, { inCall: false })
        })
        call.on("disconnect", () => {
          this.setStatus("Llamada finalizada", "text-gray-700")
          // Restaurar UI/botón
          this.restoreCallButton()
          window.CallState = Object.assign({}, window.CallState, { inCall: false })
          window.dispatchEvent(new CustomEvent("call:ui:hide"))
        })
        call.on("error", (e) => {
          console.error("Twilio.Call error", e?.info || e)
          this.setStatus(`Error de llamada: ${e.message || e}`, "text-red-700")
          try { call.disconnect?.() } catch (_) {}
          this.teardownDevice()
          // Restaurar UI/botón en caso de error
          this.restoreCallButton()
          window.CallState = Object.assign({}, window.CallState, { inCall: false })
          window.dispatchEvent(new CustomEvent("call:ui:stop-audio"))
          window.dispatchEvent(new CustomEvent("call:ui:hide"))
        })
      } else {
        // Si no hay API de eventos, nos limitamos a actualizar estado.
        this.setStatus("Llamando…", "text-yellow-700")
      }
    }

    // Validación de parámetros antes de iniciar la llamada
    if (!to) {
      this.setStatus("Parámetro 'To' vacío: selecciona el número del cliente.", "text-red-700")
      return
    }

    // Asegura que capturamos el próximo connect.
    this.device.once?.("connect", handleConnect)

    // Iniciar la llamada; en SDK v2 los parámetros personalizados deben ir en 'params'
    // Serán reenviados a /twilio/voice/connect
    // Guardar referencia global al Device para el controlador de UI
    window.twilioDevice = this.device

    // Mostrar inmediatamente la UI de llamada y ocultar el botón original
    this.hideCallButton()
    const uiDetail = { name: this.clientNameValue || "", phone: to }
    window.CallState = Object.assign({ inCall: true, clientName: uiDetail.name, phone: uiDetail.phone }, window.CallState || {})
    window.dispatchEvent(new CustomEvent("call:ui:show", { detail: uiDetail }))

    // Construir parámetros personalizados según el tipo de entidad
    const params = {
      To: to,
      caller_id: from
    }
    const entityType = (this.entityTypeValue || "client").toString()
    if (entityType === "contact_list") {
      // Para llamadas a ContactList, enviar contact_list_id
      params.contact_list_id = clientId
    } else {
      // Compatibilidad: para clientes, enviar client_id
      params.client_id = clientId
    }

    this.device.connect({ params })
  }

  // Espera a que Twilio.Device emita "ready" antes de intentar conectar.
  async waitForDeviceReady(device) {
    return new Promise((resolve, reject) => {
      let settled = false
      const timeout = setTimeout(() => {
        if (!settled) {
          settled = true
          // En SDK v2 el evento "ready" puede no dispararse en algunos flujos.
          // Si se agota el tiempo, seguimos adelante: el connect suele funcionar igualmente.
          // Aun así, informamos del retraso.
          reject(new Error("El SDK no se inicializó a tiempo (esperando ready/registered)"))
        }
      }, 12000)

      const onReady = () => {
        if (!settled) {
          settled = true
          clearTimeout(timeout)
          resolve()
        }
      }

      // Aceptamos tanto "ready" como "registered" como señal de inicialización.
      if (typeof device.once === "function") {
        device.once("ready", onReady)
        device.once("registered", onReady)
        device.once("error", (e) => {
          if (!settled) {
            settled = true
            clearTimeout(timeout)
            reject(e)
          }
        })
      } else {
        // Fallback: si el SDK no tiene once, resolvemos de inmediato.
        try { resolve() } catch (_) {}
      }
    })
  }

  teardownDevice() {
    // Cierra conexiones y destruye el Device para liberar el micrófono/estado.
    try { this.device?.disconnectAll?.() } catch (_) {}
    try { this.device?.destroy?.() } catch (_) {}
    this.device = null
    this.connection = null
  }

  hideCallButton() {
    try {
      const btn = this.buttonTarget || this.element
      if (btn) btn.classList.add("hidden")
    } catch (_) {}
  }

  restoreCallButton() {
    try {
      const btn = this.buttonTarget || this.element
      if (btn) btn.classList.remove("hidden")
    } catch (_) {}
    // También intentar restaurar cualquier otro botón de llamada presente en la vista actual
    document.querySelectorAll('[data-controller="call"] [data-call-target="button"]').forEach((el) => el.classList.remove('hidden'))
  }
}