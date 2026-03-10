import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { shopSlug: String }

  connect() {
    this.updateUI()
  }

  toggle() {
    const favorites = this.getFavorites()
    const slug = this.shopSlugValue

    if (favorites.includes(slug)) {
      this.setFavorites(favorites.filter(s => s !== slug))
    } else {
      this.setFavorites([...favorites, slug])
    }
    this.updateUI()
  }

  updateUI() {
    const isFavorite = this.getFavorites().includes(this.shopSlugValue)
    const star = this.element.querySelector("[data-favorite-star]")
    if (star) {
      star.textContent = isFavorite ? "★" : "☆"
      star.classList.toggle("text-yellow-500", isFavorite)
      star.classList.toggle("text-gray-400", !isFavorite)
    }
  }

  getFavorites() {
    try {
      return JSON.parse(localStorage.getItem("favorite_shops") || "[]")
    } catch {
      return []
    }
  }

  setFavorites(favorites) {
    try {
      localStorage.setItem("favorite_shops", JSON.stringify(favorites))
    } catch {
      // localStorage quota exceeded or access denied (e.g. private browsing)
    }
  }
}
