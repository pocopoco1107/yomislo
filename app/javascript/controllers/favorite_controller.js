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
    const button = this.element.querySelector("button")
    const iconEmpty = this.element.querySelector("[data-favorite-icon-empty]")
    const iconFilled = this.element.querySelector("[data-favorite-icon-filled]")
    // Legacy text-based UI (used outside shop detail)
    const star = this.element.querySelector("[data-favorite-star]")
    const label = this.element.querySelector("[data-favorite-label]")

    if (iconEmpty && iconFilled) {
      iconEmpty.classList.toggle("hidden", isFavorite)
      iconFilled.classList.toggle("hidden", !isFavorite)
    }
    if (button) {
      button.setAttribute("aria-pressed", isFavorite ? "true" : "false")
      button.setAttribute("aria-label", isFavorite ? "お気に入りから外す" : "お気に入りに追加")
      button.classList.toggle("border-yellow-500/60", isFavorite)
      button.classList.toggle("bg-yellow-500/10", isFavorite)
    }
    if (star) {
      star.textContent = isFavorite ? "★" : "☆"
      star.classList.toggle("text-yellow-500", isFavorite)
      star.classList.toggle("text-muted-foreground", !isFavorite)
    }
    if (label) {
      // アイコン下のラベル(text-[9px])と従来のラベル両方に対応
      label.textContent = isFavorite ? "登録済み" : "お気に入り"
      label.classList.toggle("text-yellow-600", isFavorite)
      label.classList.toggle("text-muted-foreground", !isFavorite)
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
