import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entriesContainer", "template", "entry", "formError"]

  addEntry() {
    const template = this.templateTarget
    const clone = template.content.cloneNode(true)
    const newIndex = this.entryTargets.length

    // Update name attributes: replace __INDEX__ with correct index
    clone.querySelectorAll("[data-index-placeholder]").forEach(el => {
      const name = el.getAttribute("name")
      if (name) {
        el.setAttribute("name", name.replace("__INDEX__", newIndex))
      }
      el.removeAttribute("data-index-placeholder")
    })

    // id 属性にも __INDEX__ が残るため置換し、複製時のid重複を防ぐ
    clone.querySelectorAll("[id*='__INDEX__']").forEach(el => {
      el.setAttribute("id", el.getAttribute("id").replace("__INDEX__", newIndex))
    })

    this.entriesContainerTarget.appendChild(clone)

    // Send current machine list to the newly added entry's autocomplete
    // The machine-options controller stores machines; re-broadcast after DOM insertion
    requestAnimationFrame(() => {
      const machineOptions = this.element.closest("[data-controller~='machine-options']")
        || this.element.querySelector("[data-controller~='machine-options']")
      // Find the controller instance via the element's __stimulus property
      // Simpler: just re-dispatch the event on window with cached data
      if (window._cachedMachineList) {
        window.dispatchEvent(new CustomEvent("machine-options:machinesLoaded", {
          detail: { machines: window._cachedMachineList }
        }))
      }
    })
  }

  // 送信前ガード1: 店舗が未選択(shop_idのhidden inputが空)だと belongs_to :shop の
  // 必須バリデーションでサーバ側が弾く。hidden inputは required 属性が効かない
  // (HTML5仕様上ブラウザネイティブ検証の対象外)ため、ここで明示的にチェックする。
  //
  // 送信前ガード2: 同じ機種を複数の行に選んでいると、サーバ側の一意制約
  // (voter_token + shop_id + machine_model_id + played_on) に違反する。
  // サーバ側(create_multiple)でも弾いているが(こちらが主要ガード)、
  // ここで先に検出してユーザーに即フィードバックする。
  validateSubmit(event) {
    const shopIdInput = this.element.querySelector('[data-shop-autocomplete-target="hidden"]')
    if (!shopIdInput || !shopIdInput.value) {
      event.preventDefault()
      this.showError("店舗を検索して選択してください。")
      return
    }

    const ids = this.entryTargets
      .map(entry => entry.querySelector("[data-entry-field='machine_model_id']"))
      .filter(input => input && input.value)
      .map(input => input.value)

    const hasDuplicate = new Set(ids).size !== ids.length
    if (hasDuplicate) {
      event.preventDefault()
      this.showError("同じ機種が重複しています。1機種につき1件で記録してください。")
      return
    }

    this.hideError()
  }

  // フォーム内インラインエラー表示。target未定義の環境向けに alert へフォールバック
  showError(message) {
    if (this.hasFormErrorTarget) {
      this.formErrorTarget.textContent = message
      this.formErrorTarget.classList.remove("hidden")
    } else {
      window.alert(message)
    }
  }

  hideError() {
    if (this.hasFormErrorTarget) {
      this.formErrorTarget.classList.add("hidden")
    }
  }

  removeEntry(event) {
    const entry = event.currentTarget.closest("[data-play-record-form-target='entry']")
    if (!entry) return

    // Keep at least one entry
    if (this.entryTargets.length <= 1) return

    entry.remove()
    this._reindex()
  }

  // 配列として送る必要があるフィールド (チェックボックス複数選択)
  static arrayFields = ["confirmed_setting", "tags"]

  // Re-number name indices after removal
  _reindex() {
    this.entryTargets.forEach((entry, index) => {
      entry.querySelectorAll("[data-entry-field]").forEach(el => {
        const field = el.dataset.entryField
        // confirmed_setting / tags は entries[N][field][] 形式 (配列)
        const suffix = this.constructor.arrayFields.includes(field) ? "[]" : ""
        el.setAttribute("name", `entries[${index}][${field}]${suffix}`)
      })
    })
  }
}
