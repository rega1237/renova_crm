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
    }
    this.onHide = () => this.hide()

    window.addEventListener("call:ui:show", this.onShow)
    window.addEventListener("call:ui:hide", this.onHide)
  }

  disconnect() {
    // Remove listeners to avoid duplicates across Turbo visits
    window.removeEventListener("call:ui:show", this.onShow)
    window.removeEventListener("call:ui:hide", this.onHide)
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
  }

  // ===== Actions =====

  hangup() {
    try {
      const conn = window.activeConnection
      if (conn && typeof conn.disconnect === "function") {
        conn.disconnect()
      }
      window.CallState = Object.assign({}, window.CallState, { inCall: false })
      window.dispatchEvent(new CustomEvent("call:ui:hide"))

      // Restaurar botones de llamada (si existen en la vista)
      document.querySelectorAll('[data-controller="call"] [data-call-target="button"]').forEach((el) => el.classList.remove('hidden'))
    } catch (e) {
      console.error("Error al colgar la llamada:", e)
    }
  }
}