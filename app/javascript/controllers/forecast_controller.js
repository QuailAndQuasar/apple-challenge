import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "results", "loading", "submitButton", "title"]

  connect() {
    // console.log("Forecast controller connected")
  }

  async search(event) {
    event.preventDefault()
    this.titleTarget.textContent = "Weather Forecast - Button Clicked"
    const location = this.inputTarget.value.trim()

    if (!location) {
      this.showError("Please enter an address")
      return
    }

    this.showLoading()

    try {
      const response = await fetch('/api/v1/forecasts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ address: location })
      })
      const data = await response.json()

      if (response.ok) {
        this.renderForecast(data)
      } else {
        this.showError(data.error || "Failed to fetch forecast")
      }
    } catch (error) {
      this.showError("Network error. Please try again.")
      console.error("Forecast error:", error)
    } finally {
      this.hideLoading()
    }
  }

  showLoading() {
    this.loadingTarget.classList.remove("hidden")
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    this.resultsTarget.innerHTML = ""
  }

  hideLoading() {
    this.loadingTarget.classList.add("hidden")
    this.submitButtonTarget.disabled = false
    this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
  }

  showError(message) {
    this.resultsTarget.innerHTML = `
      <div class="bg-red-50 border-l-4 border-red-500 p-4 mb-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
            </svg>
          </div>
          <div class="ml-3">
            <p class="text-sm text-red-700">${message}</p>
          </div>
        </div>
      </div>
    `
  }

  renderForecast(data) {
    const html = `
      <div class="bg-white shadow rounded-lg p-6 transition-all duration-300 ease-in-out transform hover:scale-[1.02]">
        <h2 class="text-2xl font-bold mb-4 text-gray-800">${data.address}</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <p class="text-gray-600">Current Conditions</p>
            <p class="text-xl mt-2 text-gray-800">${data.forecast.current.conditions}</p>
          </div>
          <div class="text-right">
            <p class="text-3xl font-bold text-gray-800">${data.forecast.current.temp_f}°F</p>
            <p class="text-gray-600">High: ${data.forecast.forecast[0].high_f}°F | Low: ${data.forecast.forecast[0].low_f}°F</p>
          </div>
        </div>
      </div>
    `
    this.resultsTarget.innerHTML = html
  }
} 