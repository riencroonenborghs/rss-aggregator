class AddFetchStateToSources < ActiveRecord::Migration[8.1]
  def change
    add_column :sources, :last_fetched_at, :datetime
    add_column :sources, :last_error, :text
    add_column :sources, :last_error_at, :datetime
    add_column :sources, :etag, :string
    add_column :sources, :last_modified, :string
  end
end
