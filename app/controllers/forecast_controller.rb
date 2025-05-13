class ForecastController < ApplicationController
  def index
    lat = params[:lat]
    lng = params[:lng]

    Rails.logger.info("Received forecast request for coordinates: #{lat}, #{lng}")

    begin
      weather_data = WeatherApiService.get_forecast(lat, lng)
      render json: weather_data
    rescue StandardError => e
      Rails.logger.error("Weather API error: #{e.message}")
      render json: {
        error: 'Failed to fetch weather data',
        details: e.message
      }, status: :service_unavailable
    end
  end
end
