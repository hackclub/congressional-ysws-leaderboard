class AddCongressionalDistrictRefToAddresses < ActiveRecord::Migration[8.0]
  def change
    add_reference :addresses, :congressional_district, null: true, foreign_key: true
  end
end
