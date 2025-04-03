class AddInvalidAddressFlagToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :addresses, :invalid_address, :boolean, null: false, default: false
  end
end
