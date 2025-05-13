# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WeatherForecastService do
  let(:location) { create(:location, latitude: 40.7128, longitude: -74.0060) } # New York coordinates
  let(:service) { described_class.new(location) }
  # Use the real API key from ENV for VCR recording, otherwise a dummy for other stubs.
  # VCR will filter the real key from cassettes.
  let(:api_key) { ENV.fetch('OPENWEATHER_API_KEY', 'dummy_key_for_non_vcr_or_stubbed_tests') }

  before do
    # Allow original ENV behavior for other keys
    allow(ENV).to receive(:[]).and_call_original
    # Stub specifically for OPENWEATHER_API_KEY to ensure the service gets what we intend for the test
    allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return(api_key)
  end

  describe '#fetch_forecast' do
    # This context will now use VCR to record and replay actual API calls to OpenWeatherMap
    context 'when the API request is successful', :vcr do
      # Removed the WebMock stub_request block that was here.
      # VCR will handle recording/replaying the HTTP interaction.

      it 'returns formatted current weather data' do
        result = service.fetch_forecast

        expect(result).to be_a(Hash)
        expect(result).to include(:current, :forecast)

        current_weather = result[:current]
        expect(current_weather).to include(
          :temp_f,
          :feels_like_f,
          :conditions,
          :humidity,
          :pressure
        )
        expect(current_weather[:temp_f]).to be_a(Float)
        expect(current_weather[:conditions]).to be_a(String)

        # OpenWeatherMap's /weather endpoint only provides current conditions, not a multi-day forecast.
        # The service.format_forecast method reflects this by returning an empty array for :forecast.
        expect(result[:forecast]).to eq([])
      end

      it 'updates the location with the latest forecast data' do
        service.fetch_forecast
        location.reload

        expect(location.last_forecast_at).to be_present
        expect(location.last_forecast_at).to be_within(1.second).of(Time.current)
        expect(location.forecast_data).to be_present
        expect(location.forecast_data[:current][:temp_f]).to be_a(Float) # Check one field from the stored data
      end
    end

    context 'when the API request fails' do
      before do
        # This stub remains to simulate a generic API failure for OpenWeatherMap
        # Note: The URL and params should match OpenWeatherMap's API structure
        stub_request(:get, /api.openweathermap.org\/data\/2.5\/weather/)
          .with(
            query: {
              appid: api_key,
              lat: location.latitude.to_s, # Ensure params are strings if HTTParty sends them that way
              lon: location.longitude.to_s,
              units: 'imperial'
            }
          )
          .to_return(status: 400, body: { message: 'Invalid request parameters' }.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises a ForecastError' do
        expect { service.fetch_forecast }.to raise_error(WeatherForecastService::ForecastError, /Failed to fetch weather forecast: Invalid request parameters/)
      end
    end

    context 'when the API key is missing' do
      before do
        allow(ENV).to receive(:[]).with('OPENWEATHER_API_KEY').and_return(nil)
      end

      it 'raises a ForecastError with a specific message' do # Renamed for clarity
        expect { service.fetch_forecast }.to raise_error(
          WeatherForecastService::ForecastError,
          'OpenWeatherMap API key is not configured' # Updated message
        )
      end
    end
  end
end
