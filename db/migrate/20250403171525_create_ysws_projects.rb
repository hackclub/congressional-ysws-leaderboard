class CreateYswsProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :ysws_projects, id: false do |t|
      t.string :airtable_id, null: false, primary_key: true
      t.jsonb :fields, null: false, default: {}
      t.st_point :location, geographic: true

      t.timestamps
    end

    add_index :ysws_projects, :location, using: :gist
    add_index :ysws_projects, :fields, using: :gin
  end
end
