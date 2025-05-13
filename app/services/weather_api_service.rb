\
require 'net/http'
require 'json'
require 'uri'

# Service class to interact with the weather.gov API.
# Handles fetching forecast data based on latitude and longitude.
class WeatherApiService
  # Base URL for the weather.gov API.
  BASE_URL = 'https://api.weather.gov'
  # Maximum number of retries for failed requests (specifically for 503 errors).
  MAX_RETRIES = 3
  # Delay in seconds between retries.
  RETRY_DELAY = 1

  # Class method entry point to fetch forecast.
  # @param lat [Float, String] Latitude.
  # @param lng [Float, String] Longitude.
  # @return [Hash] Parsed forecast data.
  # @raise [StandardError] If the request fails after retries or parsing fails.
  def self.get_forecast(lat, lng)
    new.get_forecast(lat, lng)
  end

  # Instance method to fetch and parse forecast data.
  # 1. Rounds coordinates.
  # 2. Fetches the gridpoint URL from /points/{lat},{lng}.
  # 3. Fetches the actual forecast data from the gridpoint URL.
  # @param lat [Float, String] Latitude.
  # @param lng [Float, String] Longitude.
  # @return [Hash] Parsed forecast data containing :temperature, :conditions, etc.
  # @raise [StandardError] Propagates errors from API requests or parsing.
  def get_forecast(lat, lng)
    # Convert to floats and round coordinates to 4 decimal places as required by weather.gov API
    # to avoid potential redirects or errors.
    lat = lat.to_f.round(4)
    lng = lng.to_f.round(4)
    Rails.logger.info("Fetching weather data for coordinates: #{lat}, #{lng} (rounded)")

    begin
      # Step 1: Get the specific API endpoint URL for the forecast grid.
      points_uri = URI("#{BASE_URL}/points/#{lat},#{lng}")
      Rails.logger.info("Making request to points endpoint: #{points_uri}")
      points_response = make_request_with_retry(points_uri)

      # Step 2: Parse the response to find the forecast URL.
      points_data = JSON.parse(points_response.body)
      Rails.logger.debug("Points data received: #{points_data.inspect}") # Use debug level

      forecast_url = points_data.dig('properties', 'forecast')
      raise 'No forecast URL found in weather.gov points response' unless forecast_url

      Rails.logger.info("Found forecast URL: #{forecast_url}")
      forecast_uri = URI(forecast_url)

      # Step 3: Make the request to the actual forecast endpoint.
      Rails.logger.info("Making request to forecast endpoint: #{forecast_uri}")
      forecast_response = make_request_with_retry(forecast_uri)

      # Step 4: Parse the final forecast response.
      parse_response(forecast_response.body)
    rescue Net::HTTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
      # Catch specific network/HTTP errors.
      error_message = "Network/HTTP error fetching weather.gov data: #{e.class} - #{e.message}"
      Rails.logger.error(error_message)
      raise StandardError, error_message # Re-raise as a generic error for the controller
    rescue JSON::ParserError => e
      error_message = "Error parsing weather.gov API response: #{e.message}"
      Rails.logger.error(error_message)
      raise StandardError, error_message
    rescue StandardError => e # Catch other unexpected errors
      error_message = "Unexpected error fetching weather.gov data: #{e.message}"
      Rails.logger.error(error_message)
      Rails.logger.error e.backtrace.join("\n")
      raise # Re-raise the original error
    end
  end

  private

  # Makes an HTTP GET request to the given URI with a retry mechanism for specific errors (e.g., 503).
  # @param uri [URI] The URI to make the request to.
  # @param retries_left [Integer] The number of retries remaining.
  # @return [Net::HTTPResponse] The successful HTTP response.
  # @raise [StandardError] If the request fails after all retries.
  def make_request_with_retry(uri, retries_left = MAX_RETRIES)
    attempt = MAX_RETRIES - retries_left + 1
    begin
      make_request(uri) # Delegate to the actual request method
    rescue StandardError => e
      # Only retry on 503 Service Unavailable or similar transient errors.
      # Check the exception message string as specific error classes might vary.
      is_retryable = e.message.include?('503') || e.message.match?(/Service Unavailable/i)

      unless is_retryable && retries_left > 0
        Rails.logger.error "Request failed (Attempt #{attempt}/#{MAX_RETRIES}), no more retries or error not retryable: #{e.message}"
        raise e # Re-raise the last error if retries are exhausted or error is not retryable
      end

      Rails.logger.warn("Request attempt #{attempt} failed with retryable error: #{e.message}. Retrying in #{RETRY_DELAY}s... (#{retries_left} retries left)")
      sleep RETRY_DELAY
      # Recursively call with one less retry
      make_request_with_retry(uri, retries_left - 1)
    end
  end

  # Performs a single Net::HTTP GET request, handling redirects.
  # @param uri [URI] The URI for the request.
  # @param redirect_limit [Integer] Maximum number of redirects to follow.
  # @return [Net::HTTPSuccess] The successful HTTP response object.
  # @raise [StandardError] If the request fails, hits redirect limit, or returns non-success/non-redirect status.
  def make_request(uri, redirect_limit = 5)
    raise StandardError, 'Redirect limit exceeded' if redirect_limit <= 0

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.read_timeout = 10 # seconds
    http.open_timeout = 5 # seconds

    request = Net::HTTP::Get.new(uri)
    # Identify the application in the User-Agent header as required by weather.gov API terms.
    request['User-Agent'] = '4Cast/1.0 (github.com/your_repo or contact_email)' # Please update with your contact info
    request['Accept'] = 'application/geo+json' # Standard for weather.gov

    Rails.logger.debug("Making HTTP GET request to: #{uri}")
    # Rails.logger.debug("Request headers: #{request.to_hash}") # Can be verbose

    response = http.request(request)
    Rails.logger.debug("Response status: #{response.code}")
    # Rails.logger.debug("Response headers: #{response.to_hash}") # Can be verbose

    case response
    when Net::HTTPSuccess
      Rails.logger.debug('Request successful')
      response # Return the successful response object
    when Net::HTTPRedirection
      # Handle redirects by making a new request to the location specified in the header.
      new_location = response['location']
      Rails.logger.info("Redirected to: #{new_location}")
      new_uri = URI.parse(new_location)
      make_request(new_uri, redirect_limit - 1) # Recursively call with decremented limit
    else
      # Raise an error for any other response codes (4xx, 5xx, etc.)
      error_message = "Weather API request failed: #{response.code} - #{response.message}. URI: #{uri}"
      # Log body only if useful and not excessively large
      error_message += " Body: #{response.body}" if response.body&.length&.<(500)
      Rails.logger.error(error_message)
      # Raise an error that includes the status code for better context
      raise StandardError, "Weather API Error #{response.code}: #{response.message}"
    end
  end

  # Parses the JSON response body from the weather.gov forecast endpoint.
  # Extracts relevant fields into a simplified hash.
  # @param response_body [String] The JSON string from the forecast API response.
  # @return [Hash] A hash containing simplified weather data (:temperature, :conditions, etc.).
  # @raise [JSON::ParserError] If the response body is not valid JSON.
  # @raise [StandardError] If the expected data structure ('properties.periods') is missing.
  def parse_response(response_body)
    data = JSON.parse(response_body)
    periods = data.dig('properties', 'periods')
    raise StandardError, 'Invalid forecast data structure: properties.periods missing' unless periods&.is_a?(Array) && periods.first

    current = periods.first

    # Extract and format relevant data points
    {
      temperature: current['temperature'],
      temperature_unit: current['temperatureUnit'], # e.g., "F"
      conditions: current['shortForecast'],
      detailed_forecast: current['detailedForecast'],
      humidity: current.dig('relativeHumidity', 'value'), # Humidity might be nested
      wind_speed: current['windSpeed'], # Keep full string like "10 mph"
      wind_direction: current['windDirection'],
      icon: current['icon'], # URL to weather icon
      # location_name: current['name'], # Often just "Today", "Tonight", etc. - may not be useful as location
      start_time: Time.parse(current['startTime']) # Convert times to Time objects
      # end_time: Time.parse(current['endTime'])
    }
  end
end
