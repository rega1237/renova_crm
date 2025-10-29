import { Controller } from "@hotwired/stimulus"

// Controlador para actualizar dinámicamente el selector de ciudades según el estado seleccionado
export default class extends Controller {
  static targets = ["stateSelect", "citySelect", "loadingIndicator"]
  static values = { url: String }

  connect() {
    // Inicializar: si no hay estado seleccionado, no hacemos fetch; las opciones iniciales vienen del servidor
    // Si hay estado seleccionado y el select de ciudad está vacío (sin opciones de ciudades), cargar.
    if (this.stateSelectTarget && this.stateSelectTarget.value && this.citySelectTarget.options.length <= 2) {
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

    // Mostrar indicador de carga y deshabilitar select de ciudad
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
    // Limpiar opciones actuales (manteniendo el blank y 'Sin ciudad')
    this.citySelectTarget.innerHTML = ""

    // Opción en blanco (Todas las Ciudades)
    const blankOpt = document.createElement("option")
    blankOpt.value = ""
    blankOpt.textContent = "Todas las Ciudades"
    this.citySelectTarget.appendChild(blankOpt)

    // Opción especial 'Sin ciudad'
    const noneOpt = document.createElement("option")
    noneOpt.value = "none"
    noneOpt.textContent = "Sin ciudad"
    this.citySelectTarget.appendChild(noneOpt)

    // Agregar ciudades
    cities.forEach((c) => {
      const opt = document.createElement("option")
      opt.value = String(c.id)
      opt.textContent = c.name
      this.citySelectTarget.appendChild(opt)
    })

    // Restaurar valor si sigue siendo válido
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
    // Opciones temporales
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