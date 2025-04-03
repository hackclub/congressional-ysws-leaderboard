class CreateCongressionalDistricts < ActiveRecord::Migration[8.0]
  def change
    create_table :congressional_districts do |t|
      t.string :state, null: false
      t.integer :district_number, null: false
      t.geometry :boundary, null: false, geographic: true

      t.timestamps
    end

    add_index :congressional_districts, [:state, :district_number], unique: true
    add_index :congressional_districts, :boundary, using: :gist
  end
end
