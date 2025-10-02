import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"

export default class extends Controller {
  static values = { events: Array }

  connect() {
    const calendarEl = this.element;

    const calendar = new Calendar(calendarEl, {
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

    calendar.render();
  }
}
