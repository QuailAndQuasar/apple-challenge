class AddGooglePlaceIdToLocations < ActiveRecord::Migration[7.1]
  def change
    add_column :locations, :google_place_id, :string
  end
end
