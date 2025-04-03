class AddBoundingBoxIndexes < ActiveRecord::Migration[8.0]
  def up
    # Add an index for the bounding box operator (&&) to make it ultra-fast
    execute %{
      CREATE INDEX index_congressional_districts_boundary_bbox
      ON congressional_districts USING GIST (ST_Expand(boundary::geometry, 0));
    }

    execute %{
      CREATE INDEX index_ysws_projects_location_bbox
      ON ysws_projects USING GIST (ST_Expand(location::geometry, 0))
      WHERE location IS NOT NULL;
    }

    # Add a partial index to quickly find projects with valid locations
    execute %{
      CREATE INDEX index_ysws_projects_with_location
      ON ysws_projects (airtable_id)
      WHERE location IS NOT NULL;
    }
    
    # Update statistics
    execute "ANALYZE"
  end

  def down
    execute "DROP INDEX IF EXISTS index_congressional_districts_boundary_bbox"
    execute "DROP INDEX IF EXISTS index_ysws_projects_location_bbox"
    execute "DROP INDEX IF EXISTS index_ysws_projects_with_location"
  end
end
