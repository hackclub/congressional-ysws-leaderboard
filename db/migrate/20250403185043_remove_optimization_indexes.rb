class RemoveOptimizationIndexes < ActiveRecord::Migration[8.0]
  def up
    # Drop all the optimization indexes we added
    
    # From AddBoundingBoxIndexes migration
    execute "DROP INDEX IF EXISTS index_congressional_districts_boundary_bbox"
    execute "DROP INDEX IF EXISTS index_ysws_projects_location_bbox"
    execute "DROP INDEX IF EXISTS index_ysws_projects_with_location"
    
    # From AddJsonbOperatorIndex migration
    execute "DROP INDEX IF EXISTS index_ysws_projects_weighted_contribution_path"
    execute "DROP INDEX IF EXISTS index_ysws_projects_has_weighted_contribution"
    
    # From AddAdditionalSpatialIndexes migration
    execute "DROP INDEX IF EXISTS index_congressional_districts_on_boundary_geom"
    execute "DROP INDEX IF EXISTS index_ysws_projects_on_location_geom"
    
    # From AddLeaderboardIndexes migration
    execute "DROP INDEX IF EXISTS index_ysws_projects_on_weighted_contribution"
    
    # Update statistics
    execute "ANALYZE"
  end

  def down
    # This is a one-way migration - we don't provide a way to recreate the indexes
    # as they would be handled by the original migrations
    raise ActiveRecord::IrreversibleMigration
  end
end
