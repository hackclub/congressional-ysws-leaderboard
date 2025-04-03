class AddMedianHouseholdIncomeToCongressionalDistricts < ActiveRecord::Migration[8.0]
  def change
    add_column :congressional_districts, :median_household_income, :integer
  end
end
