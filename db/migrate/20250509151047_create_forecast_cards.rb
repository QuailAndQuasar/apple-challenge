class CreateForecastCards < ActiveRecord::Migration[7.1]
  def change
    create_table :forecast_cards do |t|
      t.string :address
      t.decimal :latitude
      t.decimal :longitude
      t.integer :temperature
      t.string :conditions
      t.integer :wind_speed
      t.string :location_name
      t.datetime :queried_at

      t.timestamps
    end
  end
end
