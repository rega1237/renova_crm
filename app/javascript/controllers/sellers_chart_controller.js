import { Controller } from "@hotwired/stimulus";
import ApexCharts from "apexcharts";

// Connects to data-controller="sellers-chart"
export default class extends Controller {
  static targets = [
    "chart",
    // filters
    "seller",
    "status",
    "month",
    "dateFrom",
    "dateTo",
    "dateFromWrapper",
    "dateToWrapper",
    "day",
    // KPI targets
    "kpiVendido",
    "kpiMalCredito",
    "kpiNoCerroNoAplico",
    "kpiNoCerroBuenCredito",
    "kpiNoCerroNoPresento",
    "kpiCitaAgendada"
  ];

  connect() {
    this.chartInstances = [];
    this.setupMonthSubfilters();
    this.fetchAndRender();
  }

  disconnect() {
    if (this.chartInstances && this.chartInstances.length) {
      this.chartInstances.forEach((inst) => inst.destroy());
      this.chartInstances = [];
    }
  }

  updateFilters() {
    this.setupMonthSubfilters();
    this.fetchAndRender();
  }

  setupMonthSubfilters() {
    const monthVal = this.hasMonthTarget ? this.monthTarget.value : null;
    const hasMonth = Boolean(monthVal);

    if (this.hasDateFromWrapperTarget) {
      this.dateFromWrapperTarget.classList.toggle("hidden", !hasMonth);
    }
    if (this.hasDateToWrapperTarget) {
      this.dateToWrapperTarget.classList.toggle("hidden", !hasMonth);
    }

    if (this.hasDateFromTarget) this.dateFromTarget.disabled = !hasMonth;
    if (this.hasDateToTarget) this.dateToTarget.disabled = !hasMonth;

    if (hasMonth) {
      const [yearStr, monthStr] = monthVal.split("-");
      const year = parseInt(yearStr, 10);
      const month = parseInt(monthStr, 10);
      const start = new Date(year, month - 1, 1);
      const end = new Date(year, month, 0);
      const startISO = start.toISOString().slice(0, 10);
      const endISO = end.toISOString().slice(0, 10);
      if (this.hasDateFromTarget) {
        this.dateFromTarget.min = startISO;
        this.dateFromTarget.max = endISO;
        if (this.dateFromTarget.value && (this.dateFromTarget.value < startISO || this.dateFromTarget.value > endISO)) {
          this.dateFromTarget.value = startISO;
        }
      }
      if (this.hasDateToTarget) {
        this.dateToTarget.min = startISO;
        this.dateToTarget.max = endISO;
        if (this.dateToTarget.value && (this.dateToTarget.value < startISO || this.dateToTarget.value > endISO)) {
          this.dateToTarget.value = endISO;
        }
      }
    } else {
      if (this.hasDateFromTarget) {
        this.dateFromTarget.min = "";
        this.dateFromTarget.max = "";
      }
      if (this.hasDateToTarget) {
        this.dateToTarget.min = "";
        this.dateToTarget.max = "";
      }
    }
  }

