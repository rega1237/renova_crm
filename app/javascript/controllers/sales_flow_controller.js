import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["board", "column", "clientList"];
  static values = { userId: Number };

  connect() {
    this.loadSortableJS().then(() => {
      this.initializeDragAndDrop();
    });
    this.connectWebSocket();
  }

  disconnect() {
    this.disconnectWebSocket();
  }

  // Cargar SortableJS desde CDN
  async loadSortableJS() {
    if (window.Sortable) return Promise.resolve();

    return new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src =
        "https://cdnjs.cloudflare.com/ajax/libs/Sortable/1.15.0/Sortable.min.js";
      script.onload = () => resolve();
      script.onerror = () => reject(new Error("Failed to load SortableJS"));
      document.head.appendChild(script);
    });
  }

  // Prevenir que el link se active cuando se hace click en el drag handle
  preventLinkClick(event) {
    event.preventDefault();
    event.stopPropagation();
  }

  // Inicializar funcionalidad de drag and drop
  initializeDragAndDrop() {
    if (!window.Sortable) {
      console.error("SortableJS not loaded");
      return;
    }

    this.clientListTargets.forEach((list) => {
      new window.Sortable(list, {
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

    // Actualizar el status en el servidor
    this.updateClientStatus(clientId, newStatus, oldStatus);

    // Actualizar el dataset de la tarjeta
    if (oldStatusElement) {
      oldStatusElement.dataset.clientStatus = newStatus;
    }
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
        // Mostrar notificación de éxito (opcional)
        console.log("Cliente actualizado correctamente");
        this.updateColumnCounts();
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

  // Actualizar contadores de las columnas
  updateColumnCounts() {
    this.columnTargets.forEach((column) => {
      const status = column.dataset.status;
      const clientList = column.querySelector(
        '[data-sales-flow-target="clientList"]'
      );
      const count = clientList ? clientList.children.length : 0;
      const badge = column.querySelector(
        ".bg-" + this.getStatusColor(status) + "-100"
      );
      if (badge) {
        badge.textContent = count;
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
    // Implementaremos esto en la siguiente fase
    console.log("WebSocket connection - to be implemented");
  }

  disconnectWebSocket() {
    // Implementaremos esto en la siguiente fase
    console.log("WebSocket disconnection - to be implemented");
  }

  // Método para manejar el inicio del drag (alternativa al handle)
  startDrag(event) {
    // Este método es para implementación futura de long press
    console.log("Start drag initiated");
  }
}
