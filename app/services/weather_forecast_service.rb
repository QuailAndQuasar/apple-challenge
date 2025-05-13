# frozen_string_literal: true

# Service class responsible for fetching weather forecast data from the OpenWeatherMap API
# for a given Location object and updating the location's cached forecast data.
class WeatherForecastService
  # Custom error class for forecast-related issues.
  class ForecastError < StandardError; end

  # Initializes the service with a Location object.
  # Reads the OpenWeatherMap API key from environment variables.
  # @param location [Location] The location object containing latitude and longitude.
  # @raise [ForecastError] If the OPENWEATHER_API_KEY environment variable is not set.
  def initialize(location)
    @location = location
    @api_key = ENV['OPENWEATHER_API_KEY'].presence
    Rails.logger.info "Initializing WeatherForecastService for location: #{@location.address} (Lat: #{@location.latitude}, Lon: #{@location.longitude})"
    raise ForecastError, 'OpenWeatherMap API key (OPENWEATHER_API_KEY) is not configured in environment variables.' unless @api_key
  end

  # Fetches the current weather from OpenWeatherMap API using the location's coordinates.
  # If successful, it parses the response, formats it, and updates the associated
  # Location record with the new forecast data and timestamp.
  # @return [Hash] The formatted forecast data that was saved to the location.
  # @raise [ForecastError] If the API request fails (HTTP error, connection error, API key issue, or bad response).
  def fetch_forecast
    unless @location.latitude && @location.longitude
      raise ForecastError, "Cannot fetch forecast for location ID #{@location.id} without coordinates."
    end

    Rails.logger.info "Fetching OpenWeatherMap forecast for coordinates: #{@location.latitude},#{@location.longitude}"

    response = HTTParty.get(
      'https://api.openweathermap.org/data/2.5/weather', # Current weather endpoint
      query: {
        appid: @api_key,
        lat: @location.latitude,
        lon: @location.longitude,
        units: 'imperial' # Request Fahrenheit, mph, etc.
      },
      timeout: 10 # Add a reasonable timeout
    )

    Rails.logger.info "OpenWeatherMap API response status: #{response.code}"
    # Log response body for debugging if not successful or in development
    Rails.logger.debug "OpenWeatherMap response body: #{response.body}" if !response.success? || Rails.env.development?

    if response.success?
      data = response.parsed_response.deep_symbolize_keys
      Rails.logger.info 'Successfully parsed OpenWeatherMap API response'

      formatted_data = format_forecast(data)

      Rails.logger.info "Updating location ID #{@location.id} with new forecast data."
      # Use update! to raise an error if validation fails
      @location.update!(
        forecast_data: formatted_data,
        last_forecast_at: Time.current
      )
      Rails.logger.info "Location ID #{@location.id} forecast data updated successfully."
      formatted_data # Return the data that was saved
    else
      # Handle API errors reported in the response body
      parsed_body = response.parsed_response
      error_message = if parsed_body.is_a?(Hash)
                        parsed_body['message'] || parsed_body.dig(:error, :message) || 'Unknown API error'
                      else
                        "API returned status #{response.code}"
                      end

      Rails.logger.error "OpenWeatherMap API error: #{response.code} - #{error_message}"
      raise ForecastError, "Failed to fetch weather forecast: #{error_message} (Status: #{response.code})"
    end

  # Rescue network errors (timeout, DNS, connection refused etc.)
  rescue HTTParty::Error, Timeout::Error, SocketError => e
    Rails.logger.error "HTTP/Network error during OpenWeatherMap API call: #{e.class} - #{e.message}"
    raise ForecastError, "Network error while connecting to OpenWeatherMap API: #{e.message}"
  # Rescue potential errors during update!
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update location record: #{e.message}"
    raise ForecastError, "Error saving forecast data: #{e.message}"
  end

  private

  # Formats the raw data from the OpenWeatherMap API into a structured hash.
  # Extracts current weather conditions, temperature, etc.
  # Note: The /weather endpoint only provides current conditions, not a multi-day forecast.
  # @param data [Hash] The symbolized hash parsed from the OpenWeatherMap JSON response.
  # @return [Hash] A structured hash containing `{ current: { ... }, forecast: [] }`.
  def format_forecast(data)
    Rails.logger.debug 'Formatting OpenWeatherMap data'
    # Example data structure keys: :coord, :weather, :base, :main, :visibility, :wind, :clouds, :dt, :sys, :timezone, :id, :name, :cod
    current_weather = data.dig(:weather, 0) || {}
    main_data = data[:main] || {}
    wind_data = data[:wind] || {}
    sys_data = data[:sys] || {}

    {
      current: {
        # Temperatures
        temp_f: main_data[:temp],
        feels_like_f: main_data[:feels_like],
        temp_min_f: main_data[:temp_min],
        temp_max_f: main_data[:temp_max],
        # Conditions
        conditions: current_weather[:description]&.titleize || current_weather[:main] || 'N/A', # e.g., "Scattered Clouds"
        condition_code: current_weather[:id], # OpenWeatherMap condition code
        icon_code: current_weather[:icon], # OpenWeatherMap icon code (e.g., "03d")
        # Atmospheric
        pressure_hpa: main_data[:pressure], # hPa
        humidity_percent: main_data[:humidity], # %
        # Wind
        wind_speed_mph: wind_data[:speed], # mph (since units=imperial)
        wind_deg: wind_data[:deg],
        wind_gust_mph: wind_data[:gust],
        # Location/Time
        location_name: data[:name],
        country: sys_data[:country],
        sunrise_at: sys_data[:sunrise] ? Time.at(sys_data[:sunrise]).utc : nil,
        sunset_at: sys_data[:sunset] ? Time.at(sys_data[:sunset]).utc : nil,
        observed_at: data[:dt] ? Time.at(data[:dt]).utc : nil # Data timestamp
      },
      # The /weather endpoint only provides current data.
      # An empty array is kept here for potential future expansion using a different API endpoint.
      forecast: []
    }
  end
end
