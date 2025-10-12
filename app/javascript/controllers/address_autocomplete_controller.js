// app/javascript/controllers/address_autocomplete_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]

  connect() {
    this.debouncedFetch = this.debounce(this.fetchSuggestions, 300)
  }

  // Se activa cada vez que el usuario escribe en el campo
  search() {
    this.debouncedFetch(this.inputTarget.value)
  }

  async fetchSuggestions(address) {
    if (address.length < 3) {
      this.resultsTarget.innerHTML = ""
      this.resultsTarget.classList.add("hidden")
      return
    }

    // URL del endpoint 'suggest' de ArcGIS
    const endpoint = `https://geocode.arcgis.com/arcgis/rest/services/World/GeocodeServer/suggest`
    const params = new URLSearchParams({
      text: address,
      f: 'json',
      countryCode: 'USA', // Limitar búsqueda a Estados Unidos
      maxSuggestions: 5,
    })

    try {
      const response = await fetch(`${endpoint}?${params}`)
      const data = await response.json()
      this.displaySuggestions(data.suggestions)
    } catch (error) {
      console.error("Error fetching address suggestions:", error)
    }
  }

  displaySuggestions(suggestions) {
    if (suggestions.length === 0) {
      this.resultsTarget.innerHTML = ""
      this.resultsTarget.classList.add("hidden")
      return
    }

    this.resultsTarget.innerHTML = suggestions.map(suggestion => {
      return `<div data-action="click->address-autocomplete#select" data-address="${suggestion.text}" class="cursor-pointer p-2 hover:bg-gray-100">${suggestion.text}</div>`
    }).join("")

    this.resultsTarget.classList.remove("hidden")
  }

  select(event) {
    this.inputTarget.value = event.currentTarget.dataset.address
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
  }

  // Función de debounce para no hacer peticiones en cada tecla
  debounce(func, wait) {
    let timeout;
    return function(...args) {
      const context = this;
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(context, args), wait);
    };
  }
}