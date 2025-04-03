class AddHighSchoolEnrollmentToCongressionalDistricts < ActiveRecord::Migration[8.0]
  def change
    add_column :congressional_districts, :high_school_enrollment, :integer
  end
end
