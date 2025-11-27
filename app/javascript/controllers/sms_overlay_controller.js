import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "content", "messageInput", "messagesContainer", "sendButton"]
  
  connect() {
    // Asegurar que el overlay esté oculto al conectar
    console.log('SMS overlay controller connected successfully!')
    console.log('Element:', this.element)
    console.log('Targets:', this.overlayTarget, this.contentTarget)
    
    // Asegurar que el overlay esté oculto inicialmente
    this.overlayTarget.classList.add('hidden')
    this.overlayTarget.style.opacity = '0'
    
    // Debug: Verificar que el botón existe y está accesible
    setTimeout(() => {
      const button = document.querySelector('[data-action*="sms-overlay#show"]')
      console.log('SMS button found:', button)
      if (button) {
        console.log('Button client ID:', button.dataset.clientId)
      }
    }, 1000)
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
    
    console.log('Loading SMS messages for client:', clientId)
    // Cargar lista de mensajes SMS
    this.loadSmsData(clientId)
    
    // Mostrar overlay
    const overlay = this.overlayTarget
    console.log('Overlay element:', overlay)
    overlay.classList.remove('hidden')
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
      overlay.classList.add('hidden')
    }, 300)
  }
  
  close(event) {
    this.hide(event)
  }

  returnToClient(event) {
    this.hide(event)
  }
  
  loadSmsData(clientId) {
    fetch(`/clients/${clientId}/sms_messages.json`, {
      headers: {
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      // Reemplazar todo el contenido del overlay con el HTML recibido
      this.contentTarget.innerHTML = data.html
      
      // Hacer scroll al final después de cargar los mensajes
      setTimeout(() => {
        this.scrollToBottom()
      }, 100)
    })
    .catch(error => {
      console.error('Error al cargar mensajes SMS:', error)
      this.contentTarget.innerHTML = '<div class="p-4 text-red-600">Error al cargar los mensajes SMS</div>'
    })
  }
  
  showSmsList(event) {
    if (event) {
      event.preventDefault()
      const button = event.currentTarget
      const clientId = button.dataset.clientId
      
      console.log('Loading SMS list for client:', clientId)
      this.loadSmsData(clientId)
    }
  }

  loadSmsDetails(event) {
    if (event) {
      event.preventDefault()
      const button = event.currentTarget
      const clientId = button.dataset.clientId
      const smsId = button.dataset.smsId
      
      console.log('Loading SMS details for client:', clientId, 'SMS:', smsId)
      
      fetch(`/clients/${clientId}/sms_message/${smsId}.json`, {
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
        console.error('Error al cargar detalles de SMS:', error)
        this.contentTarget.innerHTML = '<div class="p-4 text-red-600">Error al cargar los detalles del mensaje</div>'
      })
    }
  }

  // Métodos para la interfaz conversacional
  adjustTextareaHeight() {
    const textarea = this.messageInputTarget
    textarea.style.height = 'auto'
    textarea.style.height = Math.min(textarea.scrollHeight, 128) + 'px' // Máximo 32px * 4 líneas
  }

  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage()
    }
  }

  sendMessage() {
    const message = this.messageInputTarget.value.trim()
    const clientId = this.element.dataset.clientId
    
    if (!message || !clientId) return
    
    // Deshabilitar el botón mientras se envía
    this.sendButtonTarget.disabled = true
    this.sendButtonTarget.innerHTML = '<svg class="animate-spin h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>'
    
    fetch(`/clients/${clientId}/send_sms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'X-Requested-With': 'XMLHttpRequest'
      },
      body: JSON.stringify({ message: message })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Limpiar el campo de texto
        this.messageInputTarget.value = ''
        this.adjustTextareaHeight()
        
        // Agregar el mensaje a la conversación
        this.addMessageToConversation(data.sms)
        
        // Hacer scroll al último mensaje
        this.scrollToBottom()
      } else {
        alert('Error al enviar el mensaje: ' + (data.error || 'Error desconocido'))
      }
    })
    .catch(error => {
      console.error('Error al enviar SMS:', error)
      alert('Error al enviar el mensaje')
    })
    .finally(() => {
      // Rehabilitar el botón
      this.sendButtonTarget.disabled = false
      this.sendButtonTarget.innerHTML = '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path></svg>'
    })
  }

  addMessageToConversation(sms) {
    const messageHtml = `
      <div class="flex justify-end mb-4 animate-slide-in-right">
        <div class="max-w-xs lg:max-w-md">
          <div class="bg-blue-500 rounded-2xl rounded-tr-sm px-4 py-3 shadow-sm">
            <p class="text-sm text-white leading-relaxed">${this.escapeHtml(sms.message_body)}</p>
          </div>
          <div class="mt-1 px-2 flex items-center justify-between">
            <span class="text-xs text-gray-500">${this.formatDateTime(sms.sms_time)}</span>
            <span class="text-xs text-blue-600 font-medium">${sms.sender_name || 'Tú'}</span>
          </div>
        </div>
      </div>
    `
    
    this.messagesContainerTarget.insertAdjacentHTML('beforeend', messageHtml)
  }

  scrollToBottom() {
    this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  formatDateTime(dateTimeStr) {
    const d = new Date(dateTimeStr)
    return d.toLocaleDateString('es-ES', { 
      day: '2-digit', 
      month: '2-digit', 
      year: 'numeric',
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }
}