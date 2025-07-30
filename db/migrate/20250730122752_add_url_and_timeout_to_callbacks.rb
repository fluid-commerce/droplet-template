class AddUrlAndTimeoutToCallbacks < ActiveRecord::Migration[8.0]
  def change
    add_column :callbacks, :url, :string
    add_column :callbacks, :timeout_in_seconds, :integer
  end
end
