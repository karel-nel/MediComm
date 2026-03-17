class AddArchivedAtToIntakeFieldGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :intake_field_groups, :archived_at, :datetime
    add_index :intake_field_groups, [ :intake_flow_id, :archived_at ]
  end
end
