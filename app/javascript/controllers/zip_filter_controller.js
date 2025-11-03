import { Controller } from "@hotwired/stimulus"

// Controla el dropdown de ZIP para que se actualice jerárquicamente según estado y ciudad,
// y provee opciones válidas (solo 5 dígitos) desde /api/zipcodes.
// Valores:
// - urlValue: endpoint para obtener zipcodes (por defecto /api/zipcodes)
// - stateSelectorValue, citySelectorValue: selectores CSS para ubicar los selects de estado y ciudad
// Targets opcionales:
// - feedback: elemento donde mostrar el conteo y contexto de filtrado
export default class extends Controller {
  static targets = ["zipSelect", "feedback"]
  static values = { url: String, stateSelector: String, citySelector: String }

  connect() {
    this.stateEl = document.querySelector(this.stateSelectorValue || 'select[name="state_id"]')
    this.cityEl = document.querySelector(this.citySelectorValue || 'select[name="city_id"]')

    if (this.stateEl) this.stateEl.addEventListener("change", () => this.loadZipcodes())
    if (this.cityEl) this.cityEl.addEventListener("change", () => this.loadZipcodes())

    // Carga inicial
    this.loadZipcodes()
  }

  async loadZipcodes() {
    const url = new URL(this.urlValue || "/api/zipcodes", window.location.origin)
    const stateId = this.stateEl && this.stateEl.value ? this.stateEl.value : null
    const cityId = this.cityEl && this.cityEl.value && this.cityEl.value !== "none" ? this.cityEl.value : null
    if (stateId) url.searchParams.set("state_id", stateId)
    if (cityId) url.searchParams.set("city_id", cityId)

    const currentValue = this.zipSelectTarget.value
    this._filterContext = { stateId, cityId }

    try {
      const resp = await fetch(url.toString(), { headers: { Accept: "application/json" } })
      const data = await resp.json()
      const zipcodes = Array.isArray(data) ? data : (data.zipcodes || [])
      this.updateZipOptions(zipcodes, currentValue)
    } catch (e) {
      console.error("Error obteniendo zipcodes:", e)
    }
  }

  updateZipOptions(zipcodes, currentValue) {
    this.zipSelectTarget.innerHTML = ""

    const blankOpt = document.createElement("option")
    blankOpt.value = ""
    blankOpt.textContent = "Todos los Códigos"
    this.zipSelectTarget.appendChild(blankOpt)

    zipcodes.forEach((z) => {
      const code = (typeof z === "string") ? z : (z && z.code)
      if (!code) return
      const label = (typeof z === "string")
        ? z
        : (z.city_name ? `${z.code} - ${z.city_name}${z.state_abbr ? ", " + z.state_abbr : ""}` : z.code)
      const opt = document.createElement("option")
      opt.value = String(code)
      opt.textContent = String(label)
      this.zipSelectTarget.appendChild(opt)
    })

    const values = zipcodes.map(z => (typeof z === "string" ? String(z) : String(z.code)))
    if (values.includes(String(currentValue))) {
      this.zipSelectTarget.value = currentValue
    } else {
      this.zipSelectTarget.value = ""
    }

    // Feedback visual
    if (this.hasFeedbackTarget) {
      const count = zipcodes.length
      const { stateId, cityId } = this._filterContext || {}
      if (count === 0) {
        if (cityId) {
          this.feedbackTarget.textContent = "No hay códigos postales con clientes para la ciudad seleccionada"
        } else if (stateId) {
          this.feedbackTarget.textContent = "No hay códigos postales con clientes para el estado seleccionado"
        } else {
          this.feedbackTarget.textContent = "No hay códigos postales con clientes disponibles"
        }
      } else {
        if (cityId) {
          this.feedbackTarget.textContent = `ZIPs disponibles: ${count} (filtrados por ciudad)`
        } else if (stateId) {
          this.feedbackTarget.textContent = `ZIPs disponibles: ${count} (filtrados por estado)`
        } else {
          this.feedbackTarget.textContent = `ZIPs disponibles: ${count}`
        }
      }
    }
  }
}