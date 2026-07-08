import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list", "empty", "count"]

  connect() {
    // Cache the non-numeric part of the initial count text (e.g. "12 店舗" → " 店舗")
    // so filtered updates can reuse the same unit label without hardcoding it here.
    if (this.hasCountTarget) {
      const match = this.countTarget.textContent.match(/^([\d,]+)(.*)$/)
      this.countSuffix = match ? match[2] : ""
    }
  }

  // 旧字体カナ（ヱ/ヲ/ヰ）を新字体に寄せて比較する。
  // 例: 機種正式名「ヱヴァンゲリヲン」を、ユーザー入力「エヴァ」でヒットさせる。
  #normalize(str) {
    return (str || "")
      .normalize("NFKC")
      .toLowerCase()
      .replace(/ヱ/g, "エ")
      .replace(/ヲ/g, "オ")
      .replace(/ヰ/g, "イ")
  }

  filter() {
    const query = this.#normalize(this.inputTarget.value.trim())
    const list = this.listTarget

    // Machine vote rows (shop page) — check first since rows are turbo-frames
    const rows = list.querySelectorAll("turbo-frame[id^='machine_vote_']")
    if (rows.length > 0) {
      this.#filterMachineRows(list, rows, query)
      return
    }

    // City-grouped shop cards (prefecture page)
    const cityGroups = list.querySelectorAll("[data-city-group]")
    if (cityGroups.length > 0) {
      this.#filterCityGroups(list, cityGroups, query)
      return
    }

    // Flat shop cards (without city groups)
    const shopCards = list.querySelectorAll("[data-filter-name]")
    if (shopCards.length > 0) {
      this.#filterShopCards(list, shopCards, query)
      return
    }
  }

  #filterMachineRows(list, rows, query) {
    let visibleCount = 0

    rows.forEach(el => {
      const name = this.#normalize(el.dataset.filterName)
      const visible = query === "" || name.includes(query)
      el.classList.toggle("hidden", !visible)
      if (visible) visibleCount++
    })

    // Hide a type header when its following grid has no visible rows
    const headers = list.querySelectorAll("[data-type-header]")
    headers.forEach(header => {
      const grid = header.nextElementSibling
      const hasVisible = grid && grid.querySelector("turbo-frame[id^='machine_vote_']:not(.hidden)")
      header.classList.toggle("hidden", query !== "" && !hasVisible)
    })

    this.#updateCount(list, query, visibleCount)
    this.#updateEmpty(query, visibleCount)
  }

  #filterCityGroups(list, groups, query) {
    let totalVisible = 0

    groups.forEach(group => {
      const cards = group.querySelectorAll("[data-filter-name]")

      if (query === "") {
        cards.forEach(el => el.classList.remove("hidden"))
        group.classList.remove("hidden")
        totalVisible += cards.length
        return
      }

      let groupVisible = 0
      cards.forEach(el => {
        const name = this.#normalize(el.dataset.filterName)
        const visible = name.includes(query)
        el.classList.toggle("hidden", !visible)
        if (visible) groupVisible++
      })

      // Hide entire city group if no matching shops
      group.classList.toggle("hidden", groupVisible === 0)
      totalVisible += groupVisible

      // Auto-expand group if it has matching results
      if (groupVisible > 0) {
        const content = group.querySelector("[data-accordion-target='content']")
        if (content) content.classList.remove("hidden")
      }
    })

    this.#updateCount(list, query, totalVisible)
    this.#updateEmpty(query, totalVisible)
  }

  #filterShopCards(list, cards, query) {
    let visibleCount = 0

    if (query === "") {
      cards.forEach(el => el.classList.remove("hidden"))
      visibleCount = cards.length
    } else {
      cards.forEach(el => {
        const name = this.#normalize(el.dataset.filterName)
        const visible = name.includes(query)
        el.classList.toggle("hidden", !visible)
        if (visible) visibleCount++
      })
    }

    this.#updateCount(list, query, visibleCount)
    this.#updateEmpty(query, visibleCount)
  }

  // クエリが空ならlist要素のdata-machine-filter-total-valueから元の総数に戻し、
  // それ以外は実際に見えている件数を表示する。総数が取得できない場合は何もしない。
  #updateCount(list, query, visibleCount) {
    if (!this.hasCountTarget) return

    const total = list.dataset.machineFilterTotalValue
    const value = query === "" ? total : visibleCount
    if (value === undefined) return

    this.countTarget.textContent = `${value}${this.countSuffix ?? ""}`
  }

  #updateEmpty(query, visibleCount) {
    if (!this.hasEmptyTarget) return
    this.emptyTarget.classList.toggle("hidden", !(query !== "" && visibleCount === 0))
  }
}
