class CongressionalDistrict < ApplicationRecord
  validates :state, presence: true
  validates :district_number, presence: true
  validates :boundary, presence: true
  
  validates :state, uniqueness: { scope: :district_number }

  def name
    "#{state}-#{district_number}"
  end

  def self.leaderboard
    joins(<<~SQL)
      LEFT JOIN ysws_projects ON 
        congressional_districts.boundary && ysws_projects.location AND
        ST_Contains(
          congressional_districts.boundary::geometry,
          ysws_projects.location::geometry
        )
    SQL
    .group(:id)
    .select(<<~SQL)
      congressional_districts.*,
      COALESCE(SUM((fields->>'YSWS–Weighted Project Contribution')::float), 0) as project_count
    SQL
    .order('project_count DESC, state ASC, district_number ASC')
  end

  def self.find_by_location(point)
    where("ST_Contains(ST_GeomFromEWKB(boundary), ST_GeomFromEWKB(?))", point)
    .first
  end
end
