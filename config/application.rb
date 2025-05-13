require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WeatherForecast
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Configure Content Security Policy
    config.content_security_policy do |policy|
      policy.default_src :self, :https
      policy.font_src    :self, :https, :data
      policy.img_src     :self, :https, :data
      policy.object_src  :none
      policy.script_src  :self, :https, :unsafe_inline, :unsafe_eval
      policy.style_src   :self, :https, :unsafe_inline
      policy.connect_src :self, :https, :ws, :wss, "http://localhost:3035", "ws://localhost:3035", "http://localhost:3000", "ws://localhost:3000"
    end

    # Generate CSP nonces for script and style tags
    config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w(script-src)

    # Enable serving of static files
    config.public_file_server.enabled = true

    # Configure the asset pipeline
    config.assets.enabled = true
    config.assets.initialize_on_precompile = false
    config.assets.compile = true
    # config.assets.digest = true
    config.assets.version = '1.0'

    # Add additional assets to the asset load path
    config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
    config.assets.paths << Rails.root.join('app', 'assets', 'images')

    # Precompile additional assets
    config.assets.precompile += %w( application.tailwind.css )
  end
end
