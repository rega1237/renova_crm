import { Controller } from "@hotwired/stimulus"

// Handles the fixed call UI, independent of where it's rendered.
// Interacts with global window.twilioDevice and window.activeConnection created by call_controller.
export default class extends Controller {
  static targets = ["container", "name", "phone", "status", "hangupButton"]

  connect() {
    // Initialize global state if missing (minimal)
    window.CallState = window.CallState || { inCall: false }

    // Restore UI if a call is already active (Turbo navigation)
    if (window.CallState.inCall) {
      this.render(window.CallState.clientName, window.CallState.phone)
    }

    // Listen for UI events from call_controller
    this.onShow = (e) => {
      const { name, phone } = e.detail || {}
      this.render(name, phone)
      // Prepara el contexto de audio para poder reproducir el tono tras interacción del usuario
      this.ensureAudioContext()
    }
    this.onHide = () => this.hide()

    // Eventos para feedback auditivo
    this.onRinging = () => this.startRingback()
    this.onAccepted = () => this.stopRingback()
    this.onStopAudio = () => this.stopRingback()

    window.addEventListener("call:ui:show", this.onShow)
    window.addEventListener("call:ui:hide", this.onHide)
    window.addEventListener("call:ui:ringing", this.onRinging)
    window.addEventListener("call:ui:accepted", this.onAccepted)
    window.addEventListener("call:ui:stop-audio", this.onStopAudio)
  }

  disconnect() {
    // Remove listeners to avoid duplicates across Turbo visits
    window.removeEventListener("call:ui:show", this.onShow)
    window.removeEventListener("call:ui:hide", this.onHide)
    window.removeEventListener("call:ui:ringing", this.onRinging)
    window.removeEventListener("call:ui:accepted", this.onAccepted)
    window.removeEventListener("call:ui:stop-audio", this.onStopAudio)
    this.stopRingback()
  }

  // ===== UI rendering =====
  render(name, phone) {
    if (name) this.nameTarget.textContent = name
    if (phone) this.phoneTarget.textContent = phone
    this.statusTarget.textContent = "Llamando…"
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
      if (conn && typeof conn.disconnect === "function") {
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