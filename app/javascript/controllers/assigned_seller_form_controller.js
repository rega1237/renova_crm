import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "editForm", "editButton", "select", "loading"]

  connect() {
    // Configurar evento para cuando termine la actualización
    this.element.addEventListener("turbo:submit-end", (event) => {
      if (event.detail.success) {
        // La actualización fue exitosa
        this.hideLoading()
        console.log("Vendedor asignado actualizado correctamente")
      } else {
        // Hubo un error
        this.hideLoading()
        this.showEdit() // Mostrar el formulario de nuevo para corregir
        console.error("Error al actualizar vendedor asignado")
      }
    })
  }

  toggleEdit() {
    if (this.editFormTarget.classList.contains('hidden')) {
      this.showEdit()
    } else {
      this.hideEdit()
    }
  }

  showEdit() {
    this.displayTarget.classList.add('hidden')
    this.editFormTarget.classList.remove('hidden')
    this.editButtonTarget.classList.add('hidden')
    
    // Focus en el select
    setTimeout(() => {
      this.selectTarget.focus()
    }, 100)
  }

  hideEdit() {
    this.displayTarget.classList.remove('hidden')
    this.editFormTarget.classList.add('hidden')
    this.editButtonTarget.classList.remove('hidden')
  }

  cancelEdit() {
    this.hideEdit()
  }

  // Cuando se envía el formulario
  submit(event) {
    this.showLoading()
    // El formulario se envía automáticamente, turbo maneja el resto
  }

  showLoading() {
    this.editFormTarget.classList.add('hidden')
    this.loadingTarget.classList.remove('hidden')
  }

  hideLoading() {
    this.loadingTarget.classList.add('hidden')
    this.editFormTarget.classList.remove('hidden')
  }
}