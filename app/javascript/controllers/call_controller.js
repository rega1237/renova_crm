import { Controller } from "@hotwired/stimulus"

// Handles click-to-call flow with Twilio via API
export default class extends Controller {
  static targets = ["button", "status", "selection"]
  static values = { clientId: Number, toNumber: String }

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
      const r = await fetch("/api/voice/prepare", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin",
        body: JSON.stringify({
          client_id: this.clientIdValue,
          to_number: this.toNumberValue
        })
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
        clientId: this.clientIdValue
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
      const r = await fetch("/api/voice/prepare", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin",
        body: JSON.stringify({
          client_id: this.clientIdValue,
          to_number: this.toNumberValue,
          from_number: fromNumber
        })
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
          clientId: this.clientIdValue
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
        logLevel: "debug",
        enableRingingState: true
        // Nota: a partir de v2.15 se usa setCodecPreferences en el objeto Call.
        // Evitamos codecPreferences aquí para compatibilidad futura.
      })

      this.device.on("ready", () => this.setStatus("Listo para llamar", "text-green-700"))
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
        this.setStatus(`No se pudo inicializar el dispositivo: ${e.message || e}`, "text-red-700")
        return
      }
    } else {
      // Actualiza el token para sesiones previas y continúa.
      if (typeof this.device.updateToken === "function") {
        this.device.updateToken(data.token)
      }
    }

    // Conectar: los parámetros se enviarán al webhook /twilio/voice/connect
    // Si hay una conexión previa, asegúrate de cerrarla antes de iniciar otra.
    if (this.connection && typeof this.connection.disconnect === "function") {
      try { this.connection.disconnect() } catch (_) {}
      this.connection = null
    }

    const conn = this.device.connect({
      To: to,
      From: from,
      client_id: clientId
    })

    this.connection = conn
    conn.on("accept", () => this.setStatus("Cliente respondió", "text-green-700"))
    conn.on("cancel", () => this.setStatus("Llamada cancelada", "text-gray-700"))
    conn.on("error", (e) => {
      console.error("Twilio.Call error", e?.info || e)
      this.setStatus(`Error de llamada: ${e.message || e}`, "text-red-700")
      try { conn.disconnect() } catch (_) {}
      this.teardownDevice()
    })
  }

  // Espera a que Twilio.Device emita "ready" antes de intentar conectar.
  async waitForDeviceReady(device) {
    return new Promise((resolve, reject) => {
      let settled = false
      const timeout = setTimeout(() => {
        if (!settled) {
          settled = true
          reject(new Error("El SDK no se inicializó a tiempo"))
        }
      }, 8000)

      device.once("ready", () => {
        if (!settled) {
          settled = true
          clearTimeout(timeout)
          resolve()
        }
      })
      device.once("error", (e) => {
        if (!settled) {
          settled = true
          clearTimeout(timeout)
          reject(e)
        }
      })
    })
  }

  teardownDevice() {
    // Cierra conexiones y destruye el Device para liberar el micrófono/estado.
    try { this.device?.disconnectAll?.() } catch (_) {}
    try { this.device?.destroy?.() } catch (_) {}
    this.device = null
    this.connection = null
  }
}