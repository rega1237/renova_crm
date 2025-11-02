import { Controller } from "@hotwired/stimulus"

// Stimulus controller para implementar scroll infinito.
// Uso:
// <tbody data-controller="infinite-scroll"
//        data-infinite-scroll-url-value="/settings/cities"
//        data-infinite-scroll-per-page-value="50"
//        data-infinite-scroll-target="list">
//   ... filas iniciales ...
// </tbody>
// <div data-infinite-scroll-target="sentinel"></div>
// <div data-infinite-scroll-target="loadingIndicator">Cargando...</div>

export default class extends Controller {
  static targets = ["list", "sentinel", "loadingIndicator"]
  static values = {
    url: String,
    page: { type: Number, default: 1 },
    perPage: { type: Number, default: 50 },
  }

  connect() {
    this.loading = false
    this.hasMore = true
    this._setupObserver()
    this._updateLoading(false)
  }

  disconnect() {
    this._cleanupObserver()
  }

  _setupObserver() {
    if (!this.hasSentinelTarget) return
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          this._loadNextPage()
        }
      })
    }, { rootMargin: "200px" })
    this.observer.observe(this.sentinelTarget)
  }

  _cleanupObserver() {
    if (this.observer && this.hasSentinelTarget) {
      this.observer.unobserve(this.sentinelTarget)
      this.observer.disconnect()
      this.observer = null
    }
  }

  async _loadNextPage() {
    if (this.loading || !this.hasMore) return
    this.loading = true
    this._updateLoading(true)

    try {
      const nextPage = this.pageValue + 1
      const url = this._buildUrl(nextPage)
      const response = await fetch(url, { headers: { "Accept": "text/html" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const html = (await response.text()).trim()

      if (html.length === 0) {
        this.hasMore = false
        this._updateLoading(false)
        return
      }

      // Insertar nuevas filas al final del tbody usando el contexto correcto de tabla
      // createContextualFragment con document puede no parsear correctamente <tr> fuera de una tabla
      this.listTarget.insertAdjacentHTML("beforeend", html)
      this.pageValue = nextPage
    } catch (e) {
      console.error("InfiniteScroll error:", e)
      this.hasMore = false
    } finally {
      this.loading = false
      this._updateLoading(false)
    }
  }

  _buildUrl(page) {
    const base = this.urlValue || window.location.pathname + window.location.search
    const hasQuery = base.includes("?")
    const sep = hasQuery ? "&" : "?"
    const per = this.perPageValue || 50
    return `${base}${sep}page=${page}&per_page=${per}&only_rows=1`
  }

  _updateLoading(show) {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.toggle("hidden", !show)
    }
  }
}