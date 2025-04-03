class CongressionalDistrict < ApplicationRecord
  validates :state, presence: true
  validates :district_number, presence: true
  validates :boundary, presence: true
  
  validates :state, uniqueness: { scope: :district_number }

  # Add association to Ysws::Project
  has_many :ysws_projects, class_name: 'Ysws::Project', foreign_key: 'congressional_district_id'

  def name
    "#{state}-#{district_number}"
  end

  def self.leaderboard
    # Optimized query using the pre-calculated congressional_district_id
    left_joins(:ysws_projects) # Use left_joins to include districts with 0 projects
    .group(:id)
    .select(<<~SQL)
      congressional_districts.*,
      COALESCE(SUM((ysws_projects.fields->>'YSWS–Weighted Project Contribution')::float), 0) as project_count,
      congressional_districts.high_school_enrollment
    SQL
    .order('project_count DESC, state ASC, district_number ASC')
  end

  def self.find_by_location(point)
    # This method is still useful for finding a single district for a point,
    # but it's no longer used for the main leaderboard calculation.
    # Keep the optimized spatial query here.
    find_by_sql([<<~SQL, point.to_s, point.to_s]).first
      SELECT cd.*
      FROM congressional_districts cd
      WHERE cd.boundary && ST_GeographyFromText(?)
      AND ST_Contains(cd.boundary::geometry, ST_GeometryFromText(?, 4326))
      LIMIT 1
    SQL
  end
end
