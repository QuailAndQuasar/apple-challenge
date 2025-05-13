# frozen_string_literal: true

module Api
  module V1
    class ForecastsController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:create]

      def create
        location = determine_location
        return unless location

        validate_location_coordinates(location)
        return unless location.valid?

        forecast = fetch_weather_for(location)
        return unless forecast

        render_success(location, forecast)
      rescue ActiveRecord::RecordInvalid => e
        render_validation_error(e)
      rescue StandardError => e
        render_generic_error(e, 'An unexpected error occurred while processing the forecast request.')
      end

      private

      def determine_location
        return find_or_fetch_location_by_place_id(forecast_params[:place_id]) if forecast_params[:place_id].present?
        return find_or_create_location_by_address(forecast_params[:address]) if forecast_params[:address].present?

        render_error('Address or Place ID is required', :unprocessable_entity)
        nil
      end

      def find_or_create_location_by_address(address)
        Rails.logger.info "Received forecast request for address: #{address}"
        Location.find_or_create_by(address: address)
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Validation error creating location by address '#{address}': #{e.message}"
        render_validation_error(e)
        nil
      end

      def find_or_fetch_location_by_place_id(place_id)
        Rails.logger.info "Received forecast request for google_place_id: #{place_id}"
        location = Location.find_by(google_place_id: place_id)
        return location if location&.has_recent_forecast?

        Rails.logger.info "No existing up-to-date location found for google_place_id: #{place_id}. Fetching details."
        place_details = fetch_google_place_details(place_id)
        return nil unless place_details

        update_or_create_location_from_details(place_id, place_details)
      end

      def fetch_google_place_details(place_id)
        api_key = ENV['GOOGLE_MAPS_API_KEY']
        return render_error('Server configuration error: Missing Google API key.', :internal_server_error) unless api_key

        fields = %w[formatted_address geometry/location name place_id].join(',')
        url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=#{place_id}&fields=#{fields}&key=#{api_key}"
        Rails.logger.info "Fetching place details from Google: #{url.gsub(api_key, '[REDACTED]')}"

        response = HTTParty.get(url)
        return handle_google_api_error(response) unless response.success? && response.parsed_response['status'] == 'OK'

        response.parsed_response['result']
      rescue StandardError => e
        Rails.logger.error "HTTParty error fetching Google Place details: #{e.message}"
        render_error('Failed to communicate with Google Places service.', :service_unavailable)
        nil
      end

      def update_or_create_location_from_details(place_id, details)
        formatted_address = details['formatted_address']
        lat = details.dig('geometry', 'location', 'lat')
        lng = details.dig('geometry', 'location', 'lng')
        return render_error('Could not retrieve complete location details from Google for the provided place_id.', :unprocessable_entity) unless lat.present? && lng.present? && formatted_address.present?

        location = Location.find_or_initialize_by(google_place_id: place_id)
        location.assign_attributes(
          address: formatted_address,
          latitude: lat,
          longitude: lng,
          skip_geocoding: true
        )

        return render_validation_error_explicit(location.errors) unless location.save

        Rails.logger.info "Location #{location.previously_new_record? ? 'created' : 'updated'} (ID: #{location.id}) with Google Place Details for place_id: #{place_id}"
        location
      end

      def validate_location_coordinates(location)
        return unless location.latitude.blank? || location.longitude.blank?

        log_msg = "Location (ID: #{location&.id}, Address: '#{location&.address}', PlaceID: '#{location&.google_place_id}') missing coordinates after fetch/geocode."
        Rails.logger.error log_msg
        location.errors.add(:base, 'Could not determine coordinates for the provided input.')
        render_error(location.errors.full_messages.join(', '), :unprocessable_entity)
      end

      def fetch_weather_for(location)
        Rails.logger.info "Fetching weather for location ID: #{location.id} at (#{location.latitude}, #{location.longitude})"
        service = WeatherForecastService.new(location)
        service.fetch_forecast
      rescue WeatherForecastService::ForecastError => e
        Rails.logger.error "WeatherForecastService error for Location ID #{location.id}: #{e.message}"
        render_error(e.message, :internal_server_error)
        nil
      end

      def render_success(location, forecast)
        render json: {
          google_place_id: location.google_place_id,
          address: location.address,
          latitude: location.latitude,
          longitude: location.longitude,
          forecast: forecast
        }, status: :ok
      end

      def render_error(message, status)
        render json: { error: message }, status: status
      end

      def render_validation_error(exception)
        render_error("Validation error: #{exception.record.errors.full_messages.join(', ')}", :unprocessable_entity)
      end

      def render_validation_error_explicit(errors)
        render_error("Validation error: #{errors.full_messages.join(', ')}", :unprocessable_entity)
      end

      def render_generic_error(exception, message = 'An unexpected error occurred.')
        Rails.logger.error "#{message}: #{exception.message}"
        Rails.logger.error exception.backtrace.join("\n")
        render_error(message, :internal_server_error)
      end

      def handle_google_api_error(response)
        status = response.parsed_response['status']
        message = response.parsed_response['error_message'] || 'Unknown Google API error'
        Rails.logger.error "Google Places API error: Status: #{status}, Message: #{message}"
        render_error("Failed to fetch location details from Google. Status: #{status}", :service_unavailable)
      end

      def forecast_params
        params.permit(:address, :place_id)
      end
    end
  end
end
