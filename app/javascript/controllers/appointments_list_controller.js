import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["listContainer", "appointmentItem"]

  connect() {
    console.log("Appointments list controller connected")
  }

  openClientDetails(event) {
    event.preventDefault()
    
    const appointmentItem = event.currentTarget
    const clientPath = appointmentItem.dataset.clientPath
    
    if (clientPath) {
      // Usar Turbo para navegar al cliente en el slideover
      window.Turbo.visit(clientPath, { frame: "slideover" })
    }
  }
}