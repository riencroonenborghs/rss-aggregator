class AddDuplicateDetectionToEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :entries, :normalised_link, :string
    add_reference :entries, :duplicate_of, foreign_key: { to_table: :entries }
    add_index :entries, :normalised_link

    # Backfill so Entries stored before this change can be matched too.
    Entry.reset_column_information
    Entry.where.not(link: nil).find_each do |entry|
      entry.update_column(:normalised_link, Entry.normalise_link(entry.link))
    end
  end

  def down
    remove_index :entries, :normalised_link
    remove_reference :entries, :duplicate_of, foreign_key: { to_table: :entries }
    remove_column :entries, :normalised_link
  end
end
