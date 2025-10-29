import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "loading"]

  disable(event) {
    // Prevent double clicks, show loading message
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.classList.add("opacity-70", "cursor-not-allowed")
      this.submitTarget.textContent = "Ingresando..."
    }
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }
}