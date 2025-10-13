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
    "kpiCitaAgendada",
    "kpiTotal"
  ];

  connect() {
    this.chartInstance = null;
    this.setupMonthSubfilters();
    this.fetchAndRender();
  }

  disconnect() {
    if (this.chartInstance) {
      this.chartInstance.destroy();
      this.chartInstance = null;
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
    const statusKey = this.hasStatusTarget ? this.statusTarget.value : null;
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
      this.renderChart(data);
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
      "Citas agendadas": "kpiCitaAgendada"
    };

    const setText = (targetName, value) => {
      const hasProp = this[`has${targetName.charAt(0).toUpperCase() + targetName.slice(1)}Target`];
      const el = this[`${targetName}Target`];
      if (hasProp && el) el.textContent = value;
    };

    let grandTotal = 0;
    Object.entries(nameMap).forEach(([human, target]) => {
      const val = Number(totals[human] || 0);
      grandTotal += val;
      setText(target, val);
    });
    setText("kpiTotal", grandTotal);
  }

  renderChart(data) {
    const categories = data.categories || [];
    const series = data.series || [];

    const options = {
      chart: { type: "bar", height: 320, toolbar: { show: false }, animations: { enabled: true } },
      theme: { mode: "light" },
      colors: [
        "#ef4444", "#f59e0b", "#10b981", "#3b82f6", "#9333ea",
        "#14b8a6", "#f97316", "#22c55e", "#06b6d4", "#a855f7",
        "#64748b", "#84cc16", "#e11d48", "#0ea5e9", "#8b5cf6"
      ],
      plotOptions: { bar: { horizontal: false, borderRadius: 6, columnWidth: "45%" } },
      dataLabels: { enabled: false },
      stroke: { show: true, width: 2, colors: ["transparent"] },
      xaxis: { categories, labels: { style: { colors: "#111827", fontFamily: "Montserrat" } } },
      yaxis: { labels: { style: { colors: "#111827", fontFamily: "Montserrat" } } },
      legend: { position: "top", fontFamily: "Poppins" },
      grid: { strokeDashArray: 4 },
      series,
      noData: { text: "Sin datos", align: "center" }
    };

    if (this.chartInstance) {
      this.chartInstance.updateOptions(options);
      this.chartInstance.updateSeries(series);
    } else {
      this.chartInstance = new ApexCharts(this.chartTarget, options);
      this.chartInstance.render();
    }
  }
}