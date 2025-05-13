# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Location, type: :model do
  subject(:location) { build(:location) }

  # ensure that the location is valid with numerical latitude and longitude
  # ensure that the location is valid with an address present
  describe 'validations' do
    it { is_expected.to validate_presence_of(:address) }
    it { is_expected.to validate_uniqueness_of(:google_place_id).allow_nil }

    context 'latitude validations' do
      let(:location) { Location.new(address: '123 Test St', skip_geocoding: true) }

      it 'requires latitude to be present' do
        location.valid?
        expect(location.errors[:latitude]).to include("can't be blank")
      end

      it 'validates latitude range' do
        location.latitude = 40.7128
        expect(location).to validate_numericality_of(:latitude)
          .is_greater_than_or_equal_to(-90)
          .is_less_than_or_equal_to(90)
      end
    end

    context 'longitude validations' do
      let(:location) { Location.new(address: '123 Test St', skip_geocoding: true) }

      it 'requires longitude to be present' do
        location.valid?
        expect(location.errors[:longitude]).to include("can't be blank")
      end

      it 'validates longitude range' do
        location.longitude = -74.0060
        expect(location).to validate_numericality_of(:longitude)
          .is_greater_than_or_equal_to(-180)
          .is_less_than_or_equal_to(180)
      end
    end
  end

  # ensure that the location is geocoded before validation
  # VCR is used to record the geocoding request and replay it in future tests
  # to avoid making actual requests to the geocoding service.
  # This ensures that the geocoding service is not being hit during testing thus avoiding rate limiting errors.
  describe 'geocoding' do
    let(:valid_address) { '1600 Pennsylvania Avenue NW, Washington, DC 20500' }
    let(:location) { build(:location, address: valid_address, latitude: nil, longitude: nil) }

    it 'geocodes the address before validation', :vcr do
      location.valid? # Triggers before_validation :geocode_address
      expect(location.latitude).to be_present
      expect(location.longitude).to be_present
    end

    it 'adds an error and makes the record invalid if address cannot be geocoded' do
      location.address = 'Invalid Address That Cannot Be Found'
      # In test env, this address makes geocode_address return nil, add error, and throw(:abort)
      expect(location.valid?).to be false
      expect(location.errors[:address]).to include('could not be geocoded')
    end

    it 'prevents saving and raises RecordInvalid if geocoding fails' do
      # Test with build to avoid VCR for this specific interaction, relying on TestGeocoderResult
      invalid_location_for_save = build(:location, address: 'Invalid Address That Cannot Be Found', latitude: nil, longitude: nil)
      
      expect(invalid_location_for_save.save).to be false
      expect(invalid_location_for_save.persisted?).to be false # Should not be saved
      expect(invalid_location_for_save.errors[:address]).to include('could not be geocoded')

      # Attempting with save! should raise RecordInvalid
      expect {
        # Need a new instance for save! as errors are already populated on invalid_location_for_save
        new_invalid_location = build(:location, address: 'Invalid Address That Cannot Be Found', latitude: nil, longitude: nil)
        new_invalid_location.save!
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    context 'when skip_geocoding is true' do
      let(:location_skip_geocoding) { build(:location, address: valid_address, latitude: nil, longitude: nil, skip_geocoding: true) }

      it 'does not geocode the address' do
        # Expect that geocode_address is not called on the instance
        expect(location_skip_geocoding).not_to receive(:geocode_address)
        location_skip_geocoding.valid?
        # Coordinates should remain nil as geocoding was skipped and none were provided
        expect(location_skip_geocoding.latitude).to be_nil
        expect(location_skip_geocoding.longitude).to be_nil
      end
    end

    context 'when address has not changed' do
      let!(:persisted_location) { create(:location, address: valid_address) } # Persist with initial geocoding

      it 'does not re-geocode if only other attributes change' do
        # Change a non-address attribute
        persisted_location.google_place_id = 'new_place_id'
        
        # Expect geocode_address not to be called during the save/validation process
        # Note: We spy on the private method here for a more direct test of its invocation.
        # This is generally okay for testing callbacks if carefully managed.
        allow(persisted_location).to receive(:geocode_address).and_call_original
        persisted_location.save!
        expect(persisted_location).not_to have_received(:geocode_address)
      end

      it 'does re-geocode if the address itself changes' do
        allow(persisted_location).to receive(:geocode_address).and_call_original
        persisted_location.address = '1 Infinite Loop, Cupertino, CA' # Change the address
        persisted_location.save!
        expect(persisted_location).to have_received(:geocode_address)
      end
    end
  end

  # Make sure we don't query the weather API for locations that don't already have a forecast that have been
  # fetched within 30 minutes

  describe 'scopes' do
    describe '.with_recent_forecast' do
      let!(:recent_location) { create(:location, :with_forecast) }
      let!(:old_location) { create(:location, :with_expired_forecast) }
      let!(:no_forecast_location) { create(:location) }

      it 'returns only locations with forecasts less than 30 minutes old' do
        expect(described_class.with_recent_forecast).to include(recent_location)
        expect(described_class.with_recent_forecast).not_to include(old_location)
        expect(described_class.with_recent_forecast).not_to include(no_forecast_location)
      end
    end
  end

  # Ensure that the forecast is expired if the last forecast was fetched more than 30 minutes ago
  # Ensure that the forecast is not expired if the last forecast was fetched within the last 30 minutes
  # Ensure that the forecast is not expired if the last forecast was fetched more than 30 minutes ago
  # Ensure that the forecast is not expired if the last forecast was fetched within the last 30 minutes
  describe 'instance methods' do
    describe '#forecast_expired?' do
      it 'returns true when last_forecast_at is nil' do
        location = build(:location)
        expect(location.forecast_expired?).to be true
      end

      it 'returns true when forecast is older than 30 minutes' do
        location = build(:location, :with_expired_forecast)
        expect(location.forecast_expired?).to be true
      end

      it 'returns false when forecast is less than 30 minutes old' do
        location = build(:location, :with_forecast)
        expect(location.forecast_expired?).to be false
      end
    end

    describe '#needs_forecast_update?' do
      it 'returns true when forecast_data is nil' do
        location = build(:location)
        expect(location.needs_forecast_update?).to be true
      end

      it 'returns true when forecast is expired' do
        location = build(:location, :with_expired_forecast)
        expect(location.needs_forecast_update?).to be true
      end

      it 'returns false when forecast is recent' do
        location = build(:location, :with_forecast)
        expect(location.needs_forecast_update?).to be false
      end
    end

    describe '#update_forecast' do
      let(:location) { create(:location) }
      let(:forecast_data) do
        {
          temperature: 75.5,
          high: 80.0,
          low: 65.0,
          extended_forecast: []
        }
      end

      it 'updates forecast data and timestamp' do
        expect do
          location.update_forecast(forecast_data)
        end.to change(location, :forecast_data).from(nil).to(forecast_data)
                                               .and change(location, :last_forecast_at).from(nil)

        expect(location.last_forecast_at).to be_within(1.second).of(Time.current)
      end
    end

    describe '#forecast_data' do
      let(:location) { build(:location) }

      it 'returns nil if raw forecast_data is nil' do
        location.write_attribute(:forecast_data, nil)
        expect(location.forecast_data).to be_nil
      end

      it 'deep symbolizes keys' do
        raw_data = { 'current' => { 'temp' => 72 }, 'extended_forecast' => [{ 'date' => '2023-01-01', 'high' => 75 }] }
        location.write_attribute(:forecast_data, raw_data)
        processed_data = location.forecast_data
        expect(processed_data.key?(:current)).to be true
        expect(processed_data[:current].key?(:temp)).to be true
        expect(processed_data[:extended_forecast].first.key?(:date)).to be true
      end

      context 'with extended_forecast processing' do
        it 'parses valid date strings into Date objects' do
          raw_data = { extended_forecast: [{ date: '2023-10-26', high: 80 }, { date: '2023-10-27' }] }
          location.write_attribute(:forecast_data, raw_data)
          processed_data = location.forecast_data
          expect(processed_data[:extended_forecast][0][:date]).to eq(Date.parse('2023-10-26'))
          expect(processed_data[:extended_forecast][1][:date]).to eq(Date.parse('2023-10-27'))
        end

        it 'handles nil or missing date fields gracefully' do
          raw_data = { extended_forecast: [{ high: 80 }, { date: nil, high: 75 }] }
          location.write_attribute(:forecast_data, raw_data)
          processed_data = location.forecast_data
          # Assuming if date is not present or nil, it remains as is (or nil)
          expect(processed_data[:extended_forecast][0].key?(:date)).to be false
          expect(processed_data[:extended_forecast][1][:date]).to be_nil
        end

        it 'handles an empty extended_forecast array' do
          raw_data = { extended_forecast: [] }
          location.write_attribute(:forecast_data, raw_data)
          processed_data = location.forecast_data
          expect(processed_data[:extended_forecast]).to eq([])
        end

        it 'handles extended_forecast being nil' do
          raw_data = { current_temp: 70, extended_forecast: nil }
          location.write_attribute(:forecast_data, raw_data)
          processed_data = location.forecast_data
          expect(processed_data[:extended_forecast]).to be_nil
        end

        it 'handles extended_forecast key not being present' do
          raw_data = { current_temp: 70 }
          location.write_attribute(:forecast_data, raw_data)
          processed_data = location.forecast_data
          expect(processed_data.key?(:extended_forecast)).to be false
        end
      end
    end
  end

  describe 'class methods' do
    describe '.find_or_create_by_address' do
      let(:address) { '1600 Pennsylvania Avenue NW, Washington, DC 20500' }

      it 'creates a new location if address does not exist', :vcr do
        expect do
          described_class.find_or_create_by_address(address)
        end.to change(described_class, :count).by(1)
      end

      it 'returns existing location if address exists', :vcr do
        existing_location = create(:location, address: address)
        expect do
          result = described_class.find_or_create_by_address(address)
          expect(result).to eq(existing_location)
        end.not_to change(described_class, :count)
      end
    end
  end
end
