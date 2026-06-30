import { Controller } from "@hotwired/stimulus"

// Bottom sheet (mobile) / center dialog (desktop) for play record entry
export default class extends Controller {
  static targets = ["backdrop", "panel", "dateInput", "dateLabel"]

  connect() {
    this._onKeydown = this._handleKeydown.bind(this)
    this._isOpen = false
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    document.body.style.overflow = ""
  }

  // Called from calendar:dateSelected event
  openWithDate(event) {
    const date = event.detail?.date
    if (date) this._setDate(date)
    this.open()
  }

  // FAB button — open for today
  openForToday() {
    const today = new Date()
    const yyyy = today.getFullYear()
    const mm = String(today.getMonth() + 1).padStart(2, "0")
    const dd = String(today.getDate()).padStart(2, "0")
    this._setDate(`${yyyy}-${mm}-${dd}`)
    this.open()
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

    // Show elements (style.display で制御)
    backdrop.style.display = "block"
    panel.style.display = "flex"

    // Set initial state
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

    // Lock body scroll
    document.body.style.overflow = "hidden"
    document.addEventListener("keydown", this._onKeydown)

    // Animate in
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        backdrop.style.opacity = "1"
        if (desktop) {
          panel.style.transform = "translate(-50%, -50%) scale(1)"
          panel.style.opacity = "1"
        } else {
          panel.style.transform = "translateY(0)"
        }
        // a11y: パネル本体にフォーカスを移し、SR がダイアログタイトルから読む
        panel.focus({ preventScroll: true })
      })
    })
  }

  close() {
    if (!this._isOpen) return
    this._isOpen = false

    const panel = this.panelTarget
    const backdrop = this.backdropTarget
    const desktop = this._isDesktop()

    // Animate out
    backdrop.style.opacity = "0"
    if (desktop) {
      panel.style.transform = "translate(-50%, -50%) scale(0.95)"
      panel.style.opacity = "0"
    } else {
      panel.style.transform = "translateY(100%)"
    }

    setTimeout(() => {
      // Hide elements (style.display で制御)
      backdrop.style.display = "none"
      panel.style.display = "none"
      // Clean up inline styles
      panel.style.transform = ""
      panel.style.opacity = ""
      panel.style.transition = ""
      backdrop.style.transform = ""
      backdrop.style.opacity = ""
      backdrop.style.transition = ""
      document.body.style.overflow = ""
      document.removeEventListener("keydown", this._onKeydown)
      // a11y: フォーカスを開く前の要素に戻す
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

  // Private

  _handleKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  _setDate(dateStr) {
    if (this.hasDateInputTarget) {
      this.dateInputTarget.value = dateStr
    }
    if (this.hasDateLabelTarget) {
      this.dateLabelTarget.textContent = this._formatDate(dateStr)
    }
  }

  _formatDate(dateStr) {
    const d = new Date(dateStr + "T00:00:00")
    const days = ["日", "月", "火", "水", "木", "金", "土"]
    return `${d.getMonth() + 1}/${d.getDate()}(${days[d.getDay()]})`
  }

  _isDesktop() {
    return window.matchMedia("(min-width: 640px)").matches
  }
}
