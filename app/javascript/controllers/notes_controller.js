import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["recentContainer", "allNotesFrame", "loadMoreButton", "allNotesContent"]
  static values = { showingAll: Boolean }

  connect() {
    // Inicializar el estado
    this.showingAllValue = false
  }

  showAllNotes() {
    // Ocultar notas recientes
    this.recentContainerTarget.style.display = 'none'
    this.showingAllValue = true
  }

  toggleNotes() {
    if (this.showingAllValue) {
      // Ocultar todas las notas y mostrar las recientes
      this.hideAllNotes()
    } else {
      // Mostrar todas las notas
      this.showAllNotes()
    }
  }

  hideAllNotes() {
    // Limpiar el contenido de todas las notas
    if (this.hasAllNotesContentTarget) {
      this.allNotesContentTarget.innerHTML = ''
    }

    // Mostrar la lista de notas recientes
    this.recentContainerTarget.style.display = 'block'

    // Mostrar el botón "Ver más"
    if (this.hasLoadMoreButtonTarget) {
      this.loadMoreButtonTarget.style.display = 'block'
    }

    this.showingAllValue = false
  }
}