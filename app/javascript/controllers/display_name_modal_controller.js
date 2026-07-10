import { Controller } from "@hotwired/stimulus"

// Bottom sheet (mobile) / center dialog (desktop) for editing display name
export default class extends Controller {
  static targets = ["backdrop", "panel", "input"]

  connect() {
    this._onKeydown = this._handleKeydown.bind(this)
    this._isOpen = false
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
  }

  open() {
    if (this._isOpen) return
    this._isOpen = true

    // a11y: モーダル開閉時のフォーカス管理。直前のフォーカス要素を覚えておき、
    // close 時に戻す。完全な focus trap は重いので最小限。
    this._previouslyFocused = document.activeElement

    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    const desktop = this._isDesktop()

    backdrop.style.display = "block"
    panel.style.display = "flex"

    backdrop.style.transition = "opacity 300ms ease"
    backdrop.style.opacity = "0"

    panel.style.transition = "transform 300ms ease, opacity 300ms ease"
    if (desktop) {
      panel.style.transform = "translate(-50%, -50%) scale(0.95)"
      panel.style.opacity = "0"
    } else {
      panel.style.transform = "translateY(100%)"
      panel.style.opacity = "1"
    }

    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this._onKeydown)

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        backdrop.style.opacity = "1"
        if (desktop) {
          panel.style.transform = "translate(-50%, -50%) scale(1)"
          panel.style.opacity = "1"
        } else {
          panel.style.transform = "translateY(0)"
        }
        if (this.hasInputTarget) {
          this.inputTarget.focus({ preventScroll: true })
        } else {
          panel.focus({ preventScroll: true })
        }
      })
    })
  }

  close() {
    if (!this._isOpen) return
    this._isOpen = false

    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    const desktop = this._isDesktop()

    backdrop.style.opacity = "0"
    if (desktop) {
      panel.style.transform = "translate(-50%, -50%) scale(0.95)"
      panel.style.opacity = "0"
    } else {
      panel.style.transform = "translateY(100%)"
    }

    setTimeout(() => {
      backdrop.style.display = "none"
      panel.style.display = "none"
      panel.style.transform = ""
      panel.style.opacity = ""
      panel.style.transition = ""
      backdrop.style.transform = ""
      backdrop.style.opacity = ""
      backdrop.style.transition = ""
      document.body.style.overflow = ""
      document.removeEventListener("keydown", this._onKeydown)
      if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
        this._previouslyFocused.focus({ preventScroll: true })
      }
      this._previouslyFocused = null
    }, 300)
  }

  backdropClose(event) {
    if (event.target === this.backdropTarget) {
      this.close()
    }
  }

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _isDesktop() {
    return window.matchMedia("(min-width: 640px)").matches
  }
}
