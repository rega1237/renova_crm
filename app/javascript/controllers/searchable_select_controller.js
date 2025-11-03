import { Controller } from "@hotwired/stimulus"

// Hace un select "buscable" reconstruyendo las opciones según el texto de búsqueda
// Uso básico (contenedor):
// <div data-controller="searchable-select">
//   <input data-searchable-select-target="search">
//   <select data-searchable-select-target="select">...</select>
// </div>
// Uso desacoplado (select fuera del contenedor):
// <div data-controller="searchable-select" data-searchable-select-select-selector-value="select[name='city_id']">
//   <input data-searchable-select-target="search">
// </div>
export default class extends Controller {
  static targets = ["search", "select"]
  static values = { selectSelector: String }

  connect() {
    this.selectEl = this.hasSelectTarget ? this.selectTarget : document.querySelector(this.selectSelectorValue)
    if (!this.selectEl) return
    this.allOptions = Array.from(this.selectEl.options).map(opt => ({
      value: opt.value,
      label: opt.textContent
    }))
    this.searchTarget.addEventListener("input", () => this.filter())
  }

  filter() {
    if (!this.selectEl) return
    const q = this.searchTarget.value.trim().toLowerCase()
    const matches = q.length === 0
      ? this.allOptions
      : this.allOptions.filter(o => (o.label.toLowerCase().includes(q) || o.value.toLowerCase().includes(q)))

    const currentValue = this.selectEl.value
    this.selectEl.innerHTML = ""

    matches.forEach(({ value, label }) => {
      const opt = document.createElement("option")
      opt.value = value
      opt.textContent = label
      this.selectEl.appendChild(opt)
    })

    // Preservar selección si sigue existiendo
    const values = matches.map(m => m.value)
    if (values.includes(currentValue)) {
      this.selectEl.value = currentValue
    }
  }
}