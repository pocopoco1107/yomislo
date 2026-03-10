import { Controller } from "@hotwired/stimulus"

// テーマ切替コントローラ
// OS設定に従う (system) / ライト (light) / ダーク (dark) の3段階
export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    this.applyTheme()
    // OS設定の変化を監視
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.mediaQueryHandler = () => this.applyTheme()
    this.mediaQuery.addEventListener("change", this.mediaQueryHandler)
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener("change", this.mediaQueryHandler)
    }
  }

  toggle() {
    const current = this.currentSetting
    // system → dark → light → system のサイクル
    const next = current === "system" ? "dark" : current === "dark" ? "light" : "system"
    try {
      localStorage.setItem("theme", next)
    } catch {
      // localStorage access denied (e.g. private browsing)
    }
    this.applyTheme()
  }

  get currentSetting() {
    try {
      return localStorage.getItem("theme") || "dark"
    } catch {
      return "dark"
    }
  }

  applyTheme() {
    const setting = this.currentSetting
    const isDark = setting === "dark" ||
      (setting === "system" && window.matchMedia("(prefers-color-scheme: dark)").matches)

    document.documentElement.classList.toggle("dark", isDark)
    this.updateIcon(setting, isDark)
  }

  updateIcon(setting, isDark) {
    if (!this.hasIconTarget) return

    // SVGアイコンを切り替え
    if (setting === "system") {
      // システム設定アイコン (モニター)
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>`
    } else if (setting === "dark") {
      // 月アイコン
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"/>
        </svg>`
    } else {
      // 太陽アイコン
      this.iconTarget.innerHTML = `
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/>
        </svg>`
    }

    if (this.hasLabelTarget) {
      const labels = { system: "自動", dark: "ダーク", light: "ライト" }
      this.labelTarget.textContent = labels[setting]
    }
  }
}
