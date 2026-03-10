import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.isRemoving = false
    // 自動消去タイマー
    this.timer = setTimeout(() => this.fadeOut(), this.delayValue)
  }

  disconnect() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
    if (this.fadeTimer) {
      clearTimeout(this.fadeTimer)
      this.fadeTimer = null
    }
  }

  dismiss() {
    this.fadeOut()
  }

  fadeOut() {
    // 二重実行を防止
    if (this.isRemoving) return
    this.isRemoving = true

    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }

    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    this.fadeTimer = setTimeout(() => {
      // Guard: element may have been removed by Turbo navigation
      if (this.element.isConnected) {
        this.element.remove()
      }
    }, 300)
  }
}
