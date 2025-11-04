import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { events: Array }

  connect() {
    this.setupCalendar()
    this.setupActionCable()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupCalendar() {
    const calendarEl = this.element;

    this.calendar = new Calendar(calendarEl, {
      timeZone: 'America/Chicago',
      plugins: [dayGridPlugin, timeGridPlugin],
      initialView: 'dayGridMonth',
      headerToolbar: {
        left: 'prev,next today',
        center: 'title',
        right: 'dayGridMonth,timeGridWeek,timeGridDay'
      },
      events: this.eventsValue,
      eventClick: function(info) {
        // Al hacer clic en un evento, abre el panel de detalles del cliente
        const clientPath = info.event.extendedProps.clientPath;
        if (clientPath) {
          // Usamos Turbo para navegar al cliente en el slideover
          window.Turbo.visit(clientPath, { frame: "slideover" });
        }
      }
    });

    this.calendar.render();
  }

  setupActionCable() {
    const consumer = createConsumer()
    
    this.subscription = consumer.subscriptions.create("CalendarChannel", {
      received: (data) => {
        if (data.action === "refresh_calendar") {
          this.refreshCalendar()
        }
      }
    })
  }

  async refreshCalendar() {
    try {
      // Hacer fetch de los eventos actualizados sin recargar la página
      const response = await fetch('/calendar.json')
      const events = await response.json()
      
      // Actualizar los eventos del calendario
      this.calendar.removeAllEvents()
      this.calendar.addEventSource(events)
    } catch (error) {
      console.error('Error refreshing calendar:', error)
      // Fallback: recargar la página solo si hay error
      window.location.reload()
    }
  }
}
