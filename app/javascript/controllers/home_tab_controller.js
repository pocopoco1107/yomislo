import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabA", "tabB", "zoneA", "zoneB"]

  connect() {
    this.active = localStorage.getItem("home_active_tab") || "a"
    this.apply()
  }

  switchA() {
    this.active = "a"
    localStorage.setItem("home_active_tab", "a")
    this.apply()
  }

  switchB() {
    this.active = "b"
    localStorage.setItem("home_active_tab", "b")
    this.apply()
  }

  apply() {
    const isA = this.active === "a"

    this.zoneATarget.classList.toggle("zone-hidden", !isA)
    this.zoneBTarget.classList.toggle("zone-hidden", isA)

    this.tabATarget.classList.toggle("bg-primary", isA)
    this.tabATarget.classList.toggle("text-primary-foreground", isA)
    this.tabATarget.classList.toggle("text-muted-foreground", !isA)

    this.tabBTarget.classList.toggle("bg-primary", !isA)
    this.tabBTarget.classList.toggle("text-primary-foreground", !isA)
    this.tabBTarget.classList.toggle("text-muted-foreground", isA)
  }
}
