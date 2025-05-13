# 4Cast - Weather Forecast Application

This application allows users to search for locations using Google Places Autocomplete and view the current weather forecast for the selected location using the OpenWeatherMap API.

## Prerequisites

Before you begin, ensure you have the following installed:

*   **Ruby:** Version 3.x We're using RBENV to manage Ruby versions (check `.ruby-version` file for the exact version)
*   **Bundler:** `gem install bundler`
*   **Node.js:** Version 18+ (for JavaScript asset pipeline)
*   **Yarn:** Version 1.x (for JavaScript package management)
*   **PostgreSQL:** Or another database compatible with Rails (default is PostgreSQL).

## Getting Started

1.  **Clone the Repository:**
    ```bash
    git clone git@github.com:QuailAndQuasar/apple-challenge.git
    cd apple-challenge
    ```

2.  **Install Ruby Dependencies:**
    ```bash
    bundle install
    ```

3.  **Install JavaScript Dependencies:**
    ```bash
    yarn install
    ```

4.  **Configure Environment Variables:**
    *   Copy the example environment file:
        ```bash
        cp .env.example .env
        ```
    *   Edit the `.env` file and add your API keys:
        *   `GOOGLE_MAPS_API_KEY`: Your Google Maps API key (enable Places API and Geocoding API in Google Cloud Console).
        *   `OPENWEATHER_API_KEY`: Your OpenWeatherMap API key.

5.  **Set Up the Database:**
    *   Create the database:
        ```bash
        rails db:create
        ```
    *   Run database migrations:
        ```bash
        rails db:migrate
        ```
    *(If you encounter issues, ensure your `config/database.yml` matches your local database setup.)*

## Running the Application

Start the Rails server:

```bash
bin/dev
```

This typically starts the server using `foreman` or a similar tool defined in the `Procfile.dev`. Open your web browser and navigate to `http://localhost:3000` (or the port specified in the output).

## Running Tests

To run the RSpec test suite:

```bash
rspec
```
