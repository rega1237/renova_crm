import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// Connects to data-controller="progress"
// Expects data attributes:
// - data-progress-id: unique progress ID to subscribe
// Targets: bar, percent, status, details, download
export default class extends Controller {
  static targets = ["bar", "percent", "status", "details", "download"]
  static values = { id: String }

  connect() {
    const pid = this.idValue || this.element.dataset.progressId
    if (!pid) return
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create({ channel: "ProgressChannel", pid }, {
      received: (data) => this.handleMessage(data)
    })
  }

  disconnect() {
    if (this.subscription) this.subscription.unsubscribe()
    if (this.consumer) this.consumer.disconnect()
  }

  handleMessage(data) {
    try {
      const { event, total, processed, percent, message, summary, download_url } = data
      if (event === "start") {
        this.updateStatus(message || "Iniciando...")
        this.updateProgress(0)
      } else if (event === "tick" || event === "progress") {
        const pct = percent != null ? percent : this.computePercent(processed, total)
        this.updateProgress(pct)
        if (message) this.updateStatus(message)
      } else if (event === "complete") {
        this.updateProgress(100)
        this.updateStatus(message || "Completado")
        if (summary && this.hasDetailsTarget) {
          this.detailsTarget.innerHTML = this.renderSummary(summary)
        }
        if (download_url && this.hasDownloadTarget) {
          this.downloadTarget.innerHTML = `<a href="${download_url}" class="inline-flex items-center gap-2 bg-emerald-600 text-white font-semibold py-2 px-4 rounded hover:bg-emerald-700">Descargar archivo</a>`
        }
      } else if (event === "error") {
        this.updateStatus(message || "Error durante el proceso", true)
      }
    } catch (e) {
      // Silently ignore to avoid breaking UI
    }
  }

  computePercent(processed, total) {
    if (!total || total <= 0) return 0
    const pct = Math.round((processed / total) * 100)
    return Math.max(0, Math.min(100, pct))
  }

  updateProgress(percent) {
    if (this.hasBarTarget) {
      this.barTarget.style.width = `${percent}%`
    }
    if (this.hasPercentTarget) {
      this.percentTarget.textContent = `${percent}%`
    }
  }

  updateStatus(text, isError = false) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.classList.toggle("text-red-600", !!isError)
    }
  }

  renderSummary(summary) {
    // Summary can be an object of counts; render basic list
    const items = Object.entries(summary).map(([k, v]) => `<li><strong>${k}:</strong> ${v}</li>`).join("")
    return `<ul class="list-disc list-inside">${items}</ul>`
  }
}