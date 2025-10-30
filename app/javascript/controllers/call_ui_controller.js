import { Controller } from "@hotwired/stimulus"

// Handles the fixed call UI, independent of where it's rendered.
// Interacts with global window.twilioDevice and window.activeConnection created by call_controller.
export default class extends Controller {
  static targets = ["container", "name", "phone", "status", "muteButton", "speakerButton", "hangupButton"]

  connect() {
    // Initialize global state if missing
    window.CallState = window.CallState || { inCall: false, muted: false, outputMode: "default", sinkId: "default" }

    // Restore UI if a call is already active (Turbo navigation)
    if (window.CallState.inCall) {
      this.render(window.CallState.clientName, window.CallState.phone)
      this.updateControls()
    }

    // Listen for UI events from call_controller
    this.onShow = (e) => {
      const { name, phone } = e.detail || {}
      this.render(name, phone)
    }
    this.onUpdate = () => this.updateControls()
    this.onHide = () => this.hide()

    window.addEventListener("call:ui:show", this.onShow)
    window.addEventListener("call:ui:update", this.onUpdate)
    window.addEventListener("call:ui:hide", this.onHide)
  }

  disconnect() {
    // Remove listeners to avoid duplicates across Turbo visits
    window.removeEventListener("call:ui:show", this.onShow)
    window.removeEventListener("call:ui:update", this.onUpdate)
    window.removeEventListener("call:ui:hide", this.onHide)
  }

  // ===== UI rendering =====
  render(name, phone) {
    if (name) this.nameTarget.textContent = name
    if (phone) this.phoneTarget.textContent = phone
    this.statusTarget.textContent = "Llamando…"
    this.show()
    this.updateControls()
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
  }

  updateControls() {
    const muted = !!(window.CallState && window.CallState.muted)
    this.muteButtonTarget.classList.toggle("bg-gray-500", muted)
    this.muteButtonTarget.classList.toggle("bg-gray-700", !muted)

    const mode = (window.CallState && window.CallState.outputMode) || "default"
    // Visual hint: speaker -> green, headphones -> blue
    const isSpeaker = mode === "speaker"
    this.speakerButtonTarget.classList.toggle("bg-green-600", isSpeaker)
    this.speakerButtonTarget.classList.toggle("bg-gray-700", !isSpeaker)
  }

  // ===== Actions =====
  toggleMute() {
    try {
      const conn = window.activeConnection
      if (!conn || typeof conn.mute !== "function") {
        console.warn("No hay conexión activa o la API mute no está disponible.")
        return
      }
      const newMuted = !window.CallState.muted
      conn.mute(newMuted)
      window.CallState.muted = newMuted
      this.statusTarget.textContent = newMuted ? "Micrófono apagado" : "Micrófono encendido"
      window.dispatchEvent(new CustomEvent("call:ui:update"))
    } catch (e) {
      console.error("Error al alternar mute:", e)
    }
  }

  async toggleOutput() {
    const device = window.twilioDevice
    if (!device) {
      console.warn("Twilio.Device no disponible para cambiar salida de audio.")
      return
    }

    // Detect setSinkIds support (Chrome/Edge); Safari no soporta.
    const supportsSink = typeof device.audio?.setSinkIds === "function"
    if (!supportsSink) {
      this.statusTarget.textContent = "Salida de audio no soportada por el navegador"
      return
    }

    try {
      const mode = window.CallState.outputMode === "speaker" ? "headphones" : "speaker"
      const sinks = await navigator.mediaDevices.enumerateDevices()
      const audioOutputs = sinks.filter((d) => d.kind === "audiooutput")

      let targetDeviceId = "default"
      if (mode === "headphones") {
        // Intentar encontrar un dispositivo que parezca audífonos o 'communications'
        const comm = audioOutputs.find((d) => d.deviceId === "communications")
        const headphones = audioOutputs.find((d) => /headphone|aud[ií]fono/i.test(d.label))
        targetDeviceId = (headphones?.deviceId) || (comm?.deviceId) || "default"
      } else {
        // Altavoz: preferir 'default'
        targetDeviceId = "default"
      }

      await device.audio.setSinkIds([targetDeviceId])
      window.CallState.outputMode = mode
      window.CallState.sinkId = targetDeviceId
      this.statusTarget.textContent = mode === "speaker" ? "Salida: Altavoz" : "Salida: Audífonos"
      this.updateControls()
    } catch (e) {
      console.error("Error al cambiar salida de audio:", e)
      this.statusTarget.textContent = "Error al cambiar salida de audio"
    }
  }

  hangup() {
    try {
      const conn = window.activeConnection
      if (conn && typeof conn.disconnect === "function") {
        conn.disconnect()
      }
      // Teardown del Device para liberar recursos
      try { window.twilioDevice?.disconnectAll?.() } catch (_) {}
      try { window.twilioDevice?.destroy?.() } catch (_) {}
      window.CallState = Object.assign({}, window.CallState, { inCall: false })
      window.dispatchEvent(new CustomEvent("call:ui:hide"))

      // Restaurar botones de llamada (si existen en la vista)
      document.querySelectorAll('[data-controller="call"] [data-call-target="button"]').forEach((el) => el.classList.remove('hidden'))
    } catch (e) {
      console.error("Error al colgar la llamada:", e)
    }
  }
}