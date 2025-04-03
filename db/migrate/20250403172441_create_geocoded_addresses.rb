class CreateGeocodedAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :geocoded_addresses do |t|
      t.string :address, null: false
      t.st_point :location, geographic: true

      t.timestamps
    end

    add_index :geocoded_addresses, :address, unique: true
    add_index :geocoded_addresses, :location, using: :gist
  end
end
