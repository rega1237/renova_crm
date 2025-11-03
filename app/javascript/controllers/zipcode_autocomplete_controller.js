import { Controller } from "@hotwired/stimulus"

// Campo de texto con autocomplete para zipcodes, filtrando por ciudad si está seleccionada o por estado en su defecto.
// Uso:
// <div data-controller="zipcode-autocomplete"
//      data-zipcode-autocomplete-url-value="/api/zipcodes"
//      data-zipcode-autocomplete-state-id-value="123"
//      data-zipcode-autocomplete-city-id-value="456">
//   <input type="text" name="zip_code" data-zipcode-autocomplete-target="input" placeholder="Escribe el código postal">
//   <div data-zipcode-autocomplete-target="results" class="hidden absolute z-10 w-full bg-white border border-gray-300 rounded-md shadow-lg mt-1"></div>
// </div>
export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String, stateId: Number, cityId: Number }

  connect() {
    this._debounceTimer = null
    this._activeIndex = -1
    this.inputTarget.addEventListener("input", () => this.debounceSearch())
    this.inputTarget.addEventListener("focus", () => this.debounceSearch())
    this.inputTarget.addEventListener("keydown", (e) => this.onKeyDown(e))
    document.addEventListener("click", this._outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick)
    this.hideResults()
  }

  _outsideClick = (e) => {
    if (!this.element.contains(e.target)) {
      this.hideResults()
    }
  }

  debounceSearch() {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => this.search(), 200)
  }

  async search() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) { this.hideResults(); return }
    const url = new URL(this.urlValue || "/api/zipcodes", window.location.origin)
    // Forzamos el uso del modelo Zipcode para listar todos los códigos disponibles
    url.searchParams.set("use_model", "true")
    if (q.length > 0) url.searchParams.set("q", q)
    const cityId = this.cityIdValue || null
    const stateId = this.stateIdValue || null
    if (cityId) url.searchParams.set("city_id", String(cityId))
    else if (stateId) url.searchParams.set("state_id", String(stateId))

    try {
      const resp = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const data = await resp.json()
      const zipcodes = Array.isArray(data) ? data : (data.zipcodes || [])
      this.renderResults(zipcodes)
    } catch (e) {
      console.warn("Error buscando zipcodes:", e)
      this.hideResults()
    }
  }

  renderResults(zipcodes) {
    const q = this.inputTarget.value.trim().toLowerCase()
    if (!zipcodes || zipcodes.length === 0) {
      this.resultsTarget.innerHTML = `<div class="px-3 py-2 text-sm text-gray-500">Sin resultados</div>`
      this.showResults()
      return
    }
    const items = zipcodes.map((z, idx) => {
      const code = z.code || z
      const city = z.city_name
      const state = z.state_abbr
      const label = city ? `${code} - ${city}${state ? ", " + state : ""}` : code
      return `<button type="button" data-code="${this._escape(code)}" data-index="${idx}" class="w-full text-left px-3 py-2 hover:bg-gray-100 text-sm">${this._highlight(this._escape(label), q)}</button>`
    }).join("")
    this.resultsTarget.innerHTML = items
    this.showResults()
    this._buttons = Array.from(this.resultsTarget.querySelectorAll("button"))
    this._buttons.forEach(btn => {
      btn.addEventListener("click", (e) => this.selectZip(e.currentTarget.dataset.code))
    })
    this._activeIndex = this._buttons.length ? 0 : -1
    this._updateActive()
  }

  selectZip(code) {
    this.inputTarget.value = code
    this.hideResults()
  }

  showResults() {
    this.resultsTarget.classList.remove("hidden")
  }

  hideResults() {
    this.resultsTarget.classList.add("hidden")
    this.resultsTarget.innerHTML = ""
    this._activeIndex = -1
    this._buttons = []
  }

  _escape(str) {
    return String(str).replace(/[&<>"]/g, s => ({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[s]))
  }

  _highlight(text, q) {
    if (!q) return this._escape(text)
    const idx = text.toLowerCase().indexOf(q)
    if (idx === -1) return this._escape(text)
    const before = this._escape(text.slice(0, idx))
    const match = this._escape(text.slice(idx, idx + q.length))
    const after = this._escape(text.slice(idx + q.length))
    return `${before}<strong class="text-rojo-carmesi">${match}</strong>${after}`
  }

  onKeyDown(e) {
    if (this.resultsTarget.classList.contains("hidden")) return
    if (e.key === "ArrowDown") {
      e.preventDefault()
      if (this._buttons && this._buttons.length) {
        this._activeIndex = Math.min(this._activeIndex + 1, this._buttons.length - 1)
        this._updateActive()
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      if (this._buttons && this._buttons.length) {
        this._activeIndex = Math.max(this._activeIndex - 1, 0)
        this._updateActive()
      }
    } else if (e.key === "Enter") {
      e.preventDefault()
      if (this._buttons && this._buttons.length) {
        const btn = this._buttons[this._activeIndex] || this._buttons[0]
        this.selectZip(btn.dataset.code)
      }
    } else if (e.key === "Escape") {
      e.preventDefault()
      this.hideResults()
    }
  }

  _updateActive() {
    if (!this._buttons) return
    this._buttons.forEach((btn, i) => {
      btn.classList.toggle("bg-gray-100", i === this._activeIndex)
    })
  }
}