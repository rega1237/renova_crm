import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "editForm"]
  static values = {}

  connect() {
    // Configurar evento para cuando termine la actualización de campo
    this.element.addEventListener("turbo:submit-end", (event) => {
      if (event.detail.success) {
        // La actualización fue exitosa
        console.log("Campo actualizado correctamente")
        // Ocultar el formulario de edición y mostrar el valor actualizado
        const form = event.target.closest('[data-client-inline-edit-target="editForm"]')
        if (form) {
          const field = form.getAttribute('data-field')
          this.hideEditForm(field)
        }
      } else {
        // Hubo un error - el error se mostrará en la vista por el controlador
        console.error("Error al actualizar el campo")
      }
    })
  }

  toggleEdit(event) {
    const button = event.currentTarget
    const field = button.getAttribute('data-field')
    
    // Ocultar el formulario de edición de assigned seller si está abierto
    this.hideAssignedSellerForm()
    
    const editForm = this.getEditFormForField(field)
    const displayElement = this.getDisplayElementForField(field)
    
    if (editForm && displayElement) {
      if (editForm.classList.contains('hidden')) {
        // Mostrar formulario de edición
        this.hideAllEditForms() // Asegurarse de que otros formularios estén ocultos
        editForm.classList.remove('hidden')
        displayElement.classList.add('hidden')
      } else {
        // Ocultar formulario de edición
        this.hideEditForm(field)
      }
    }
  }

  cancelEdit(event) {
    // Encontrar el formulario padre
    const editForm = event.target.closest('[data-client-inline-edit-target="editForm"]')
    if (editForm) {
      const field = editForm.getAttribute('data-field')
      this.hideEditForm(field)
    }
  }

  hideEditForm(field) {
    const editForm = this.getEditFormForField(field)
    const displayElement = this.getDisplayElementForField(field)
    
    if (editForm) {
      editForm.classList.add('hidden')
    }
    if (displayElement) {
      displayElement.classList.remove('hidden')
    }
  }

  hideAllEditForms() {
    this.editFormTargets.forEach((form) => {
      form.classList.add('hidden')
      // También mostrar los elementos de visualización correspondientes
      const field = form.getAttribute('data-field')
      const displayElement = this.getDisplayElementForField(field)
      if (displayElement) {
        displayElement.classList.remove('hidden')
      }
    })
  }

  // Específicamente para ocultar el formulario de assigned seller si está abierto
  hideAssignedSellerForm() {
    const assignedSellerEditButton = this.element.querySelector('[data-assigned-seller-form-target="editForm"]:not(.hidden)')
    if (assignedSellerEditButton) {
      const assignedSellerController = this.element.querySelector('[data-controller="assigned-seller-form"]')
      if (assignedSellerController) {
        // Intentar llamar al método cancelEdit del controlador existente
        const cancelButtons = assignedSellerController.querySelectorAll('[data-action*="cancelEdit"]')
        if (cancelButtons.length > 0) {
          cancelButtons.forEach(button => button.click())
        }
      }
    }
  }

  getEditFormForField(field) {
    return this.editFormTargets.find(form => form.getAttribute('data-field') === field)
  }

  getDisplayElementForField(field) {
    return this.displayTargets.find(display => display.getAttribute('data-field') === field)
  }
}