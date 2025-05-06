# frozen_string_literal: true

# Location model for storing addresses and their associated weather forecasts
# @attr [String] address The full address of the location
# @attr [Decimal] latitude The latitude coordinate
# @attr [Decimal] longitude The longitude coordinate
# @attr [DateTime] last_forecast_at When the forecast was last fetched
# @attr [JSON] forecast_data The cached forecast data
class Location < ApplicationRecord
  # Validations
  validates :address, presence: true
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }

  # Scopes
  scope :with_recent_forecast, -> { where('last_forecast_at > ?', 30.minutes.ago) }

  # Callbacks
  before_validation :geocode_address, if: :address_changed?

  # Class methods
  def self.find_or_create_by_address(address)
    find_or_create_by(address: address)
  end

  # Instance methods
  def forecast_expired?
    last_forecast_at.nil? || last_forecast_at < 30.minutes.ago
  end

  def needs_forecast_update?
    forecast_data.nil? || forecast_expired?
  end

  def update_forecast(forecast_data)
    update(
      forecast_data: forecast_data,
      last_forecast_at: Time.current
    )
  end

  private

  def geocode_address
    return unless address_changed?

    result = Geocoder.search(address).first
    if result
      self.latitude = result.latitude
      self.longitude = result.longitude
    else
      errors.add(:address, 'could not be geocoded')
    end
  end
end
