import { Controller } from "@hotwired/stimulus"

// テーマ切替コントローラ
// system (OS追従) → light → dark → system の3段階トグル。デフォルトは system。
export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    this.media = window.matchMedia ? window.matchMedia("(prefers-color-scheme: dark)") : null
    this.systemListener = () => { if (this.currentSetting === "system") this.applyTheme() }
    if (this.media) this.media.addEventListener("change", this.systemListener)
    this.applyTheme()
  }

  disconnect() {
    if (this.media) this.media.removeEventListener("change", this.systemListener)
  }

  toggle() {
    const order = ["system", "light", "dark"]
    const idx = order.indexOf(this.currentSetting)
    const next = order[(idx + 1) % order.length]
    try {
      if (next === "system") localStorage.removeItem("theme")
      else localStorage.setItem("theme", next)
    } catch {
      // localStorage access denied
    }
    this.applyTheme()
  }

  get currentSetting() {
    try {
      const v = localStorage.getItem("theme")
      return (v === "light" || v === "dark") ? v : "system"
    } catch {
      return "system"
    }
  }

  applyTheme() {
    const setting = this.currentSetting
    const isDark = setting === "dark" ||
      (setting === "system" && this.media && this.media.matches)
    document.documentElement.classList.toggle("dark", isDark)
    this.updateIcon(setting)
  }

  updateIcon(setting) {
    if (!this.hasIconTarget) return

    const icons = {
      system: `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>`,
      light: `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/></svg>`,
      dark: `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/></svg>`,
    }
    const labels = { system: "自動", light: "ライト", dark: "ダーク" }

    this.iconTarget.innerHTML = icons[setting] || icons.system
    this.element.querySelector("button")?.setAttribute("title", `テーマ: ${labels[setting]}`)
    if (this.hasLabelTarget) this.labelTarget.textContent = labels[setting]
  }
}
