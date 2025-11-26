import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "content"]
  
  connect() {
    // Asegurar que el overlay esté oculto al conectar
    console.log('Calls overlay controller connected successfully!')
    console.log('Element:', this.element)
    console.log('Targets:', this.overlayTarget, this.contentTarget)
    
    // Debug: Verificar que el botón existe y está accesible
    setTimeout(() => {
      const button = document.querySelector('[data-action*="calls-overlay#show"]')
      console.log('Phonebook button found:', button)
      if (button) {
        console.log('Button client ID:', button.dataset.clientId)
        // Agregar listener directo para probar
        button.addEventListener('click', (e) => {
          console.log('Direct click listener triggered')
          this.show(e)
        })
      }
    }, 1000)
    
    this.hide()
  }
  
  show(event) {
    console.log('Show method starting...')
    if (event) {
      console.log('Event received:', event.type)
      event.preventDefault()
      event.stopPropagation()
    }
    
    console.log('Show method called')
    const clientId = this.element.dataset.clientId
    console.log('Client ID from element:', clientId)
    if (!clientId) {
      console.log('No client ID found!')
      return
    }
    
    console.log('Loading calls for client:', clientId)
    // Cargar lista de llamadas
    this.loadCallsData(clientId)
    
    // Mostrar overlay
    const overlay = this.overlayTarget
    console.log('Overlay element:', overlay)
    overlay.style.display = 'block'
    overlay.style.opacity = '0'
    
    // Forzar reflow
    overlay.offsetHeight
    
    // Animar entrada
    overlay.style.transition = 'opacity 300ms ease-out'
    requestAnimationFrame(() => {
      overlay.style.opacity = '1'
      console.log('Overlay should be visible now')
    })
  }
  
  hide(event) {
    if (event) event.preventDefault()
    
    const overlay = this.overlayTarget
    overlay.style.opacity = '0'
    
    setTimeout(() => {
      overlay.style.display = 'none'
    }, 300)
  }
  
  close(event) {
    this.hide(event)
  }

  returnToClient(event) {
    this.hide(event)
  }
  
  loadCallsData(clientId) {
    fetch(`/clients/${clientId}/calls.json`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      this.contentTarget.innerHTML = data.html
    })
    .catch(error => {
      console.error('Error al cargar llamadas:', error)
      this.contentTarget.innerHTML = '<div class="p-4 text-red-600">Error al cargar las llamadas</div>'
    })
  }
  
  showCallsList(event) {
    if (event) {
      event.preventDefault()
      const button = event.currentTarget
      const clientId = button.dataset.clientId
      
      console.log('Loading calls list for client:', clientId)
      this.loadCallsData(clientId)
    }
  }

  loadCallDetails(event) {
    if (event) {
      event.preventDefault()
      const button = event.currentTarget
      const clientId = button.dataset.clientId
      const callId = button.dataset.callId
      
      console.log('Loading call details for client:', clientId, 'call:', callId)
      
      fetch(`/clients/${clientId}/call/${callId}.json`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      .then(response => response.json())
      .then(data => {
        this.contentTarget.innerHTML = data.html
      })
      .catch(error => {
        console.error('Error al cargar detalles de llamada:', error)
        this.contentTarget.innerHTML = '<div class="p-4 text-red-600">Error al cargar los detalles</div>'
      })
    }
  }
}