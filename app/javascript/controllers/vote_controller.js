import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "form"]

  submit(event) {
    const button = event.currentTarget
    const originalText = button.textContent

    // Disable all buttons in this controller to prevent double-clicks
    this.buttonTargets.forEach(btn => {
      btn.disabled = true
      btn.classList.add("opacity-50", "pointer-events-none")
    })

    // Add loading indicator to clicked button
    button.textContent = "..."

    // Re-enable after a brief delay in case turbo stream doesn't replace
    setTimeout(() => {
      this.buttonTargets.forEach(btn => {
        btn.disabled = false
        btn.classList.remove("opacity-50", "pointer-events-none")
      })
      button.textContent = originalText
    }, 3000)
  }
}
