import { Controller } from "@hotwired/stimulus"

// 閉じた <details> の中身の取得を、開いた瞬間まで遅らせる。
// turbo-frame の loading="lazy" は閉じた details 内でも交差判定が走る余地があり、
// 設置機種数ぶんのリクエストが一斉に飛びうるため使わない。data-src を src へ移す方式なら
// 「開くまで絶対にフェッチしない」が保証できる。
export default class extends Controller {
  static targets = ["frame"]

  load() {
    if (!this.element.open) return

    this.frameTargets.forEach((frame) => {
      const src = frame.dataset.src
      // src が入っていれば取得済みか進行中。二重フェッチを避ける
      if (src && !frame.getAttribute("src")) frame.setAttribute("src", src)
    })
  }
}
