import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit", "spinner", "cancel"]

  start() {
    this.submitTarget.classList.add("d-none")
    this.spinnerTarget.classList.remove("d-none")
    this.cancelTarget.classList.remove("d-none")
  }

  cancel() {
    window.history.back()
  }
}
