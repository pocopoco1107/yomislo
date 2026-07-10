import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]

  connect() {
    this.reEnableTimer = null
    this.element.addEventListener("turbo:submit-end", this.trackSubmit)
  }

  disconnect() {
    if (this.reEnableTimer) {
      clearTimeout(this.reEnableTimer)
      this.reEnableTimer = null
    }
    this.element.removeEventListener("turbo:submit-end", this.trackSubmit)
  }

  trackSubmit = (event) => {
    if (event.detail.success && typeof gtag === "function") {
      gtag("event", "vote_submit")
    }
  }

  submit(event) {
    const button = event.currentTarget

    // Defer disabling to next microtask so the form submission is not blocked
    requestAnimationFrame(() => {
      this.buttonTargets.forEach(btn => {
        btn.disabled = true
        btn.classList.add("opacity-50", "pointer-events-none")
      })
      button.classList.add("animate-pulse")
    })

    // Re-enable after a brief delay in case turbo stream doesn't replace
    if (this.reEnableTimer) clearTimeout(this.reEnableTimer)
    this.reEnableTimer = setTimeout(() => {
      this.reEnableTimer = null
      if (!this.element.isConnected) return
      this.buttonTargets.forEach(btn => {
        btn.disabled = false
        btn.classList.remove("opacity-50", "pointer-events-none")
      })
      button.classList.remove("animate-pulse")
    }, 3000)
  }
}
