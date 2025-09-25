import { Controller } from "@hotwired/stimulus";
import { createConsumer } from "@rails/actioncable";
import Sortable from "sortablejs";

export default class extends Controller {
  static targets = ["board", "column", "clientList"];
  static values = { userId: Number };

  // =============================================
  // MÉTODOS DE CONEXIÓN Y CONFIGURACIÓN INICIAL
  // =============================================

  connect() {
    console.log("SalesFlow controller connected");
    this.initializeDragAndDrop();
    this.connectWebSocket();
  }

  disconnect() {
    this.disconnectWebSocket();
    this.destroyDragAndDrop();
  }

  // Método que se ejecuta cuando Turbo Frame actualiza el contenido
  boardTargetConnected() {
    console.log("Board reconnected - reinitializing drag and drop");
    // Destruir instancias anteriores antes de crear nuevas
    this.destroyDragAndDrop();
    // Pequeño delay para asegurar que el DOM esté completamente renderizado
    setTimeout(() => {
      this.initializeDragAndDrop();
    }, 100);
  }

  // =============================================
  // MÉTODOS DE DRAG AND DROP
  // =============================================

  // Inicializar funcionalidad de drag and drop
  initializeDragAndDrop() {
    // Inicializar array para tracking de instancias si no existe
    this.sortableInstances = this.sortableInstances || [];

    this.clientListTargets.forEach((list) => {
      const sortableInstance = new Sortable(list, {
        group: "kanban-clients",
        animation: 150,
        ghostClass: "sortable-ghost",
        chosenClass: "sortable-chosen",
        dragClass: "sortable-drag",

        // Solo permitir drag desde el handle
        handle: ".drag-handle",

        // Cuando se suelta en una nueva columna
        onEnd: (evt) => {
          this.handleClientMove(evt);
        },

        // Visual feedback durante el drag
        onStart: (evt) => {
          evt.item.classList.add("dragging");
        },

        onUnchoose: (evt) => {
          evt.item.classList.remove("dragging");
        },
      });

      // Guardar referencia para poder destruir después
      this.sortableInstances.push(sortableInstance);
    });

    console.log(
      `Initialized ${this.sortableInstances.length} sortable instances`
    );
  }

  // Método para destruir instancias de Sortable existentes
  destroyDragAndDrop() {
    if (this.sortableInstances) {
      this.sortableInstances.forEach((instance) => {
        if (instance && instance.destroy) {
          instance.destroy();
        }
      });
      this.sortableInstances = [];
    }
  }

