class CreateProjection < ActiveRecord::Migration[8.0]
  def change
    create_table :positions do |table|
      table.string :account, null: false
      table.string :commodity, null: false
      table.bigint :quantity, null: false, default: 0
    end
    add_index :positions, [:account, :commodity], unique: true

    create_table :processed_executions, id: false do |table|
      table.string :execution_id, null: false, primary_key: true
    end
  end
end
