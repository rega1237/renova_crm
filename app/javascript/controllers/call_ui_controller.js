import { Controller } from "@hotwired/stimulus"

// Handles the fixed call UI, independent of where it's rendered.
// Interacts with global window.twilioDevice and window.activeConnection created by call_controller.
export default class extends Controller {
  static targets = ["container", "name", "phone", "status", "hangupButton", "answerButton"]
  // CSRF helper (igual que en otros controladores)
  csrfToken() {
    const meta = document.querySelector("meta[name=csrf-token]");
    return meta ? meta.getAttribute("content") : ""
  }
  connect() {
    // Initialize global state if missing (minimal)
    window.CallState = window.CallState || { inCall: false }

    // Restore UI if a call is already active (Turbo navigation)
    if (window.CallState.inCall) {
      this.render(window.CallState.clientName, window.CallState.phone, "Conectado")
    }

    // Listen for UI events from call_controller
    this.onShow = (e) => {
      const { name, phone, direction } = e.detail || {}
      const hasIncomingPending = !!(window.activeIncomingCall && typeof window.activeIncomingCall.accept === "function" && !window.CallState?.inCall)
      // Mantener modo entrante si hay llamada pendiente o si el emisor lo indica
      if (hasIncomingPending || direction === "inbound") {
        this.render(name, phone, "Llamada entrante…")
        this.setIncomingMode()
      } else {
        this.render(name, phone, "Llamando…")
        this.setActiveMode()
      }
      // Prepara el contexto de audio para poder reproducir el tono tras interacción del usuario
      this.ensureAudioContext()
    }
    this.onHide = () => {
      this.hide()
      // Re-inicializar el Device para recibir futuras llamadas entrantes
      // (por ejemplo, después de finalizar una llamada saliente que destruyó el Device)
      setTimeout(() => this.initializeIncomingDeviceIfNeeded(), 250)
    }

    // Eventos para feedback auditivo
    this.onRinging = () => this.startRingback()
    this.onAccepted = () => this.stopRingback()
    this.onStopAudio = () => this.stopRingback()

    // Evento específico para llamadas entrantes
    this.onIncoming = (e) => {
      const { name, phone } = e.detail || {}
      this.render(name || "Llamada entrante", phone, "Llamada entrante…")
      this.setIncomingMode()
    }

    window.addEventListener("call:ui:show", this.onShow)
    window.addEventListener("call:ui:hide", this.onHide)
    window.addEventListener("call:ui:ringing", this.onRinging)
    window.addEventListener("call:ui:accepted", this.onAccepted)
    window.addEventListener("call:ui:stop-audio", this.onStopAudio)
    window.addEventListener("call:ui:incoming", this.onIncoming)

    // Inicializar el dispositivo para poder recibir llamadas entrantes
    this.initializeIncomingDeviceIfNeeded()
  }

  disconnect() {
    // Remove listeners to avoid duplicates across Turbo visits
    window.removeEventListener("call:ui:show", this.onShow)
    window.removeEventListener("call:ui:hide", this.onHide)
    window.removeEventListener("call:ui:ringing", this.onRinging)
    window.removeEventListener("call:ui:accepted", this.onAccepted)
    window.removeEventListener("call:ui:stop-audio", this.onStopAudio)
    window.removeEventListener("call:ui:incoming", this.onIncoming)
    this.stopRingback()
  }

  // ===== UI rendering =====
  render(name, phone, statusText) {
    if (name) this.nameTarget.textContent = name
    if (phone) this.phoneTarget.textContent = phone
    if (statusText) {
      this.statusTarget.textContent = statusText
    }
    this.show()
    // No additional controls to update
  }

  show() {
    this.containerTarget.classList.remove("hidden", "opacity-0", "translate-y-2")
    // Animate in
    this.containerTarget.classList.add("opacity-0", "translate-y-2")
    requestAnimationFrame(() => {
      this.containerTarget.classList.remove("opacity-0", "translate-y-2")
    })
  }

  hide() {
    this.containerTarget.classList.add("opacity-0", "translate-y-2")
    setTimeout(() => {
      this.containerTarget.classList.add("hidden")
      this.containerTarget.classList.remove("opacity-0", "translate-y-2")
    }, 180)
    // Asegurar que se detenga el ringback al ocultar
    this.stopRingback()
  }

