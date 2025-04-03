class AddAdditionalSpatialIndexes < ActiveRecord::Migration[8.0]
  def up
    # Create a more efficient spatial index specifically for the ST_Intersects operation
    execute %{
      CREATE INDEX index_congressional_districts_on_boundary_geom
      ON congressional_districts USING GIST (ST_GeomFromEWKB(boundary));
    }

    execute %{
      CREATE INDEX index_ysws_projects_on_location_geom  
      ON ysws_projects USING GIST (ST_GeomFromEWKB(location));
    }
    
    # Update statistics for the query planner
    execute "ANALYZE"
  end

  def down
    execute "DROP INDEX IF EXISTS index_congressional_districts_on_boundary_geom"
    execute "DROP INDEX IF EXISTS index_ysws_projects_on_location_geom"
  end
end
