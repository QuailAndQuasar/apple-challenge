class CreateLocations < ActiveRecord::Migration[7.1]
  def change
    create_table :locations do |t|
      t.string :address
      t.decimal :latitude
      t.decimal :longitude
      t.datetime :last_forecast_at
      t.jsonb :forecast_data

      t.timestamps
    end
  end
end
