class AddLeaderboardIndexes < ActiveRecord::Migration[8.0]
  def change
    # Add a functional index for the weighted contribution field
    # This will speed up aggregation of the weighted contributions
    execute %{
      CREATE INDEX index_ysws_projects_on_weighted_contribution 
      ON ysws_projects (((fields->>'YSWS–Weighted Project Contribution')::float))
      WHERE fields ? 'YSWS–Weighted Project Contribution'
    }

    # Add a spatial index specifically for the ST_Contains operation
    # This will dramatically speed up the spatial join
    execute %{
      CREATE INDEX index_congressional_districts_boundary_gist_geometry 
      ON congressional_districts USING GIST (ST_GeomFromEWKB(boundary::geometry))
    }

    execute %{
      CREATE INDEX index_ysws_projects_location_gist_geometry 
      ON ysws_projects USING GIST (ST_GeomFromEWKB(location::geometry))
    }
  end

  def down
    execute "DROP INDEX IF EXISTS index_ysws_projects_on_weighted_contribution"
    execute "DROP INDEX IF EXISTS index_congressional_districts_boundary_gist_geometry"
    execute "DROP INDEX IF EXISTS index_ysws_projects_location_gist_geometry"
  end
end
