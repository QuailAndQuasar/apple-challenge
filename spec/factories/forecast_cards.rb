FactoryBot.define do
  factory :forecast_card do
    address { "MyString" }
    latitude { "9.99" }
    longitude { "9.99" }
    temperature { 1 }
    conditions { "MyString" }
    wind_speed { 1 }
    location_name { "MyString" }
    queried_at { "2025-05-09 08:10:47" }
  end
end
