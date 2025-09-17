import { Controller } from "@hotwired/stimulus";
import { createConsumer } from "@rails/actioncable";
import Sortable from "sortablejs";

export default class extends Controller {
  static targets = ["board", "column", "clientList"];
  static values = { userId: Number };

  connect() {
    console.log("SalesFlow controller connected");
    this.initializeDragAndDrop();
    this.connectWebSocket();
  }

  disconnect() {
    this.disconnectWebSocket();
  }

  // Prevenir que el link se active cuando se hace click en el drag handle
  preventLinkClick(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  // Inicializar funcionalidad de drag and drop
  initializeDragAndDrop() {
    this.clientListTargets.forEach((list) => {
      new Sortable(list, {
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
    });
  }

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
    }, 100); // Pequeño delay para asegurar que el DOM se actualizó

    // Actualizar el status en el servidor
    this.updateClientStatus(clientId, newStatus, oldStatus);
  }

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
        this.updateColumnCounts();
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
    });
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
    }
  }

  // Manejar movimiento de cliente desde otro usuario
  handleRemoteClientMove(data) {
    const { client_id, old_status, new_status, client_html } = data;

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

      // Agregar la nueva tarjeta a la columna de destino
      newColumn.appendChild(newCard);

      // Agregar efecto visual para indicar que fue actualizado remotamente
      newCard.classList.add("remote-update");
      setTimeout(() => {
        newCard.classList.remove("remote-update");
      }, 2000);
    }

    // Actualizar contadores de las columnas
    this.updateColumnCounts();

    // Mostrar notificación sutil
    this.showRemoteUpdateNotification(data);
  }

  // Mostrar notificación de actualización remota
  showRemoteUpdateNotification(data) {
    // Crear notificación temporal
    const notification = document.createElement("div");
    notification.className =
      "fixed top-4 right-4 bg-blue-500 text-white px-4 py-2 rounded-lg shadow-lg z-50 transition-all duration-300 transform translate-x-full";
    notification.innerHTML = `
      <div class="flex items-center space-x-2">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path>
        </svg>
        <span class="text-sm font-medium">Cliente actualizado por otro usuario</span>
      </div>
    `;

    document.body.appendChild(notification);

    // Animar entrada
    setTimeout(() => {
      notification.classList.remove("translate-x-full");
    }, 100);

    // Remover después de 3 segundos
    setTimeout(() => {
      notification.classList.add("translate-x-full");
      setTimeout(() => {
        if (notification.parentNode) {
          notification.parentNode.removeChild(notification);
        }
      }, 300);
    }, 3000);
  }
}
