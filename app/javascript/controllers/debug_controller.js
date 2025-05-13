import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  connect() {
    console.log("[Debug Controller] Connected successfully to element:", this.element);
  }
}
