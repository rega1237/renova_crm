import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Date filter controller connected")
  }

  filterAppointments(event) {
    // El formulario se enviará automáticamente con Turbo
    const startDate = event.target.querySelector('[name="start_date"]').value
    const endDate = event.target.querySelector('[name="end_date"]').value
    
    // Validar que la fecha de inicio no sea posterior a la fecha de fin
    if (startDate && endDate && new Date(startDate) > new Date(endDate)) {
      event.preventDefault()
      alert("La fecha de inicio no puede ser posterior a la fecha de fin")
      return false
    }
  }
}