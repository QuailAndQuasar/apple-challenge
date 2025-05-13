# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V1::ForecastsController, type: :controller do
  describe 'POST #create' do
    let(:valid_address_param) { '123 Main St, New York, NY' } # For the address param codepath
    let(:location_from_address) { build_stubbed(:location, address: valid_address_param, latitude: 40.7128, longitude: -74.0060, google_place_id: nil) }
    
    # Updated forecast_data structure to match WeatherForecastService (OpenWeatherMap)
    let(:forecast_data_from_service) do 
      {
        current: {
          temp_f: 68.0,
          feels_like_f: 67.0,
          conditions: 'clear sky',
          humidity: 50,
          pressure: 1012
        },
        forecast: [] # OpenWeatherMap /weather endpoint provides an empty forecast array via the service
      }
    end
    let(:weather_service_double) { instance_double(WeatherForecastService) }

    before do
      # Default stub for WeatherForecastService
      allow(WeatherForecastService).to receive(:new).and_return(weather_service_double)
      allow(weather_service_double).to receive(:fetch_forecast).and_return(forecast_data_from_service)
    end

    context 'when using address parameter' do
      context 'with a valid address that can be geocoded' do
        before do
          # Stub for the address codepath in the controller
          allow(Location).to receive(:find_or_create_by).with(address: valid_address_param).and_return(location_from_address)
          # Ensure the location object itself isn't seen as needing geocoding again if it's already geocoded
          allow(location_from_address).to receive(:latitude).and_return(40.7128)
          allow(location_from_address).to receive(:longitude).and_return(-74.0060)
        end

        it 'returns a successful response with address, coordinates, and forecast data' do
          post :create, params: { address: valid_address_param }

          expect(response).to have_http_status(:ok)
          json_response = response.parsed_body.deep_symbolize_keys

          expect(json_response[:address]).to eq(valid_address_param)
          expect(json_response[:latitude]).to eq(40.7128)
          expect(json_response[:longitude]).to eq(-74.0060)
          expect(json_response[:google_place_id]).to be_nil # As it came from address, not place_id
          expect(json_response[:forecast]).to eq(forecast_data_from_service) # Compare the whole structure
        end
      end

      context 'when geocoding the address fails (Location returns no coordinates)' do
        let(:location_no_coords) { build_stubbed(:location, address: valid_address_param, latitude: nil, longitude: nil) }
        before do
          allow(Location).to receive(:find_or_create_by).with(address: valid_address_param).and_return(location_no_coords)
        end

        it 'returns an unprocessable_entity error' do
          post :create, params: { address: valid_address_param }
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:error]).to eq("Could not determine coordinates for the provided input. Please provide a valid address or place_id.")
        end
      end

      context 'when WeatherForecastService raises an error' do
        before do
          allow(Location).to receive(:find_or_create_by).with(address: valid_address_param).and_return(location_from_address)
          allow(weather_service_double).to receive(:fetch_forecast)
            .and_raise(WeatherForecastService::ForecastError.new('Service down'))
        end

        it 'returns an unprocessable_entity error with the service message' do
          post :create, params: { address: valid_address_param }
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:error]).to eq('Service down')
        end
      end
    end # end of context 'when using address parameter'

    context 'when using place_id parameter' do
      let(:google_place_id_param) { 'ChIJZXJgK35QwokR4p8jYOM2OE8' } # Example Google Place ID
      let(:address_from_google) { '1600 Amphitheatre Parkway, Mountain View, CA 94043, USA' }
      let(:lat_from_google) { 37.4224764 }
      let(:lng_from_google) { -122.0842499 }
      let(:location_attributes_from_google) do
        {
          google_place_id: google_place_id_param,
          address: address_from_google,
          latitude: lat_from_google,
          longitude: lng_from_google
        }
      end
      let(:location_created_from_google) { build_stubbed(:location, location_attributes_from_google) }

      let(:google_api_success_response_body) do
        {
          "result" => {
            "formatted_address" => address_from_google,
            "geometry" => {
              "location" => { "lat" => lat_from_google, "lng" => lng_from_google }
            },
            "name" => "Googleplex",
            "address_components" => [] # Add more if needed for specific tests
          },
          "status" => "OK"
        }.to_json
      end

      let(:google_api_key) { 'test_google_api_key' }

      before do
        # Allow other ENV calls to pass through to the original ENV object
  allow(ENV).to receive(:[]).and_call_original
  # Specifically stub the GOOGLE_MAPS_API_KEY
  allow(ENV).to receive(:[]).with('GOOGLE_MAPS_API_KEY').and_return(google_api_key)
      end

      context 'with a valid place_id and successful Google API call' do
        context 'when location does not exist or needs update' do
          before do
            # Simulate Location.find_by returning nil or a stale record initially
            allow(Location).to receive(:find_by).with(google_place_id: google_place_id_param).and_return(nil) 
            
            # Stub the Google Places API call
            expected_google_url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=#{google_place_id_param}&fields=address_component,formatted_address,geometry,name&key=#{google_api_key}"
            allow(HTTParty).to receive(:get).with(expected_google_url).and_return(
              double('response', success?: true, parsed_response: JSON.parse(google_api_success_response_body))
            )

            # Stub find_or_initialize_by and save to track the interaction
            # We expect the controller to build a new location and save it
            allow(Location).to receive(:find_or_initialize_by).with(google_place_id: google_place_id_param).and_return(location_created_from_google)
            allow(location_created_from_google).to receive(:skip_geocoding=)
            allow(location_created_from_google).to receive(:save!).and_return(true)
            
            # Ensure WeatherForecastService is called with the newly processed location
            allow(WeatherForecastService).to receive(:new).with(location_created_from_google).and_return(weather_service_double)
          end

          it 'returns a successful response with Google Place details, coordinates, and forecast data' do
            post :create, params: { place_id: google_place_id_param }
            
            expect(response).to have_http_status(:ok)
            json_response = response.parsed_body.deep_symbolize_keys

            expect(json_response[:google_place_id]).to eq(google_place_id_param)
            expect(json_response[:address]).to eq(address_from_google)
            expect(json_response[:latitude]).to eq(lat_from_google.to_s)
            expect(json_response[:longitude]).to eq(lng_from_google.to_s)
            expect(json_response[:forecast]).to eq(forecast_data_from_service)
          end
        end

        context 'when location already exists and forecast is up-to-date' do
          let(:existing_location) { build_stubbed(:location, location_attributes_from_google) }
          before do
            allow(Location).to receive(:find_by).with(google_place_id: google_place_id_param).and_return(existing_location)
            allow(existing_location).to receive(:needs_forecast_update?).and_return(false)
            
            # Ensure Google API is NOT called
            expect(HTTParty).not_to receive(:get) # Matching URL specifically might be too brittle if params change slightly

            # WeatherForecastService should be initialized with the existing location
            allow(WeatherForecastService).to receive(:new).with(existing_location).and_return(weather_service_double)
          end

          it 'returns a successful response using existing location data' do
            post :create, params: { place_id: google_place_id_param }

            expect(response).to have_http_status(:ok)
            json_response = response.parsed_body.deep_symbolize_keys
            expect(json_response[:google_place_id]).to eq(google_place_id_param)
            expect(json_response[:address]).to eq(address_from_google)
            expect(json_response[:forecast]).to eq(forecast_data_from_service)
          end
        end
      end

      context 'when Google Places API call fails' do
        before do
          allow(Location).to receive(:find_by).with(google_place_id: google_place_id_param).and_return(nil)
          expected_google_url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=#{google_place_id_param}&fields=address_component,formatted_address,geometry,name&key=#{google_api_key}"
          allow(HTTParty).to receive(:get).with(expected_google_url).and_return(
            double('response', success?: false, parsed_response: { "status" => "REQUEST_DENIED", "error_message" => "API key invalid." })
          )
        end

        it 'returns a service_unavailable error' do
          post :create, params: { place_id: google_place_id_param }
          expect(response).to have_http_status(:service_unavailable)
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:error]).to eq('Failed to fetch location details from Google.')
        end
      end

      context 'when Google Places API response is missing required details' do
        before do
          allow(Location).to receive(:find_by).with(google_place_id: google_place_id_param).and_return(nil)
          incomplete_google_response_body = {
            "result" => { "name" => "Incomplete Place" }, # Missing formatted_address or geometry
            "status" => "OK"
          }.to_json
          expected_google_url = "https://maps.googleapis.com/maps/api/place/details/json?place_id=#{google_place_id_param}&fields=address_component,formatted_address,geometry,name&key=#{google_api_key}"

          allow(HTTParty).to receive(:get).with(expected_google_url).and_return(
            double('response', success?: true, parsed_response: JSON.parse(incomplete_google_response_body))
          )
        end

        it 'returns an unprocessable_entity error' do
          post :create, params: { place_id: google_place_id_param }
          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body.deep_symbolize_keys
          expect(json_response[:error]).to eq('Could not retrieve complete location details from Google for the provided place_id.')
        end
      end
    end # end of context 'when using place_id parameter'

    # Original context 'with invalid address' - this is now more like 'WeatherForecastService raises an error'
    # context 'with invalid address' do
    #   before do
    #     allow(forecast_service).to receive(:fetch_forecast)
    #       .and_raise(WeatherForecastService::ForecastError.new('Invalid address'))
    #   end

    #   it 'returns an error response' do
    #     post :create, params: { address: 'invalid address' }

    #     expect(response).to have_http_status(:unprocessable_entity)
    #     json_response = JSON.parse(response.body)
    #     expect(json_response['error']).to eq('Invalid address')
    #   end
    # end

    context 'with missing address and place_id parameters' do
      it 'returns an error response' do
        post :create, params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Address or Place ID is required')
      end
    end
  end
end
