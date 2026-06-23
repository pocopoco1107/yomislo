import { Controller } from "@hotwired/stimulus"

// 相棒ペット: クリックで1回跳ねる。進化直後は自動で1回跳ねてお祝い。
// prefers-reduced-motion 指定時はアニメーションを行わない。
export default class extends Controller {
  static targets = ["sprite"]
  static values = { evolved: Boolean }

  connect() {
    if (this.evolvedValue) this.hop()
  }

  hop() {
    if (this.prefersReducedMotion) return

    const el = this.hasSpriteTarget ? this.spriteTarget : this.element
    el.classList.remove("pet--idle")
    // 既に跳ねている場合はリセットして打ち直す
    el.classList.remove("pet--hop-once")
    void el.offsetWidth // reflow でアニメーションを再起動
    el.classList.add("pet--hop-once")

    const onEnd = () => {
      el.classList.remove("pet--hop-once")
      el.classList.add("pet--idle")
      el.removeEventListener("animationend", onEnd)
    }
    el.addEventListener("animationend", onEnd)
  }

  get prefersReducedMotion() {
    return window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