  async fetchAndRender() {
    const params = new URLSearchParams();

    const sellerId = this.hasSellerTarget ? this.sellerTarget.value : null;
    const statusKey = this.hasStatusTarget ? this.statusTarget.value : null; // ya no se usa para pie, pero se mantiene por compatibilidad
    const month = this.hasMonthTarget ? this.monthTarget.value : null;
    const dateFrom = this.hasDateFromTarget ? this.dateFromTarget.value : null;
    const dateTo = this.hasDateToTarget ? this.dateToTarget.value : null;
    const day = this.hasDayTarget ? this.dayTarget.value : null;

    if (sellerId) params.append("seller_id", sellerId);
    if (statusKey) params.append("status", statusKey);

    if (day) {
      params.append("day", day);
    } else if (month) {
      params.append("month", month);
      if (dateFrom) params.append("date_from", dateFrom);
      if (dateTo) params.append("date_to", dateTo);
    }

    try {
      const response = await fetch(`/dashboard/sellers_metrics.json?${params.toString()}`, {
        headers: { "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content }
      });
      const data = await response.json();
      this.renderPieCharts(data);
      this.updateKpis(data);
    } catch (e) {
      console.error("Error cargando métricas de vendedores", e);
    }
  }

  updateKpis(data) {
    const totals = data.totals_by_status || {};
    const nameMap = {
      "Vendido": "kpiVendido",
      "Mal credito": "kpiMalCredito",
      "No cerro (no aplico)": "kpiNoCerroNoAplico",
      "No cerro (buen credito)": "kpiNoCerroBuenCredito",
      "No cerro (no presento)": "kpiNoCerroNoPresento",
      "Citas agendadas": "kpiCitaAgendada"
    };

    const setText = (targetName, value) => {
      const hasProp = this[`has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}Target`];
      const el = this[`${targetName}Target`];
      if (hasProp && el) el.textContent = value;
    };

    Object.entries(nameMap).forEach(([human, target]) => {
      const val = Number(totals[human] || 0);
      setText(target, val);
    });
  }

  renderPieCharts(data) {
    const pieBySeller = data.pie_by_seller || [];

    // Limpiar contenedor y destruir instancias previas
    if (this.chartInstances && this.chartInstances.length) {
      this.chartInstances.forEach((inst) => inst.destroy());
      this.chartInstances = [];
    }
    if (this.hasChartTarget) {
      this.chartTarget.innerHTML = "";
    }

    if (!pieBySeller.length) {
      // Mostrar mensaje sin datos
      const empty = document.createElement("div");
      empty.className = "w-full text-center text-gray-500 py-12";
      empty.textContent = "Sin datos";
      this.chartTarget.appendChild(empty);
      return;
    }

    // Colores por estado para consistencia
    const colorMap = {
      "Vendido": "#10b981", // green
      "Mal credito": "#ef4444", // red
      "No cerro (no aplico)": "#6366f1", // indigo
      "No cerro (buen credito)": "#8b5cf6", // violet
      "No cerro (no presento)": "#f97316", // orange
      "Citas agendadas": "#3b82f6" // blue
    };

    // Renderizar un pie por vendedor
    pieBySeller.forEach((entry, idx) => {
      const labels = entry.data.map((d) => d.label);
      const series = entry.data.map((d) => Number(d.value || 0));
      const colors = labels.map((l) => colorMap[l] || "#64748b");

      const wrapper = document.createElement("div");
      wrapper.className = "bg-white rounded-xl p-4 shadow-sm border border-gray-100";

      const title = document.createElement("div");
      title.className = "text-sm font-semibold text-gray-700 mb-2";
      title.textContent = entry.seller_name;
      wrapper.appendChild(title);

      const chartEl = document.createElement("div");
      chartEl.style.width = "100%";
      chartEl.style.height = "320px";
      wrapper.appendChild(chartEl);

      this.chartTarget.appendChild(wrapper);

      const totalSeries = series.reduce((a, b) => a + b, 0);
      const options = {
        chart: { type: "pie", height: 320, toolbar: { show: false } },
        labels,
        series,
        colors,
        dataLabels: {
          enabled: true,
          formatter: function (val, opts) {
            const idx = opts && typeof opts.seriesIndex === "number" ? opts.seriesIndex : -1;
            const num = idx >= 0 ? (series[idx] || 0) : 0;
            const pct = totalSeries > 0 ? Math.round((num / totalSeries) * 100) : 0;
            return `${num} (${pct}%)`;
          }
        },
        legend: {
          position: "bottom",
          fontFamily: "Poppins",
          formatter: function (seriesName, opts) {
            const idx = opts && typeof opts.seriesIndex === "number" ? opts.seriesIndex : -1;
            const num = idx >= 0 ? (series[idx] || 0) : 0;
            const pct = totalSeries > 0 ? Math.round((num / totalSeries) * 100) : 0;
            return `${seriesName} (${num}, ${pct}%)`;
          }
        },
        tooltip: {
          y: {
            formatter: function (value, opts) {
              const idx = opts && typeof opts.seriesIndex === "number" ? opts.seriesIndex : -1;
              const num = idx >= 0 ? (series[idx] || 0) : value;
              const pct = totalSeries > 0 ? Math.round(((idx >= 0 ? (series[idx] || 0) : value) / totalSeries) * 100) : 0;
              return `${num} (${pct}%)`;
            }
          }
        },
        responsive: [{
          breakpoint: 480,
          options: {
            chart: { height: 240 },
            legend: { position: "bottom" }
          }
        }],
        noData: { text: "Sin datos", align: "center" }
      };

      const chart = new ApexCharts(chartEl, options);
      chart.render();
      this.chartInstances.push(chart);
    });
  }
}