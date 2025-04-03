class RenameGeocodedAddressesToAddresses < ActiveRecord::Migration[8.0]
  def change
    rename_table :geocoded_addresses, :addresses
  end
end
