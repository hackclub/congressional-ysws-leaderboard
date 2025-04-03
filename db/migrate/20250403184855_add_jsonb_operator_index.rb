class AddJsonbOperatorIndex < ActiveRecord::Migration[8.0]
  def up
    # Create a GIN index for JSON path operations and ? containment operator
    execute %{
      CREATE INDEX index_ysws_projects_weighted_contribution_path
      ON ysws_projects USING GIN ((fields -> 'YSWS–Weighted Project Contribution'));
    }
    
    # Create a partial index for records that have the weighted contribution field
    execute %{
      CREATE INDEX index_ysws_projects_has_weighted_contribution
      ON ysws_projects (airtable_id) 
      WHERE fields ? 'YSWS–Weighted Project Contribution';
    }
    
    # Update statistics
    execute "ANALYZE"
  end

  def down
    execute "DROP INDEX IF EXISTS index_ysws_projects_weighted_contribution_path"
    execute "DROP INDEX IF EXISTS index_ysws_projects_has_weighted_contribution"
  end
end
