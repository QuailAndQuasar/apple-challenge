# frozen_string_literal: true

FactoryBot.define do
  factory :location do
    address { "#{Faker::Address.street_address}, #{Faker::Address.city}, #{Faker::Address.state}" }
    latitude { 40.7128 }
    longitude { -74.0060 }
    last_forecast_at { nil }
    forecast_data { nil }

    trait :with_forecast do
      last_forecast_at { Time.current }
      forecast_data do
        {
          temperature: Faker::Number.decimal(l_digits: 2),
          high: Faker::Number.decimal(l_digits: 2),
          low: Faker::Number.decimal(l_digits: 2),
          conditions: Faker::Lorem.word,
          extended_forecast: [
            {
              date: Time.zone.today + 1.day,
              high: Faker::Number.decimal(l_digits: 2),
              low: Faker::Number.decimal(l_digits: 2),
              conditions: Faker::Lorem.word
            },
            {
              date: Time.zone.today + 2.days,
              high: Faker::Number.decimal(l_digits: 2),
              low: Faker::Number.decimal(l_digits: 2),
              conditions: Faker::Lorem.word
            }
          ]
        }
      end
    end

    trait :with_expired_forecast do
      last_forecast_at { 31.minutes.ago }
      forecast_data do
        {
          temperature: Faker::Number.decimal(l_digits: 2),
          high: Faker::Number.decimal(l_digits: 2),
          low: Faker::Number.decimal(l_digits: 2),
          conditions: Faker::Lorem.word,
          extended_forecast: []
        }
      end
    end

    trait :without_coordinates do
      latitude { nil }
      longitude { nil }
    end
  end
end
