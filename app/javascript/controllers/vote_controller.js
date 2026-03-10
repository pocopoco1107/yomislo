import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]

  connect() {
    this.reEnableTimer = null
  }

  disconnect() {
    if (this.reEnableTimer) {
      clearTimeout(this.reEnableTimer)
      this.reEnableTimer = null
    }
  }

  submit(event) {
    const button = event.currentTarget

    // Disable all buttons in this controller to prevent double-clicks
    this.buttonTargets.forEach(btn => {
      btn.disabled = true
      btn.classList.add("opacity-50", "pointer-events-none")
    })

    // Add pulse animation to clicked button
    button.classList.add("animate-pulse")

    // Re-enable after a brief delay in case turbo stream doesn't replace
    if (this.reEnableTimer) clearTimeout(this.reEnableTimer)
    this.reEnableTimer = setTimeout(() => {
      this.reEnableTimer = null
      // Guard: element may have been removed from DOM
      if (!this.element.isConnected) return
      this.buttonTargets.forEach(btn => {
        btn.disabled = false
        btn.classList.remove("opacity-50", "pointer-events-none")
      })
      button.classList.remove("animate-pulse")
    }, 3000)
  }
}
