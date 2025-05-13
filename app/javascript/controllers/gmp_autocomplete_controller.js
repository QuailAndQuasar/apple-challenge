import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["autocompleteInput", "placeTitle", "placeInfo", "resultsList"];
  currentForecastItem = null; // { placeId, forecastData, timestamp, domElement (if in history) }
  historyForecasts = [];    // Array of { placeId, forecastData, timestamp, domElement }
  MAX_HISTORY_AGE_MS = 30 * 60 * 1000; // 30 minutes

  connect() {
    // console.log("[GMP Autocomplete] Connecting...");
    this.boundHandleGmpSelect = this._handleGmpSelect.bind(this); 
    this.setupAutocompleteListener(); // Add listener once
    this.initializeAutocompleteElement(); // Initial setup
    this._pruneExpiredForecasts(); // Initial prune on connect
    setInterval(() => this._pruneExpiredForecasts(), 60 * 1000); // Prune every minute
    // console.log("[GMP Autocomplete] connect() finished.");
  }

  disconnect() {
    if (this.hasAutocompleteInputTarget) {
      this.autocompleteInputTarget.removeEventListener('gmp-select', this.boundHandleGmpSelect);
    }
  }

  // Renamed from initAutocomplete, only handles element creation/append
  async initializeAutocompleteElement() {
    // console.log("[GMP Autocomplete] initializeAutocompleteElement started.");
    if (!(window.google && window.google.maps && window.google.maps.importLibrary)) {
      console.error("[GMP Autocomplete] Google Maps library not loaded.");
      return;
    }

    const { PlaceAutocompleteElement } = await window.google.maps.importLibrary("places");
    // console.log("[GMP Autocomplete] 'places' library imported.");

    if (!this.hasAutocompleteInputTarget) {
      console.error("[GMP Autocomplete] Autocomplete input CONTAINER target NOT FOUND.");
      return;
    }

    const placeAutocompleteContainer = this.autocompleteInputTarget;
    placeAutocompleteContainer.innerHTML = ''; // Clear the container

    const placeAutocompleteElement = new PlaceAutocompleteElement();
    this.autocompleteElement = placeAutocompleteElement; // Store the reference
    placeAutocompleteContainer.appendChild(this.autocompleteElement);
    // console.log("[GMP Autocomplete] PlaceAutocompleteElement appended.");
  }

  // Sets up the event listener on the container using event delegation
  setupAutocompleteListener() {
    if (!this.hasAutocompleteInputTarget) return;

    this.autocompleteInputTarget.removeEventListener('gmp-select', this.boundHandleGmpSelect);
    this.autocompleteInputTarget.addEventListener('gmp-select', this.boundHandleGmpSelect);

    // console.log("[GMP Autocomplete] setupAutocompleteListener() finished.");
  }

  // The actual logic for handling the gmp-select event
  async _handleGmpSelect(event) {
    // ===== VERY FIRST LOGS =====
    // console.log(`[GMP Autocomplete] _handleGmpSelect START at ${new Date().toISOString()}`);
    // console.log("[GMP Autocomplete] RAW event.target:", event.target);
    // console.log("[GMP Autocomplete] RAW event.target.value:", event.target ? event.target.value : 'event.target is falsy');
    // console.log("[GMP Autocomplete] RAW typeof event.target.value:", event.target ? typeof event.target.value : 'event.target is falsy');
    // console.log("[GMP Autocomplete] RAW this.autocompleteElement:", this.autocompleteElement);
    // console.log("[GMP Autocomplete] RAW this.autocompleteElement.value:", this.autocompleteElement ? this.autocompleteElement.value : 'this.autocompleteElement is falsy');
    // console.log("[GMP Autocomplete] RAW typeof this.autocompleteElement.value:", this.autocompleteElement ? typeof this.autocompleteElement.value : 'this.autocompleteElement is falsy');
    // ===== END VERY FIRST LOGS =====

    if (event.target !== this.autocompleteElement) {
      console.warn("[GMP Autocomplete] gmp-select event.target is NOT this.autocompleteElement.", { target: event.target, autocompleteElement: this.autocompleteElement });
    }


    // For debugging the event object itself and what `event.placePrediction` contains.
    // console.log("[GMP Autocomplete] gmp-select event FIRED. Full event object:");
    // console.log(event.placePrediction); // This is the critical part of the event

    if (!this.hasPlaceInfoTarget || !this.hasPlaceTitleTarget) {
      console.error("[GMP Autocomplete] Target elements (placeInfo or placeTitle) are missing.");
      return;
    }

    // 1. Get the PlacePrediction object from the event.
    // The event detail should contain placePrediction, not place.
    const prediction = event.placePrediction; // Corrected based on Google's documentation
    // console.log("[GMP Autocomplete] Value assigned to prediction (from event.placePrediction):", prediction);

    if (!prediction) {
      console.error("[GMP Autocomplete] No place prediction data found in the event.");
      this.placeTitleTarget.textContent = 'Error: No prediction data.';
      this.placeInfoTarget.innerHTML = '';
      return;
    }

    try {
      // 2. Use prediction.toPlace() to get a Place object
      // console.log("[GMP Autocomplete] Calling prediction.toPlace()...", prediction);
      const place = await prediction.toPlace(); // This is an async call
      // console.log("[GMP Autocomplete] Got place object from toPlace():", place);

      if (!place) {
        console.error("[GMP Autocomplete] Failed to convert prediction to place object.");
        this.placeTitleTarget.textContent = 'Error: Could not retrieve place details.';
        this.placeInfoTarget.innerHTML = '';
        return;
      }

      // Now fetch fields for this Place object
      // console.log("[GMP Autocomplete] Calling place.fetchFields()...", place);
      // Ensure fields are requested as per the Place object capabilities
      // const fetchedPlace = await place.fetchFields({ fields: ['id', 'formattedAddress', 'location', 'displayName'] });
      const fetchResult = await place.fetchFields({ fields: ['id', 'formattedAddress', 'location', 'displayName'] });
      // console.log("[GMP Autocomplete] Result from fetchFields():", fetchResult);

      // Check if the actual Place object is nested under a 'place' property based on console logs
      const actualFetchedPlace = fetchResult.place ? fetchResult.place : fetchResult;
      // console.log("[GMP Autocomplete] Actual fetched place object to be used:", actualFetchedPlace);

      // 3. Extract data and send to backend
      const placeId = actualFetchedPlace.id;
      const placeLocation = actualFetchedPlace.location;
      let lat, lng;

      if (placeLocation) {
        if (typeof placeLocation.lat === 'function' && typeof placeLocation.lng === 'function') {
          // It's a LatLng object
          lat = placeLocation.lat();
          lng = placeLocation.lng();
        } else if (typeof placeLocation.lat === 'number' && typeof placeLocation.lng === 'number') {
          // It's a LatLngLiteral object
          lat = placeLocation.lat;
          lng = placeLocation.lng;
        }
      }

      // console.log(`[GMP Autocomplete] Extracted lat: ${lat}, lng: ${lng}`);
      // console.log(`[GMP Autocomplete] Selected Place ID: ${placeId}`);

      // If lat or lng are undefined or null, handle this case
      if (lat === undefined || lat === null || lng === undefined || lng === null) {
        console.error("[GMP Autocomplete] Latitude or Longitude is missing from place data.", fetchedPlace);
        this.placeTitleTarget.textContent = 'Error: Missing location data.';
        this.placeInfoTarget.innerHTML = '';
        return;
      }

      // Send to backend
      // console.log(`[GMP Autocomplete] Sending place_id ${placeId} to backend /api/v1/forecasts`);
      const bodyPayload = { place_id: placeId, lat: lat, lng: lng };
      // console.log('[GMP Autocomplete] Object to be stringified:', bodyPayload);
      const apiResponse = await fetch('/api/v1/forecasts', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify(bodyPayload)
      });

      if (!apiResponse.ok) {
        const errorText = await apiResponse.text();
        console.error("[GMP Autocomplete] API Error:", apiResponse.status, errorText);
        this.placeTitleTarget.textContent = 'Error fetching forecast.';
        this.placeInfoTarget.innerHTML = `Server responded with ${apiResponse.status}: ${errorText}`;
        return;
      }

      const data = await apiResponse.json(); // 'data' is now defined in the correct scope for the next lines
      // console.log("[GMP Autocomplete] Forecast data received:", data);

      const newForecastItemData = {
        placeId: placeId,
        forecastData: data, // data already contains lat/lng/address from our backend
        timestamp: Date.now() // Use 'timestamp' and store as a number
      };

      // If there was a previously displayed forecast, move it to the history.
      if (this.currentForecastItem) {
        this.historyForecasts.unshift(this.currentForecastItem); // Add the OLD currentForecastItem to the internal array
        this._addForecastToHistoryDOM(this.currentForecastItem);   // Add the OLD currentForecastItem to the history DOM
        this._pruneExpiredForecasts(); // Prune after modifying history, ensures list doesn't grow indefinitely beyond age limit
      }

      this.currentForecastItem = newForecastItemData; // Update current forecast to the new one
      this._displayCurrentForecast(); // Display the new current forecast in the main area (not in history yet)

      // Clear the input field's value after processing
      // console.log("[GMP Autocomplete] Attempting to clear input field...");

    // `event.target` is the gmp-place-autocomplete element.
    // Our previous logs showed event.target.value is undefined at this stage.
    // Let's try setting it to null directly, as per typical web component behavior for clearing.
    if (event.target) {
      // console.log(`[GMP Autocomplete] Pre-clear event.target.value: ${event.target.value} (typeof: ${typeof event.target.value})`);
      try {
        event.target.value = null;
        // console.log(`[GMP Autocomplete] Post-clear event.target.value: ${event.target.value} (typeof: ${typeof event.target.value})`);

        if (event.target.value === null) {
          // console.log("[GMP Autocomplete] Input field successfully set to null.");
        } else if (event.target.value === '') {
          // console.log("[GMP Autocomplete] Input field successfully set to an empty string (though null was attempted).");
        } else {
          console.warn(`[GMP Autocomplete] Input field NOT cleared as expected. Final value: '${event.target.value}', type: ${typeof event.target.value}`);
        }
      } catch (e) {
        console.error("[GMP Autocomplete] Error while trying to set event.target.value to null:", e);
      }
    } else {
      console.error("[GMP Autocomplete] event.target is null or undefined, cannot clear.");
    }

      this._refreshAllTimeAges(); // Refresh all history item times

    } catch (error) {
      console.error("[GMP Autocomplete] Error in gmp-select handler:", error);
      if (this.hasPlaceTitleTarget) this.placeTitleTarget.textContent = 'An error occurred.';
      if (this.hasPlaceInfoTarget) this.placeInfoTarget.innerHTML = 'Could not process the selected place.';
    }
  }

  _displayCurrentForecast() {
    if (!this.currentForecastItem || !this.currentForecastItem.forecastData) {
      if (this.hasPlaceTitleTarget) this.placeTitleTarget.textContent = 'No forecast selected.';
      if (this.hasPlaceInfoTarget) this.placeInfoTarget.innerHTML = ''; // Clear with innerHTML
      return;
    }
    const data = this.currentForecastItem.forecastData;
    const timestamp = this.currentForecastItem.timestamp;
    const displayAddress = data.address || 'Address N/A';

    if (this.hasPlaceTitleTarget) {
      this.placeTitleTarget.textContent = displayAddress;
    }

    let forecastDetailsHTML = `<pre class="text-sm">Coordinates: Lat: ${data.latitude || 'N/A'}, Lng: ${data.longitude || 'N/A'}\n\n`;
    if (data.forecast && data.forecast.current) {
      forecastDetailsHTML += `Current Weather:\n`;
      forecastDetailsHTML += `  Conditions: ${data.forecast.current.conditions || 'Not available'}\n`;
      forecastDetailsHTML += `  Temperature: ${data.forecast.current.temp_f !== undefined ? data.forecast.current.temp_f + '°F' : 'Not available'}\n`;
      forecastDetailsHTML += `  Feels Like: ${data.forecast.current.feels_like_f !== undefined ? data.forecast.current.feels_like_f + '°F' : 'Not available'}\n`;
    } else {
      forecastDetailsHTML += "No current weather data available.";
    }
    forecastDetailsHTML += "</pre>";

    const timeAgoString = this._timeAgo(timestamp);
    const timeAgoHTML = `<p class="text-xs text-gray-500 mt-1 current-forecast-time-ago">${timeAgoString}</p>`;

    if (this.hasPlaceInfoTarget) {
      this.placeInfoTarget.innerHTML = forecastDetailsHTML + timeAgoHTML;
      this.placeInfoTarget.dataset.timestamp = timestamp; // Store timestamp for refresh
    }
  }

  _addForecastToHistoryDOM(forecastItem) {
    // console.log("<<<<< MEGA DEBUG: _addForecastToHistoryDOM ENTERED >>>>>", forecastItem);
    if (!forecastItem || !this.hasResultsListTarget) return;

    const historyEntry = document.createElement('div');
    historyEntry.classList.add('bg-white', 'p-4', 'rounded-lg', 'shadow-sm', 'mb-3');
    historyEntry.dataset.placeId = forecastItem.placeId; // Store placeId for potential future use
    historyEntry.dataset.timestamp = forecastItem.timestamp; // Store timestamp for refreshing time ago
  historyEntry.dataset.timestamp = forecastItem.timestamp; // Store timestamp for refreshing time ago

    const data = forecastItem.forecastData;
    let historyDisplay = `Coordinates: Lat: ${data.latitude || 'N/A'}, Lng: ${data.longitude || 'N/A'}\n\n`;
    if (data.forecast && data.forecast.current) {
      historyDisplay += `Current Weather:\n`;
      historyDisplay += `  Conditions: ${data.forecast.current.conditions || 'Not available'}\n`;
      historyDisplay += `  Temperature: ${data.forecast.current.temp_f !== undefined ? data.forecast.current.temp_f + '°F' : 'Not available'}\n`;
      historyDisplay += `  Feels Like: ${data.forecast.current.feels_like_f !== undefined ? data.forecast.current.feels_like_f + '°F' : 'Not available'}\n`;
    } else {
      historyDisplay += "No current weather data available.";
    }

    const createdAt = forecastItem.timestamp; // Use the timestamp from when it became current/was fetched
    // console.log('[DEBUG] forecastItem.timestamp:', createdAt);

    const timeAgoString = this._timeAgo(createdAt);
    // console.log('[DEBUG] _timeAgo returned:', timeAgoString);

    const timeAgoTextElement = document.createElement('p');
    timeAgoTextElement.classList.add('text-xs', 'text-gray-500', 'mt-1');
    timeAgoTextElement.textContent = timeAgoString;
    // console.log('[DEBUG] timeAgoTextElement created:', timeAgoTextElement);

    historyEntry.innerHTML = `
      <p class="font-semibold">${data.address || 'Address N/A'}</p>
      <pre class="text-sm">${historyDisplay}</pre>
    `;
    historyEntry.appendChild(timeAgoTextElement);
    // console.log('[DEBUG] historyEntry after appending timeAgoTextElement:', historyEntry.outerHTML);
    
    forecastItem.domElement = historyEntry; // Store reference to DOM element
    this.resultsListTarget.prepend(historyEntry);
    // console.log(`[GMP Autocomplete] Added to history DOM: ${forecastItem.placeId}`);
  }

  _removeForecastFromHistoryDOM(forecastItem) {
    if (forecastItem.domElement && forecastItem.domElement.parentNode) {
      forecastItem.domElement.parentNode.removeChild(forecastItem.domElement);
      // console.log(`[GMP Autocomplete] Removed from history DOM: ${forecastItem.placeId}`);
    }
  }

  _pruneExpiredForecasts() {
    const now = new Date().getTime();
    const forecastsToKeep = [];
    
    this.historyForecasts.forEach(item => {
      // item.timestamp is already a numeric timestamp (Date.now())
    const itemAge = now - item.timestamp;
      if (itemAge < this.MAX_HISTORY_AGE_MS) {
        forecastsToKeep.push(item);
      } else {
        this._removeForecastFromHistoryDOM(item);
        // console.log(`[GMP Autocomplete] Pruned expired forecast: ${item.placeId}`);
      }
    });
    this.historyForecasts = forecastsToKeep;
    // No need to re-render the entire list, just remove specific expired items
  }

    // New method to refresh all history item time ages
  _refreshAllTimeAges() {
    // Refresh history items
    if (this.hasResultsListTarget) {
      const historyItems = this.resultsListTarget.querySelectorAll('div[data-timestamp]');
      historyItems.forEach(itemDiv => {
        const timestamp = parseInt(itemDiv.dataset.timestamp, 10);
        if (!isNaN(timestamp)) {
          const timeAgoTextElement = itemDiv.querySelector('p.text-xs.text-gray-500.mt-1');
          if (timeAgoTextElement) {
            timeAgoTextElement.textContent = this._timeAgo(timestamp);
          }
        }
      });
    }

    // Refresh current forecast item's time ago
    if (this.currentForecastItem && this.hasPlaceInfoTarget && this.placeInfoTarget.dataset.timestamp) {
      const timestamp = parseInt(this.placeInfoTarget.dataset.timestamp, 10);
      if (!isNaN(timestamp)) {
        const timeAgoTextElement = this.placeInfoTarget.querySelector('p.current-forecast-time-ago');
        if (timeAgoTextElement) {
          timeAgoTextElement.textContent = this._timeAgo(timestamp);
        }
      }
    }
  }

  _timeAgo(timestamp) {
    const now = Date.now();
    const secondsPast = (now - timestamp) / 1000;

    if (secondsPast < 5) { 
      return 'just now';
    }
    if (secondsPast < 60) {
      return `${Math.round(secondsPast)} seconds ago`;
    }
    
    const minutesPast = Math.round(secondsPast / 60);
    if (minutesPast === 1) {
      return '1 minute ago';
    }
    return `${minutesPast} minutes ago`;
  }

  // Original fillInAddress, if needed elsewhere, or can be removed if not used.
  // For now, forecast display logic is self-contained in _displayCurrentForecast and _addForecastToHistoryDOM
  fillInAddress(place) {
    // This function might still be useful if we want to extract more address components
    // for display or other purposes, but it's not directly used by the forecast logic now.
    // If it's confirmed unused, we can remove it later.
    if (!place || !place.address_components) {
      console.warn("[GMP Autocomplete] fillInAddress called but no address components found.");
      return;
    }
    // ... (rest of original fillInAddress logic)
    // console.log("[GMP Autocomplete] fillInAddress was called (original function).")
  }
}
