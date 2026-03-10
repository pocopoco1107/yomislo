import { Controller } from "@hotwired/stimulus"

// モバイルナビゲーション ドロワーコントローラ
// ハンバーガーメニューで右からスライドイン
export default class extends Controller {
  static targets = ["drawer", "overlay"]

  connect() {
    this.isOpen = false
    // ESCキーで閉じる
    this.handleKeydown = (e) => {
      if (e.key === "Escape" && this.isOpen) this.close()
    }
    document.addEventListener("keydown", this.handleKeydown)

    // Turboキャッシュ前にドロワーを閉じる（バック時にスクロールロックが残るのを防止）
    this.handleBeforeCache = () => {
      if (this.isOpen) this.close()
    }
    document.addEventListener("turbo:before-cache", this.handleBeforeCache)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("turbo:before-cache", this.handleBeforeCache)
    this.unlockScroll()
  }

  toggle() {
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.isOpen = true
    this.overlayTarget.classList.remove("opacity-0", "pointer-events-none")
    this.overlayTarget.classList.add("opacity-100")
    this.drawerTarget.classList.remove("translate-x-full")
    this.drawerTarget.classList.add("translate-x-0")
    this.lockScroll()
  }

  close() {
    this.isOpen = false
    this.overlayTarget.classList.add("opacity-0", "pointer-events-none")
    this.overlayTarget.classList.remove("opacity-100")
    this.drawerTarget.classList.add("translate-x-full")
    this.drawerTarget.classList.remove("translate-x-0")
    this.unlockScroll()
  }

  lockScroll() {
    document.body.style.overflow = "hidden"
  }

  unlockScroll() {
    document.body.style.overflow = ""
  }
}
