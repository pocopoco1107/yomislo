import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "list"]

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
      this.#filterCityGroups(cityGroups, query)
      return
    }

    // Flat shop cards (without city groups)
    const shopCards = list.querySelectorAll("[data-filter-name]")
    if (shopCards.length > 0) {
      this.#filterShopCards(shopCards, query)
      return
    }
  }

  #filterMachineRows(list, rows, query) {
    rows.forEach(el => {
      const name = this.#normalize(el.dataset.filterName)
      el.classList.toggle("hidden", query !== "" && !name.includes(query))
    })

    // Hide a type header when its following grid has no visible rows
    const headers = list.querySelectorAll("[data-type-header]")
    headers.forEach(header => {
      const grid = header.nextElementSibling
      const hasVisible = grid && grid.querySelector("turbo-frame[id^='machine_vote_']:not(.hidden)")
      header.classList.toggle("hidden", query !== "" && !hasVisible)
    })
  }

  #filterCityGroups(groups, query) {
    groups.forEach(group => {
      const cards = group.querySelectorAll("[data-filter-name]")
      let anyVisible = false

      if (query === "") {
        cards.forEach(el => el.classList.remove("hidden"))
        group.classList.remove("hidden")
        return
      }

      cards.forEach(el => {
        const name = this.#normalize(el.dataset.filterName)
        const visible = name.includes(query)
        el.classList.toggle("hidden", !visible)
        if (visible) anyVisible = true
      })

      // Hide entire city group if no matching shops
      group.classList.toggle("hidden", !anyVisible)

      // Auto-expand group if it has matching results
      if (anyVisible) {
        const content = group.querySelector("[data-accordion-target='content']")
        if (content) content.classList.remove("hidden")
      }
    })
  }

  #filterShopCards(cards, query) {
    if (query === "") {
      cards.forEach(el => el.classList.remove("hidden"))
      return
    }

    cards.forEach(el => {
      const name = this.#normalize(el.dataset.filterName)
      el.classList.toggle("hidden", !name.includes(query))
    })
  }
}
