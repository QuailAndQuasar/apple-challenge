import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  connect() {
    console.log("Test controller connected!")
  }

  test() {
    console.log("Test button clicked!")
    this.outputTarget.textContent = "JavaScript is working! Button clicked at: " + new Date().toLocaleTimeString()
    this.outputTarget.classList.remove("hidden")
  }
} 