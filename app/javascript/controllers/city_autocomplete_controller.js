import { Controller } from "@hotwired/stimulus"

// Campo de texto con autocomplete para ciudades, filtrando por estado si está disponible.
// Uso:
// <div data-controller="city-autocomplete"
//      data-city-autocomplete-url-value="/api/cities"
//      data-city-autocomplete-state-id-value="123">
//   <input type="text" data-city-autocomplete-target="input" placeholder="Escribe la ciudad">
//   <input type="hidden" name="city_id" data-city-autocomplete-target="hidden">
//   <div data-city-autocomplete-target="results" class="hidden absolute z-10 w-full bg-white border border-gray-300 rounded-md shadow-lg mt-1"></div>
// </div>
export default class extends Controller {
  static targets = ["input", "results", "hidden"]
  static values = { url: String, stateId: Number }

  connect() {
    this._debounceTimer = null
    this._activeIndex = -1
    // Prellenar el campo visible con el nombre si ya hay una ciudad seleccionada
    if (this.hiddenTarget.value && !this.inputTarget.value) {
      // No conocemos el nombre aún; se completará al primer search
    }
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
    const url = new URL(this.urlValue || "/api/cities", window.location.origin)
    url.searchParams.set("all", "true")
    if (q.length > 0) url.searchParams.set("q", q)
    const stateId = this.stateIdValue || null
    if (stateId) url.searchParams.set("state_id", String(stateId))

    try {
      const resp = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const cities = await resp.json()
      this.renderResults(cities)
    } catch (e) {
      console.warn("Error buscando ciudades:", e)
      this.hideResults()
    }
  }

  renderResults(cities) {
    const q = this.inputTarget.value.trim().toLowerCase()
    if (!cities || cities.length === 0) {
      this.resultsTarget.innerHTML = `<div class="px-3 py-2 text-sm text-gray-500">Sin resultados</div>`
      this.showResults()
      return
    }
    const items = cities.map((c, idx) => {
      const name = c.name
      const id = c.id
      return `<button type="button" data-id="${id}" data-name="${this._escape(name)}" data-index="${idx}" class="w-full text-left px-3 py-2 hover:bg-gray-100 text-sm">${this._highlight(name, q)}</button>`
    }).join("")
    this.resultsTarget.innerHTML = items
    this.showResults()
    // Bind clicks
    this._buttons = Array.from(this.resultsTarget.querySelectorAll("button"))
    this._buttons.forEach(btn => {
      btn.addEventListener("click", (e) => this.selectCity(e.currentTarget.dataset.id, e.currentTarget.dataset.name))
    })
    this._activeIndex = this._buttons.length ? 0 : -1
    this._updateActive()
  }

  selectCity(id, name) {
    this.hiddenTarget.value = id
    this.inputTarget.value = name
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
        this.selectCity(btn.dataset.id, btn.dataset.name)
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