  // ===== Actions =====

  hangup() {
    try {
      // Detener ringback antes de colgar
      this.stopRingback()
      const conn = window.activeConnection
      const incoming = window.activeIncomingCall
      // Si hay una llamada entrante sin aceptar aún, rechazarla.
      if (incoming && typeof incoming.reject === "function" && !window.CallState?.inCall) {
        try { incoming.reject() } catch (_) {}
      } else if (conn && typeof conn.disconnect === "function") {
        conn.disconnect()
      }
      // Si por algún motivo no tenemos la conexión, colgamos a nivel de Device
      try { window.twilioDevice?.disconnectAll?.() } catch (_) {}
      window.CallState = Object.assign({}, window.CallState, { inCall: false })
      window.dispatchEvent(new CustomEvent("call:ui:hide"))

      // Restaurar botones de llamada (si existen en la vista)
      document.querySelectorAll('[data-controller="call"] [data-call-target="button"]').forEach((el) => el.classList.remove('hidden'))
    } catch (e) {
      console.error("Error al colgar la llamada:", e)
    }
  }

  async answer() {
    try {
      const incoming = window.activeIncomingCall
      if (!incoming || typeof incoming.accept !== "function") {
        console.warn("No hay llamada entrante para aceptar.")
        return
      }
      // Solicitar permiso de micrófono para mejorar la experiencia al responder
      try {
        const gum = navigator.mediaDevices?.getUserMedia
        if (typeof gum === "function") {
          const stream = await gum.call(navigator.mediaDevices, { audio: { echoCancellation: true, noiseSuppression: true } })
          stream.getTracks().forEach(t => t.stop())
        }
      } catch (_) {}
      // Aceptar y cambiar a modo activo
      incoming.accept()
      this.setActiveMode()
      window.CallState = Object.assign({}, window.CallState, { inCall: true })
      window.dispatchEvent(new CustomEvent("call:ui:accepted"))
      // Exponer como conexión activa si la API lo permite
      window.activeConnection = incoming
    } catch (e) {
      console.error("Error al aceptar la llamada:", e)
      this.statusTarget.textContent = `Error al responder: ${e?.message || e}`
    }
  }

  // ===== Modos de UI (entrante/activa) =====
  setIncomingMode() {
    try {
      this.answerButtonTarget?.classList.remove("hidden")
      this.hangupButtonTarget?.classList.add("hidden")
      this.statusTarget.textContent = "Llamada entrante…"
    } catch (_) {}
  }

  setActiveMode() {
    try {
      this.answerButtonTarget?.classList.add("hidden")
      this.hangupButtonTarget?.classList.remove("hidden")
      // Si ya se aceptó, el estado es conectado o llamando según eventos
    } catch (_) {}
  }

