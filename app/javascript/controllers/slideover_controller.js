import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "panel"]
  
  connect() {
    this.showOverlay()
    this.bindEscapeKey()
  }
  
  disconnect() {
    this.cleanup()
  }
  
  showOverlay() {
    // Prevenir scroll del body
    document.body.style.overflow = 'hidden'
    
    // Iniciar con opacidad 0 y panel fuera de pantalla
    this.overlayTarget.style.opacity = '0'
    this.panelTarget.style.transform = 'translateX(100%)'
    
    // Forzar un reflow para que los estilos se apliquen
    this.overlayTarget.offsetHeight
    
    // Aplicar la transición
    this.overlayTarget.style.transition = 'opacity 300ms ease-out'
    this.panelTarget.style.transition = 'transform 300ms ease-out'
    
    // Mostrar con transición
    requestAnimationFrame(() => {
      this.overlayTarget.style.opacity = '1'
      this.panelTarget.style.transform = 'translateX(0)'
    })
  }
  
  close(event) {
    if (event) {
      event.preventDefault()
    }
    
    // Evitar múltiples clics
    if (this.isClosing) return
    this.isClosing = true
    
    // Aplicar transición de salida
    this.overlayTarget.style.opacity = '0'
    this.panelTarget.style.transform = 'translateX(100%)'
    
    // Después de la transición, navegar para cerrar
    setTimeout(() => {
      this.cleanup()
      window.Turbo.visit('/clients', { frame: 'slideover' })
    }, 300)
  }
  
  clickOutside(event) {
    // Solo cerrar si el clic fue directamente en el overlay
    if (event.target === this.overlayTarget) {
      this.close(event)
    }
  }
  
  preventClose(event) {
    event.stopPropagation()
  }
  
  bindEscapeKey() {
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
  }
  
  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close(event)
    }
  }
  
  cleanup() {
    // Restaurar scroll del body
    document.body.style.overflow = 'auto'
    
    // Remover event listener de ESC
    if (this.escapeHandler) {
      document.removeEventListener('keydown', this.escapeHandler)
    }
    
    // Limpiar variables
    this.isClosing = false
    this.escapeHandler = null
  }
}