  // Prevenir que el link se active cuando se hace click en el drag handle
  preventLinkClick(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  // =============================================
  // MÉTODOS DE MOVIMIENTO DE CLIENTES
  // =============================================

  // Manejar el movimiento de cliente entre columnas
  handleClientMove(evt) {
    const clientCard = evt.item;
    const clientId =
      clientCard.querySelector("[data-client-id]")?.dataset.clientId ||
      clientCard.dataset.clientId;
    const newStatus = evt.to.closest("[data-status]").dataset.status;
    const oldStatusElement =
      clientCard.querySelector("[data-client-status]") || clientCard;
    const oldStatus = oldStatusElement.dataset.clientStatus;

    // Si no cambió de columna, no hacer nada
    if (newStatus === oldStatus) return;

    // Marcar este movimiento como local para evitar procesarlo como remoto
    this.localMoves = this.localMoves || new Set();
    this.localMoves.add(clientId);

    // Actualizar el dataset de la tarjeta ANTES de la llamada al servidor
    if (oldStatusElement) {
      oldStatusElement.dataset.clientStatus = newStatus;
    }

    // Actualizar contadores inmediatamente (optimistic update)
    setTimeout(() => {
      this.updateColumnCounts();
      // Reorganizar elementos después del movimiento
      this.reorganizeColumnsByDate();
    }, 100);

    // Actualizar el status en el servidor
    this.updateClientStatus(clientId, newStatus, oldStatus);
  }

  // Revertir movimiento en caso de error
  revertClientMove(clientId, originalStatus) {
    const clientCard =
      document
        .querySelector(`[data-client-id="${clientId}"]`)
        ?.closest(".client-card") ||
      document.querySelector(`a[href*="${clientId}"]`);
    const originalColumn = document.querySelector(
      `[data-status="${originalStatus}"] [data-sales-flow-target="clientList"]`
    );

    if (clientCard && originalColumn) {
      originalColumn.appendChild(clientCard);
      const statusElement =
        clientCard.querySelector("[data-client-status]") || clientCard;
      if (statusElement) {
        statusElement.dataset.clientStatus = originalStatus;
      }
    }
  }

  // =============================================
  // MÉTODOS DE ACTUALIZACIÓN DEL SERVIDOR
  // =============================================

  // Actualizar status del cliente en el servidor
  async updateClientStatus(clientId, newStatus, oldStatus) {
    try {
      const response = await fetch(`/clients/${clientId}/update_status`, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        },
        body: JSON.stringify({
          status: newStatus,
        }),
      });

      const result = await response.json();

      if (result.status === "success") {
        console.log("Cliente actualizado correctamente");

        // Actualizar el timestamp en el card para el ordenamiento correcto
        const clientCard = document
          .querySelector(`[data-client-id="${clientId}"]`)
          ?.closest(".client-card");
        if (clientCard) {
          // Actualizar con el timestamp actual para que aparezca primero
          clientCard.dataset.updatedAt = new Date().toISOString();
        }

        this.updateColumnCounts();
        // Reorganizar para colocar el elemento movido en la posición correcta
        setTimeout(() => {
          this.reorganizeColumnsByDate();
        }, 200);

        // Limpiar el movimiento local después de un tiempo para permitir que el broadcast se procese
        setTimeout(() => {
          if (this.localMoves) {
            this.localMoves.delete(clientId);
          }
        }, 1000);
      } else {
        // Revertir el movimiento si hubo error
        console.error("Error al actualizar cliente:", result.errors);
        this.revertClientMove(clientId, oldStatus);
      }
    } catch (error) {
      console.error("Error de red:", error);
      this.revertClientMove(clientId, oldStatus);
    }
  }

  // =============================================
  // MÉTODOS DE ORGANIZACIÓN Y ORDENAMIENTO
  // =============================================

  // Reorganizar elementos por fecha
  reorganizeColumnsByDate() {
    this.columnTargets.forEach((column) => {
      const status = column.dataset.status;
      const clientList = column.querySelector(
        '[data-sales-flow-target="clientList"]'
      );
      if (!clientList) return;

      const clientCards = Array.from(
        clientList.querySelectorAll(".client-card, a[data-client-id]")
      );

      // Ordenar por fecha según el tipo de estado
      clientCards.sort((a, b) => {
        const dateA = this.getCardDate(a, status);
        const dateB = this.getCardDate(b, status);
        return dateB - dateA; // Más recientes primero
      });

      // Reorganizar en el DOM
      clientCards.forEach((card) => {
        clientList.appendChild(card);
      });
    });
  }

  // Encontrar la posición correcta para insertar un elemento
  findCorrectInsertPosition(column, newCard, status) {
    const existingCards = Array.from(
      column.querySelectorAll(".client-card, a[data-client-id]")
    );
    const newCardDate = this.getCardDate(newCard, status);

    // Para leads, ordenar por created_at (más nuevos primero)
    // Para otros estados, ordenar por updated_at (más nuevos primero)
    for (let existingCard of existingCards) {
      const existingCardDate = this.getCardDate(existingCard, status);

      // Si la nueva tarjeta es más reciente, insertarla antes de esta
      if (newCardDate > existingCardDate) {
        return existingCard;
      }
    }

    // Si no encontró una posición, el elemento va al final
    return null;
  }

  // Obtener fecha de una tarjeta para comparación
  getCardDate(card, status) {
    // Primero verificar si hay un timestamp en el dataset
    if (card.dataset.updatedAt) {
      return new Date(card.dataset.updatedAt);
    }

    // Extraer fecha del contenido de la tarjeta
    const dateText = card.querySelector(
      '[class*="text-gray-400"]'
    )?.textContent;

    if (dateText && dateText.includes("Creado:")) {
      const dateMatch = dateText.match(/\d{2}\/\d{2}/);
      if (dateMatch) {
        const [day, month] = dateMatch[0].split("/");
        return new Date(new Date().getFullYear(), month - 1, day);
      }
    }

    // Si es status "lead", usar created_at; para otros, usar el timestamp actual como fallback
    if (status === "lead") {
      return new Date(0); // Fecha antigua para leads sin fecha específica
    } else {
      return new Date(); // Fecha actual para otros estados
    }
  }

  // =============================================
  // MÉTODOS DE CONTADORES Y UI
  // =============================================

  // Actualizar contadores de las columnas
  updateColumnCounts() {
    this.columnTargets.forEach((column) => {
      const status = column.dataset.status;
      const clientList = column.querySelector(
        '[data-sales-flow-target="clientList"]'
      );

      if (!clientList) return;

      // Limpiar duplicados antes de contar
      this.removeDuplicateClients(clientList);

      // Contar solo elementos únicos por client-id
      const uniqueClientIds = new Set();
      const clientCards = clientList.querySelectorAll(
        "[data-client-id], .client-card[data-client-id], a[data-client-id]"
      );

      clientCards.forEach((card) => {
        const clientId =
          card.dataset.clientId ||
          card.querySelector("[data-client-id]")?.dataset.clientId;
        if (clientId) {
          uniqueClientIds.add(clientId);
        }
      });

      const count = uniqueClientIds.size;

      // Actualizar el badge - método más robusto
      this.updateColumnBadge(column, status, count);

      // Mostrar/ocultar mensaje "Sin clientes" según el conteo
      this.updateEmptyStateMessage(column, count);
    });
  }

  // Método auxiliar para actualizar el badge
  updateColumnBadge(column, status, count) {
    // Buscar el badge de múltiples formas posibles
    const statusColor = this.getStatusColor(status);
    let badge =
      column.querySelector(`.bg-${statusColor}-100`) ||
      column.querySelector("[data-count-badge]") ||
      column.querySelector(".badge") ||
      column.querySelector(".count-badge");

    if (badge) {
      badge.textContent = count;
    } else {
      // Si no encuentra el badge, buscar por texto que contenga números
      const allElements = column.querySelectorAll("*");
      for (let element of allElements) {
        const text = element.textContent.trim();
        if (/^\d+$/.test(text) && element.children.length === 0) {
          element.textContent = count;
          break;
        }
      }
    }
  }

  // Método para manejar el mensaje de "Sin clientes" en las columnas
  updateEmptyStateMessage(column, count) {
    // Buscar el mensaje de "Sin clientes" primera forma
    let emptyMessage = null;
    let emptyIcon = null;

    // Buscar por clases CSS comunes
    emptyMessage =
      column.querySelector(".empty-state") ||
      column.querySelector('[class*="sin-clientes"]') ||
      column.querySelector('[class*="Sin clientes"]');

    // Si no se encuentra por clase, buscar por contenido de texto
    if (!emptyMessage) {
      const allElements = column.querySelectorAll("*");
      for (const element of allElements) {
        const text = element.textContent
          ? element.textContent.trim().toLowerCase()
          : "";
        if (text === "sin clientes" && element.children.length === 0) {
          emptyMessage = element;
          break;
        }
      }
    }

    // Buscar el ícono de carpeta vacía
    emptyIcon =
      column.querySelector('svg[class*="folder"]') ||
      column.querySelector('svg[class*="empty"]') ||
      column.querySelector(".empty-icon");

    // Si no encuentra ícono específico, buscar cualquier SVG que esté cerca del mensaje
    if (!emptyIcon && emptyMessage) {
      const parentElement = emptyMessage.parentElement;
      if (parentElement) {
        emptyIcon = parentElement.querySelector("svg");
      }
    }

    if (count === 0) {
      // Si no hay clientes, mostrar mensaje e ícono
      if (emptyMessage) emptyMessage.style.display = "";
      if (emptyIcon) emptyIcon.style.display = "";
    } else {
      // Si hay clientes, ocultar mensaje e ícono
      if (emptyMessage) emptyMessage.style.display = "none";
      if (emptyIcon) emptyIcon.style.display = "none";
    }
  }

  // Método para remover clientes duplicados en una columna
  removeDuplicateClients(clientList) {
    const seenClientIds = new Set();
    const clientCards = clientList.querySelectorAll(
      "[data-client-id], .client-card[data-client-id], a[data-client-id]"
    );

    clientCards.forEach((card) => {
      const clientId =
        card.dataset.clientId ||
        card.querySelector("[data-client-id]")?.dataset.clientId;

      if (clientId) {
        if (seenClientIds.has(clientId)) {
          // Remover duplicado
          const cardToRemove = card.classList.contains("client-card")
            ? card
            : card.closest(".client-card");
          if (cardToRemove && cardToRemove.parentNode) {
            cardToRemove.remove();
            console.log(`Removed duplicate client ${clientId}`);
          }
        } else {
          seenClientIds.add(clientId);
        }
      }
    });
  }

  // Obtener color del status
  getStatusColor(status) {
    const colors = {
      lead: "blue",
      no_contesto: "gray",
      seguimiento: "yellow",
      cita_agendada: "purple",
      reprogramar: "orange",
      vendido: "green",
      mal_credito: "red",
      no_cerro: "red",
    };
    return colors[status] || "gray";
  }

  // =============================================
  // MÉTODOS DE WEBSOCKET Y TIEMPO REAL
  // =============================================

  // Conectar WebSocket para actualizaciones en tiempo real
  connectWebSocket() {
    if (this.subscription) return;

    this.subscription = this.createConsumer().subscriptions.create(
      "SalesFlowChannel",
      {
        connected: () => {
          console.log("Connected to SalesFlowChannel");
        },

        disconnected: () => {
          console.log("Disconnected from SalesFlowChannel");
        },

        received: (data) => {
          this.handleBroadcastMessage(data);
        },
      }
    );
  }

  disconnectWebSocket() {
    if (this.subscription) {
      this.subscription.unsubscribe();
      this.subscription = null;
    }
  }

  // Crear consumer de ActionCable
  createConsumer() {
    if (!this.consumer) {
      this.consumer = createConsumer();
    }
    return this.consumer;
  }

  // Manejar mensajes broadcast
  handleBroadcastMessage(data) {
    console.log("Received broadcast:", data);
    if (data.action === "client_moved") {
      this.handleRemoteClientMove(data);
    } else if (data.action === "new_lead_created") {
      this.handleNewLead(data);
    }
  }

  // Manejar movimiento de cliente desde otro usuario
  handleRemoteClientMove(data) {
    const {
      client_id,
      client_name,
      updated_by_name,
      old_status,
      new_status,
      client_html,
    } = data;

    // Verificar si este movimiento fue iniciado localmente
    if (this.localMoves && this.localMoves.has(client_id)) {
      this.localMoves.delete(client_id);
      return; // No procesar movimientos locales
    }

    // Buscar la tarjeta del cliente actual
    const currentCard = document.querySelector(
      `[data-client-id="${client_id}"]`
    );

    if (currentCard) {
      // Remover la tarjeta de su posición actual
      const currentCardElement = currentCard.closest(".client-card");
      if (currentCardElement) {
        currentCardElement.remove();
      }
    }

    // Encontrar la nueva columna de destino
    const newColumn = document.querySelector(
      `[data-status="${new_status}"] [data-sales-flow-target="clientList"]`
    );

    if (newColumn) {
      // Crear un elemento temporal para insertar el HTML
      const tempDiv = document.createElement("div");
      tempDiv.innerHTML = client_html;
      const newCard = tempDiv.firstElementChild;

      // Agregar timestamp actual para ordenamiento correcto
      newCard.dataset.updatedAt = new Date().toISOString();

      // Encontrar la posición correcta para insertar el elemento
      const insertPosition = this.findCorrectInsertPosition(
        newColumn,
        newCard,
        new_status
      );

      if (insertPosition) {
        newColumn.insertBefore(newCard, insertPosition);
      } else {
        // Si no hay posición específica, insertar al principio (más reciente)
        newColumn.insertBefore(newCard, newColumn.firstChild);
      }

      // Agregar efecto visual para indicar que fue actualizado remotamente
      newCard.classList.add("remote-update");
      setTimeout(() => {
        newCard.classList.remove("remote-update");
      }, 2000);
    }

    // Actualizar contadores
    this.updateColumnCounts();

    // Mostrar notificación sutil
    this.showRemoteUpdateNotification(data);
  }

  // Metodo para manejar el broadcast del nuevo lead y insertarlo
  handleNewLead(data) {
    const { client_html } = data;

    const leadColumnList = this.element.querySelector(
      '[data-status="lead"] [data-sales-flow-target="clientList"]'
    );

    if (leadColumnList) {
      const tempDiv = document.createElement("div");
      tempDiv.innerHTML = client_html.trim();

      const newCard = tempDiv.firstElementChild; 

      if (newCard) {
        leadColumnList.prepend(newCard);

        newCard.classList.add("remote-update");
        setTimeout(() => {
          newCard.classList.remove("remote-update");
        }, 2500);

        this.updateColumnCounts();
        this.showRemoteUpdateNotification(data);
      }
    }
  }

  // =============================================
  // MÉTODOS DE NOTIFICACIONES
  // =============================================

  // Mostrar notificación de actualización remota
  showRemoteUpdateNotification(data) {
    let title = "";
    let message = "";
    let bgColor = "bg-blue-500"; // Color por defecto para movimientos

    if (data.action === "client_moved") {
      title = `Cliente ${data.client_name}`;
      message = `Movido a ${data.new_status.replace("_", " ")} por ${
        data.updated_by_name
      }`;
    } else if (data.action === "new_lead_created") {
      title = "¡Nuevo Lead!";
      message = `${data.client_name} ha entrado desde Meta.`;
      bgColor = "bg-green-500"; // Color verde para nuevos leads
    }

    // Crear notificación temporal
    const notification = document.createElement("div");
    notification.className = `fixed top-4 right-4 ${bgColor} text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all duration-300 transform translate-x-full`;

    notification.innerHTML = `
      <div class="flex items-center space-x-2">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <div class="flex flex-col">
          <span class="text-sm font-medium">${title}</span>
          <span class="text-xs opacity-90">${message}</span>
        </div>
      </div>
    `;

    document.body.appendChild(notification);

    // Animar entrada
    setTimeout(() => {
      notification.classList.remove("translate-x-full");
    }, 100);

    // Remover después de 4 segundos
    setTimeout(() => {
      notification.classList.add("translate-x-full");
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }, 4000);
  }
}
