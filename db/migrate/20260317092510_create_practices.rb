class CreatePractices < ActiveRecord::Migration[8.1]
  def change
    create_table :practices do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :timezone, null: false, default: "Africa/Johannesburg"
      t.string :contact_email, null: false
      t.string :status, null: false, default: "active"

      t.timestamps null: false
    end

    add_index :practices, :slug, unique: true
    add_index :practices, :status
  end
end
