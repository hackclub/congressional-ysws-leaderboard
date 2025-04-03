class AddRepresentativeInfoToCongressionalDistricts < ActiveRecord::Migration[8.0]
  def change
    add_column :congressional_districts, :representative_name, :string
    add_column :congressional_districts, :representative_party, :string
    add_column :congressional_districts, :representative_picture_url, :string
  end
end
