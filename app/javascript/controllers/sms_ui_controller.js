import { Controller } from "@hotwired/stimulus"

// Handles the fixed SMS UI notifications, independent of where it's rendered.
export default class extends Controller {
  static targets = ["container", "name", "phone", "status", "openButton", "closeButton"]

  connect() {
    // Initialize global state if missing
    window.SmsState = window.SmsState || { notifications: [] }

    // Listen for UI events
    this.onShow = (e) => {
      const { name, phone, message } = e.detail || {}
      this.render(name || "Mensaje nuevo", phone, message || "SMS recibido")
    }
    
    this.onHide = () => {
      this.hide()
    }

    window.addEventListener("sms:ui:show", this.onShow)
    window.addEventListener("sms:ui:hide", this.onHide)
  }

  disconnect() {
    // Remove listeners to avoid duplicates across Turbo visits
    window.removeEventListener("sms:ui:show", this.onShow)
    window.removeEventListener("sms:ui:hide", this.onHide)
  }

  // ===== UI rendering =====
  render(name, phone, message) {
    if (name) this.nameTarget.textContent = name
    if (phone) this.phoneTarget.textContent = phone
    if (message) {
      this.statusTarget.textContent = message.length > 30 ? message.substring(0, 30) + "..." : message
    }
    this.show()
  }

  show() {
    this.containerTarget.classList.remove("hidden", "opacity-0", "translate-y-2")
    // Animate in
    this.containerTarget.classList.add("opacity-0", "translate-y-2")
    requestAnimationFrame(() => {
      this.containerTarget.classList.remove("opacity-0", "translate-y-2")
    })

    // Auto-hide after 5 seconds
    setTimeout(() => {
      this.hide()
    }, 5000)
  }

  hide() {
    this.containerTarget.classList.add("opacity-0", "translate-y-2")
    setTimeout(() => {
      this.containerTarget.classList.add("hidden")
      this.containerTarget.classList.remove("opacity-0", "translate-y-2")
    }, 180)
  }

  // ===== Actions =====
  openConversation() {
    const clientId = this.containerTarget.dataset.clientId
    if (clientId) {
      // Abrir el overlay de SMS del cliente
      window.dispatchEvent(new CustomEvent("client:sms:open", { detail: { clientId } }))
    }
    this.hide()
  }

  close() {
    this.hide()
  }
}