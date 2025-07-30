class CreateCallbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :callbacks do |t|
      t.string :name
      t.text :description
      t.jsonb :example_response
      t.jsonb :request_schema
      t.jsonb :response_schema
      t.boolean :active

      t.timestamps
    end
  end
end
