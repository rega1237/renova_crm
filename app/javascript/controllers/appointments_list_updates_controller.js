import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["listContainer"]

  connect() {
    this.setupActionCable()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupActionCable() {
    const consumer = createConsumer()
    
    this.subscription = consumer.subscriptions.create("CalendarChannel", {
      received: (data) => {
        if (data.action === "refresh_calendar") {
          this.refreshAppointmentsList()
        }
      }
    })
  }

  async refreshAppointmentsList() {
    try {
      // Obtener los parámetros de filtro actuales de la URL
      const urlParams = new URLSearchParams(window.location.search)
      const currentParams = {}
      
      if (urlParams.get('start_date')) {
        currentParams.start_date = urlParams.get('start_date')
      }
      if (urlParams.get('end_date')) {
        currentParams.end_date = urlParams.get('end_date')
      }
      
      // Construir la URL con los parámetros actuales
      const queryString = new URLSearchParams(currentParams).toString()
      const url = `/appointments_list${queryString ? '?' + queryString : ''}`
      
      // Hacer fetch de la lista actualizada
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'Turbo-Frame': 'appointments-list-content'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, 'text/html')
        const newContent = doc.querySelector('#appointments-list-content')
        
        if (newContent && this.listContainerTarget) {
          this.listContainerTarget.innerHTML = newContent.innerHTML
        }
      }
    } catch (error) {
      console.error('Error refreshing appointments list:', error)
    }
  }
}