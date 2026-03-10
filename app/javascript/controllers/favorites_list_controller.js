import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]

  connect() {
    this.abortController = null
    const favorites = this.getFavorites()
    if (favorites.length === 0) {
      this.containerTarget.classList.add("hidden")
      return
    }

    // Load favorite shops via fetch
    this.containerTarget.classList.remove("hidden")
    this.abortController = new AbortController()
    const slugs = favorites.join(",")
    fetch(`/shops/favorites?slugs=${encodeURIComponent(slugs)}`, {
      headers: { "Accept": "text/html" },
      signal: this.abortController.signal
    })
      .then(r => r.text())
      .then(html => {
        if (!this.element.isConnected) return
        const list = this.containerTarget.querySelector("[data-favorites-list]")
        if (list && html.trim()) {
          list.innerHTML = html
        }
      })
      .catch((e) => {
        if (e.name !== "AbortError") console.error(e)
      })
  }

  disconnect() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }
}
