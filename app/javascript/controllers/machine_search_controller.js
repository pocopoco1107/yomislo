import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { shopId: Number, date: String }

  connect() {
    this.timeout = null
    this.abortController = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  search() {
    clearTimeout(this.timeout)
    const query = this.inputTarget.value.trim()

    if (query.length < 1) {
      this.resultsTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => {
      // Abort previous in-flight request
      if (this.abortController) this.abortController.abort()
      this.abortController = new AbortController()

      const url = `/machines/search?q=${encodeURIComponent(query)}&shop_id=${this.shopIdValue}&date=${this.dateValue}`
      fetch(url, {
        headers: { "Accept": "text/html" },
        signal: this.abortController.signal
      })
        .then(r => r.text())
        .then(html => {
          if (this.element.isConnected) {
            this.resultsTarget.innerHTML = html
          }
        })
        .catch((e) => {
          if (e.name !== "AbortError") console.error(e)
        })
    }, 200)
  }

  clear() {
    this.inputTarget.value = ""
    this.resultsTarget.innerHTML = ""
  }
}
