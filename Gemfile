# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.0'

# Core gems
gem 'active_model_serializers'
gem 'bootsnap', require: false
gem 'jbuilder'
gem 'pg', '~> 1.1'
gem 'puma', '>= 5.0'
gem 'rack-cors'
gem 'rails', '~> 7.1.3'

# Authentication and security
gem 'bcrypt', '~> 3.1.7'
gem 'jwt'

# Background processing and caching
gem 'redis', '~> 5.0'
gem 'redis-rails'
gem 'redis-store'
gem 'sidekiq'

# API and data handling
gem 'forecast_io'
gem 'geocoder'
gem 'httparty'

# Platform specific
gem 'tzinfo-data', platforms: %i[windows jruby]

group :development, :test do
  gem 'debug', platforms: %i[mri windows]
  gem 'dotenv-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'rspec-rails'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
end

group :development do
  gem 'annotate'
  gem 'bullet'
  gem 'letter_opener'
  gem 'rack-mini-profiler'
  gem 'spring'
  gem 'web-console'
end

group :production do
  gem 'lograge'
  gem 'sentry-rails'
  gem 'sentry-ruby'
end

# Security
gem 'brakeman', require: false
gem 'bundler-audit', require: false
gem 'rack-attack'
