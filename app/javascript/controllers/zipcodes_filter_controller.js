import { Controller } from "@hotwired/stimulus"

// Controlador para actualizar dinámicamente el selector de ciudades según el estado seleccionado (para Zipcodes)
export default class extends Controller {
  static targets = ["stateSelect", "citySelect", "loadingIndicator"]
  static values = { url: String }

  connect() {
    // Si hay estado seleccionado, cargar ciudades de ese estado inicial
    if (this.stateSelectTarget && this.stateSelectTarget.value) {
      this.loadCities()
    }
  }

  changeState() {
    this.loadCities()
  }

  async loadCities() {
    const stateId = this.stateSelectTarget.value
    const url = new URL(this.urlValue || "/api/cities", window.location.origin)
    if (stateId) {
      url.searchParams.set("state_id", stateId)
    }

    this.showLoading()

    try {
      const response = await fetch(url.toString(), { headers: { "Accept": "application/json" } })
      const data = await response.json()
      this.updateCityOptions(data)
    } catch (error) {
      console.error("Error cargando ciudades:", error)
    } finally {
      this.hideLoading()
    }
  }

  updateCityOptions(cities) {
    const currentValue = this.citySelectTarget.value
    this.citySelectTarget.innerHTML = ""

    // Opción en blanco (Todas las Ciudades)
    const blankOpt = document.createElement("option")
    blankOpt.value = ""
    blankOpt.textContent = "Todas las ciudades"
    this.citySelectTarget.appendChild(blankOpt)

    // Agregar ciudades
    cities.forEach((c) => {
      const opt = document.createElement("option")
      opt.value = String(c.id)
      opt.textContent = c.name
      this.citySelectTarget.appendChild(opt)
    })

    const optionsValues = Array.from(this.citySelectTarget.options).map(o => o.value)
    if (optionsValues.includes(currentValue)) {
      this.citySelectTarget.value = currentValue
    } else {
      this.citySelectTarget.value = ""
    }
  }

  showLoading() {
    if (this.loadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove("hidden")
    }
    this.citySelectTarget.disabled = true
    this.citySelectTarget.innerHTML = ""
    const loadingOpt = document.createElement("option")
    loadingOpt.value = ""
    loadingOpt.textContent = "Cargando ciudades..."
    this.citySelectTarget.appendChild(loadingOpt)
  }

  hideLoading() {
    if (this.loadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
    this.citySelectTarget.disabled = false
  }
}