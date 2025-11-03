import { Controller } from "@hotwired/stimulus"

// Controlador para actualizar dinámicamente el selector de ciudades según el estado seleccionado
// Soporta dos modos:
// - Con targets: data-cities-filter-target="stateSelect" y data-cities-filter-target="citySelect"
// - Desacoplado: valores CSS data-cities-filter-state-selector-value y data-cities-filter-city-selector-value
// También provee retroalimentación visual opcional con data-cities-filter-target="feedback".
export default class extends Controller {
  static targets = ["stateSelect", "citySelect", "loadingIndicator", "feedback"]
  static values = { url: String, stateSelector: String, citySelector: String }

  connect() {
    // Obtener elementos ya sea por targets o por selectores CSS
    this.stateEl = this.hasStateSelectTarget ? this.stateSelectTarget : document.querySelector(this.stateSelectorValue)
    this.cityEl = this.hasCitySelectTarget ? this.citySelectTarget : document.querySelector(this.citySelectorValue)

    if (!this.cityEl) return

    // Listener de cambio en estado (si existe)
    if (this.stateEl) {
      this.stateEl.addEventListener("change", () => this.loadCities())
    }

    // Inicializar: si hay estado y pocas opciones de ciudad, cargar.
    if (this.stateEl && this.stateEl.value && this.cityEl.options && this.cityEl.options.length <= 2) {
      this.loadCities()
    }
  }

  async loadCities() {
    const stateId = this.stateEl && this.stateEl.value ? this.stateEl.value : null
    const url = new URL(this.urlValue || "/api/cities", window.location.origin)
    if (stateId) url.searchParams.set("state_id", stateId)

    this.showLoading()

    try {
      const response = await fetch(url.toString(), { headers: { "Accept": "application/json" } })
      const data = await response.json()
      this.updateCityOptions(data, stateId)
    } catch (error) {
      console.error("Error cargando ciudades:", error)
    } finally {
      this.hideLoading()
    }
  }

  updateCityOptions(cities, stateId) {
    const currentValue = this.cityEl.value
    this.cityEl.innerHTML = ""

    const blankOpt = document.createElement("option")
    blankOpt.value = ""
    blankOpt.textContent = "Todas las Ciudades"
    this.cityEl.appendChild(blankOpt)

    const noneOpt = document.createElement("option")
    noneOpt.value = "none"
    noneOpt.textContent = "Sin ciudad"
    this.cityEl.appendChild(noneOpt)

    cities.forEach((c) => {
      const opt = document.createElement("option")
      opt.value = String(c.id)
      opt.textContent = c.name
      this.cityEl.appendChild(opt)
    })

    const optionsValues = Array.from(this.cityEl.options).map(o => o.value)
    if (optionsValues.includes(currentValue)) {
      this.cityEl.value = currentValue
    } else {
      this.cityEl.value = ""
    }

    // Feedback visual sobre cuántas opciones hay
    if (this.hasFeedbackTarget) {
      const count = this.cityEl.options.length - 2 // excluye blank y 'none'
      if (count === 0) {
        if (stateId) {
          this.feedbackTarget.textContent = "No hay ciudades con clientes para el estado seleccionado"
        } else {
          this.feedbackTarget.textContent = "No hay ciudades con clientes disponibles"
        }
      } else {
        if (stateId) {
          this.feedbackTarget.textContent = `Ciudades disponibles: ${count} (filtradas por estado)`
        } else {
          this.feedbackTarget.textContent = `Ciudades disponibles: ${count}`
        }
      }
    }
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove("hidden")
    }
    if (this.cityEl) {
      this.cityEl.disabled = true
      this.cityEl.innerHTML = ""
      const loadingOpt = document.createElement("option")
      loadingOpt.value = ""
      loadingOpt.textContent = "Cargando ciudades..."
      this.cityEl.appendChild(loadingOpt)
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
    if (this.cityEl) this.cityEl.disabled = false
  }
}