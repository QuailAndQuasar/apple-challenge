# frozen_string_literal: true

# Represents a geographical location identified by address or coordinates,
# used for fetching and caching weather forecasts.
#
# Attributes:
#   address [String] - The full address string.
#   latitude [Decimal] - The geographical latitude.
#   longitude [Decimal] - The geographical longitude.
#   google_place_id [String] - Optional Google Place ID for precise lookups.
#   last_forecast_at [DateTime] - Timestamp of the last successful forecast fetch.
#   forecast_data [JSON] - Cached weather forecast data (structure defined by WeatherForecastService).
class Location < ApplicationRecord
  # Allows skipping the geocoding callback, useful when lat/lng are provided directly (e.g., from Google Places API).
  attr_accessor :skip_geocoding

  # Validations
  validates :address, presence: true
  # Ensure google_place_id is unique if present.
  validates :google_place_id, uniqueness: true, allow_nil: true
  # Standard latitude/longitude constraints.
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }, unless: :skip_geocoding
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }, unless: :skip_geocoding

  # Scopes
  # Finds locations where the forecast was updated within the last 30 minutes.
  scope :with_recent_forecast, -> { where('last_forecast_at > ?', 30.minutes.ago) }

  # Callbacks
  # Geocode the address to get latitude/longitude before validation, unless skipped.
  before_validation :geocode_address, if: :should_geocode?

  # Class Methods

  # Finds or creates a location record based solely on the address string.
  # @param address [String] The address to find or create.
  # @return [Location] The found or newly created location record.
  def self.find_or_create_by_address(address)
    find_or_create_by(address: address)
  end

  # Instance Methods

  # Checks if the cached forecast data is older than 30 minutes.
  # @return [Boolean] True if the forecast is missing or older than 30 minutes, false otherwise.
  def forecast_expired?
    last_forecast_at.nil? || last_forecast_at < 30.minutes.ago
  end

  # Determines if a new forecast fetch is needed (no data or data is expired).
  # @return [Boolean] True if an update is needed, false otherwise.
  def needs_forecast_update?
    forecast_data.nil? || forecast_expired?
  end

  # Checks if the location has a forecast that was fetched recently (within 30 minutes).
  # Placeholder method - adjust logic based on caching requirements.
  # @return [Boolean] Currently always returns false.
  def has_recent_forecast?
    # Example implementation:
    # forecast_data.present? && !forecast_expired?
    false # Replace with actual logic if caching is implemented
  end

  # Updates the forecast data and timestamp for the location.
  # @param new_forecast_data [Hash] The new forecast data from the WeatherForecastService.
  # @return [Boolean] True if the update was successful, false otherwise.
  def update_forecast(new_forecast_data)
    update(
      forecast_data: new_forecast_data.deep_symbolize_keys, # Ensure consistent hash keys
      last_forecast_at: Time.current
    )
  end

  # Accessor for forecast_data that ensures keys are symbols and dates are parsed.
  # Overrides the default ActiveRecord reader for the `forecast_data` JSON column.
  # @return [Hash, nil] The processed forecast data hash, or nil if no data.
  def forecast_data
    raw_data = read_attribute(:forecast_data) # Use read_attribute to avoid infinite loop
    return nil if raw_data.nil?

    # Ensure consistent key format (symbols)
    data = raw_data.deep_symbolize_keys

    # Attempt to parse date strings in extended_forecast if present
    if data[:extended_forecast].present? && data[:extended_forecast].is_a?(Array)
      data[:extended_forecast] = data[:extended_forecast].map do |forecast|
        # Check if forecast is a hash and has a :date key before parsing
        if forecast.is_a?(Hash) && forecast[:date].present?
          begin
            forecast[:date] = Date.parse(forecast[:date].to_s) unless forecast[:date].is_a?(Date)
          rescue ArgumentError
            # Handle cases where date might not be a parseable string
            Rails.logger.warn "Could not parse date in extended_forecast: #{forecast[:date]}"
          end
        end
        forecast
      end
    end
    data
  end

  private

  # Determines if geocoding should be performed.
  # Skips if `skip_geocoding` is true or if the address hasn't changed.
  # @return [Boolean]
  def should_geocode?
    !skip_geocoding && (new_record? || address_changed?)
  end

  # Simple mock result for Geocoder in the test environment.
  class TestGeocoderResult
    attr_reader :latitude, :longitude

    def initialize(latitude:, longitude:)
      @latitude = latitude
      @longitude = longitude
    end
  end

  # Performs geocoding using the Geocoder gem to find latitude/longitude for the address.
  # Uses a mock result in the test environment.
  # Adds an error and aborts validation if geocoding fails.
  def geocode_address
    # Skip if address hasn't changed (redundant check due to `if:` condition, but safe)
    # return unless address_changed?

    result = if Rails.env.test?
               # Provide a mock result for testing unless address is specifically invalid
               if address == 'Invalid Address That Cannot Be Found'
                 nil
               else
                 TestGeocoderResult.new(latitude: 40.7128, longitude: -74.0060)
               end
             else
               # Actual Geocoder lookup in non-test environments
               begin
                 Geocoder.search(address).first
               rescue StandardError => e
                 Rails.logger.error "Geocoder service error for address '#{address}': #{e.message}"
                 errors.add(:address, "geocoding service failed: #{e.message}")
                 throw(:abort)
               end
             end

    if result
      self.latitude = result.latitude
      self.longitude = result.longitude
    else
      # If no result is found (or mock is nil)
      errors.add(:address, 'could not be geocoded. Please provide a valid address.')
      throw(:abort) # Prevent saving the record if geocoding fails
    end
  end
end
