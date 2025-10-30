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

  start(event) {
    event.preventDefault()
    const btn = this.buttonTarget || this.element
    this.setLoading(btn, true)
    this.setStatus("Llamando…", "text-yellow-700")

    fetch("/api/calls", {
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
      .then(r => this.parseResponse(r))
      .then(({ ok, data, status, isJson }) => {
        if (!ok) {
          if (status === 401) {
            this.setStatus("No autorizado. Inicia sesión para realizar llamadas.", "text-red-700")
          } else {
            this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
          }
          return
        }
        if (ok && data.need_selection) {
          this.renderSelection(data.alternatives)
          this.setLoading(btn, false)
          this.setStatus("Selecciona un número de origen", "text-blue-700")
          return
        }

        if (data.success) {
          this.setStatus(`Llamada encolada (SID: ${data.sid})`, "text-green-700")
        } else {
          this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
        }
      })
      .catch(err => {
        console.error(err)
        this.setStatus("Error de red al iniciar la llamada", "text-red-700")
      })
      .finally(() => {
        this.setLoading(btn, false)
      })
  }

  selectNumber(event) {
    const fromNumber = event.params.phone
    const btn = this.buttonTarget || this.element
    this.setLoading(btn, true)
    this.setStatus("Llamando…", "text-yellow-700")

    fetch("/api/calls", {
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
      .then(r => this.parseResponse(r))
      .then(({ ok, data, status, isJson }) => {
        if (!ok) {
          if (status === 401) {
            this.setStatus("No autorizado. Inicia sesión para realizar llamadas.", "text-red-700")
          } else {
            this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
          }
          return
        }
        if (data.success) {
          this.setStatus(`Llamada encolada (SID: ${data.sid})`, "text-green-700")
          this.selectionTarget.innerHTML = ""
          this.selectionTarget.classList.add("hidden")
        } else {
          this.setStatus((isJson && data && data.error) ? data.error : `Error (${status})`, "text-red-700")
        }
      })
      .catch(err => {
        console.error(err)
        this.setStatus("Error de red al iniciar la llamada", "text-red-700")
      })
      .finally(() => this.setLoading(btn, false))
  }

  renderSelection(alternatives) {
    const container = this.selectionTarget
    container.classList.remove("hidden")
    container.innerHTML = `
      <div class="mt-2 p-2 border rounded-md bg-gray-50">
        <p class="text-xs text-gray-600 mb-1">Selecciona el número de origen:</p>
        <div class="flex flex-wrap gap-2">
          ${alternatives.map(a => `
            <button data-action="click->call#selectNumber" data-call-phone-param="${a.phone_number}" class="px-2 py-1 text-xs rounded-md bg-blue-600 text-white hover:bg-blue-700">
              ${a.phone_number} (${a.state})
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
}