  // ===== Inicialización de Twilio.Device para llamadas entrantes =====
  async initializeIncomingDeviceIfNeeded() {
    try {
      // Si ya hay un Device global, solo asegurar handlers (no re-registrar)
      if (window.twilioDevice) {
        this.attachIncomingHandlers(window.twilioDevice)
        return
      }
      // SDK no cargado
      if (!window.Twilio || !window.Twilio.Device) return
      // Obtener token del backend
      const r = await fetch("/api/twilio/voice/token", { method: "POST", headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken() }, credentials: "include" })
      const data = await r.json().catch(() => ({}))
      if (!data?.token) return
      // Crear y registrar Device solo para recepción
      const device = new window.Twilio.Device(data.token, { logLevel: "warn", enableRingingState: true })
      // Registrar sólo si no está ya registrado (cuando el Device es nuevo, su estado inicial es “unregistered”)
      if (device?.state !== "registered") {
        try { await device.register?.() } catch (_) {}
      }
      window.twilioDevice = device
      this.attachIncomingHandlers(device)
    } catch (e) {
      console.warn("No se pudo inicializar Twilio.Device para llamadas entrantes:", e)
    }
  }

  attachIncomingHandlers(device) {
    try {
      if (!device || typeof device.on !== "function") return
      if (this._incomingAttached) return
      device.on("incoming", (call) => {
        try {
          if (window.CallState?.inCall) {
            try { call.reject?.() } catch (_) {}
            return
          }
          window.activeIncomingCall = call
          const from = call?.parameters?.From || call?.parameters?.Caller || "Número desconocido"
          ;(async () => {
            const name = await this.resolveCallerName(from)
            const uiDetail = { name: name || "Llamada entrante", phone: from }
            window.dispatchEvent(new CustomEvent("call:ui:incoming", { detail: uiDetail }))
          })()
          // Eventos del ciclo de vida
          call.on?.("accept", () => {
            window.activeConnection = call
            window.CallState = Object.assign({}, window.CallState, { inCall: true })
            window.dispatchEvent(new CustomEvent("call:ui:accepted"))
            try { this.statusTarget.textContent = "Conectado" } catch (_) {}
          })
          call.on?.("cancel", () => {
            window.dispatchEvent(new CustomEvent("call:ui:hide"))
            window.CallState = Object.assign({}, window.CallState, { inCall: false })
          })
          call.on?.("disconnect", () => {
            window.dispatchEvent(new CustomEvent("call:ui:hide"))
            window.CallState = Object.assign({}, window.CallState, { inCall: false })
          })
          call.on?.("error", (e) => {
            console.error("Twilio.Call (entrante) error", e)
            this.statusTarget.textContent = `Error: ${e?.message || e}`
            window.dispatchEvent(new CustomEvent("call:ui:hide"))
            window.CallState = Object.assign({}, window.CallState, { inCall: false })
          })
        } catch (_) {}
      })
      this._incomingAttached = true
    } catch (_) {}
  }

  // ===== Resolver nombre por teléfono (Client/ContactList) =====
  async resolveCallerName(phone) {
    try {
      if (!phone) return null
      const url = `/api/lookup/caller?phone=${encodeURIComponent(phone)}`
      const r = await fetch(url, { headers: { "Accept": "application/json", "X-CSRF-Token": this.csrfToken() }, credentials: "include" })
      const data = await r.json().catch(() => ({}))
      return data?.name || null
    } catch (_) {
      return null
    }
  }

  // ===== Ringback (tono de repique) =====
  ensureAudioContext() {
    try {
      if (!this.audioCtx) {
        const AC = window.AudioContext || window.webkitAudioContext
        if (!AC) return
        this.audioCtx = new AC()
      }
      // Algunos navegadores requieren resume tras interacción del usuario
      this.audioCtx?.resume?.()
    } catch (_) {}
  }

  startRingback() {
    try {
      this.ensureAudioContext()
      if (!this.audioCtx) return
      // Evitar múltiples instancias
      if (this._ringbackActive) return

      const ctx = this.audioCtx
      const gain = ctx.createGain()
      gain.gain.value = 0.0
      gain.connect(ctx.destination)

      const osc1 = ctx.createOscillator()
      const osc2 = ctx.createOscillator()
      // Ringback estilo US: mezcla ~440Hz y ~480Hz
      osc1.frequency.value = 440
      osc2.frequency.value = 480
      osc1.connect(gain)
      osc2.connect(gain)
      osc1.start()
      osc2.start()

      // Patrón: 2s ON / 4s OFF
      const onMs = 2000
      const offMs = 4000
      let on = false
      const toggle = () => {
        on = !on
        gain.gain.value = on ? 0.05 : 0.0
      }
      // Inicio con ON para dar feedback inmediato
      toggle()
      const interval = setInterval(toggle, onMs + offMs)

      this._ringbackActive = true
      this._ringbackNodes = { gain, osc1, osc2, interval }
    } catch (e) {
      console.warn("No se pudo iniciar ringback:", e)
    }
  }

  stopRingback() {
    try {
      if (!this._ringbackActive) return
      const { gain, osc1, osc2, interval } = this._ringbackNodes || {}
      clearInterval(interval)
      try { gain && (gain.gain.value = 0.0) } catch (_) {}
      try { osc1?.stop?.() } catch (_) {}
      try { osc2?.stop?.() } catch (_) {}
      try { osc1?.disconnect?.() } catch (_) {}
      try { osc2?.disconnect?.() } catch (_) {}
      try { gain?.disconnect?.() } catch (_) {}
      this._ringbackActive = false
      this._ringbackNodes = null
    } catch (_) {}
  }
}