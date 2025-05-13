class DropForecastCards < ActiveRecord::Migration[7.1]
  def change
    drop_table :forecast_cards
  end
end
