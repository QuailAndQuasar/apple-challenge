source "https://rubygems.org"

# Core Rails gems
ruby "3.3.0"
gem "rails", "~> 7.1.3"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# API and Serialization
gem "jbuilder"
gem "rack-cors"
gem "active_model_serializers"

# Authentication and Authorization
gem "bcrypt", "~> 3.1.7"
gem "jwt"

# Background Processing
gem "sidekiq"
gem "redis", "~> 5.0"

# Caching
gem "redis-rails"
gem "redis-store"

# Testing
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-rails"
  gem "pry-byebug"
  gem "dotenv-rails"
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "simplecov", require: false
  gem "vcr"
  gem "webmock"
end

# Development
group :development do
  gem "annotate"
  gem "bullet"
  gem "letter_opener"
  gem "rack-mini-profiler"
  gem "spring"
  gem "web-console"
end

# Production
group :production do
  gem "lograge"
  gem "sentry-ruby"
  gem "sentry-rails"
end

# Security
gem "brakeman", require: false
gem "bundler-audit", require: false
gem "rack-attack"

# Utilities
gem "httparty"
gem "geocoder"
gem "forecast_io"
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ]
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"
end

