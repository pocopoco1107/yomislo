import { Controller } from "@hotwired/stimulus"

// Horizontal carousel with snap-scroll, swipe support, and navigation
export default class extends Controller {
  static targets = ["track", "prevBtn", "nextBtn", "dots"]

  connect() {
    this.track = this.trackTarget
    this.updateButtons()

    // Bind handlers once so they can be removed in disconnect
    this._onScroll = this.onScroll.bind(this)
    this._onTouchStart = this.onTouchStart.bind(this)
    this._onTouchEnd = this.onTouchEnd.bind(this)

    this.track.addEventListener("scroll", this._onScroll, { passive: true })

    // Touch swipe support (for non-snap browsers)
    this.startX = 0
    this.track.addEventListener("touchstart", this._onTouchStart, { passive: true })
    this.track.addEventListener("touchend", this._onTouchEnd, { passive: true })

    // Build dots
    this.buildDots()

    // Observe resize for button visibility
    this.resizeObserver = new ResizeObserver(() => this.updateButtons())
    this.resizeObserver.observe(this.track)
  }

  disconnect() {
    if (this.track) {
      this.track.removeEventListener("scroll", this._onScroll)
      this.track.removeEventListener("touchstart", this._onTouchStart)
      this.track.removeEventListener("touchend", this._onTouchEnd)
    }
    this.resizeObserver?.disconnect()
  }

  prev() {
    const cardWidth = this.cardWidth()
    this.track.scrollBy({ left: -cardWidth, behavior: "smooth" })
  }

  next() {
    const cardWidth = this.cardWidth()
    this.track.scrollBy({ left: cardWidth, behavior: "smooth" })
  }

  onScroll() {
    this.updateButtons()
    this.updateDots()
  }

  onTouchStart(e) {
    this.startX = e.touches[0].clientX
  }

  onTouchEnd(e) {
    const diff = this.startX - e.changedTouches[0].clientX
    if (Math.abs(diff) > 50) {
      diff > 0 ? this.next() : this.prev()
    }
  }

  cardWidth() {
    const firstCard = this.track.querySelector("[data-carousel-card]")
    if (!firstCard) return 260
    const style = getComputedStyle(this.track)
    const gap = parseFloat(style.gap) || 16
    return firstCard.offsetWidth + gap
  }

  updateButtons() {
    if (!this.hasPrevBtnTarget || !this.hasNextBtnTarget) return
    const { scrollLeft, scrollWidth, clientWidth } = this.track
    this.prevBtnTarget.classList.toggle("invisible", scrollLeft <= 4)
    this.nextBtnTarget.classList.toggle("invisible", scrollLeft + clientWidth >= scrollWidth - 4)
  }

  buildDots() {
    if (!this.hasDotsTarget) return
    const cards = this.track.querySelectorAll("[data-carousel-card]")
    if (cards.length <= 1) return

    // Calculate how many "pages"
    const visibleWidth = this.track.clientWidth
    const totalWidth = this.track.scrollWidth
    const pages = Math.max(1, Math.ceil(totalWidth / visibleWidth))

    this.dotsTarget.innerHTML = ""
    for (let i = 0; i < pages; i++) {
      const dot = document.createElement("button")
      dot.type = "button"
      dot.className = "w-1.5 h-1.5 rounded-full bg-current opacity-30 transition-opacity duration-200"
      dot.dataset.page = i
      dot.addEventListener("click", () => {
        this.track.scrollTo({ left: visibleWidth * i, behavior: "smooth" })
      })
      this.dotsTarget.appendChild(dot)
    }
    this.updateDots()
  }

  updateDots() {
    if (!this.hasDotsTarget) return
    const dots = this.dotsTarget.querySelectorAll("button")
    if (dots.length === 0) return

    const visibleWidth = this.track.clientWidth
    const currentPage = Math.round(this.track.scrollLeft / visibleWidth)
    dots.forEach((dot, i) => {
      dot.classList.toggle("opacity-100", i === currentPage)
      dot.classList.toggle("opacity-30", i !== currentPage)
    })
  }
}
