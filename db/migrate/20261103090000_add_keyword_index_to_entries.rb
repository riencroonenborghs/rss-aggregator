# frozen_string_literal: true

# Adds the full-text index behind Keywords. See
# docs/adr/0002-keyword-matching-with-sqlite-fts5.md.
class AddKeywordIndexToEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :entries, :plain_text, :text

    create_virtual_table :entries_fts, :fts5, [
      "title", "plain_text",
      "content='entries'", "content_rowid='id'",
      "tokenize='unicode61 remove_diacritics 2'"
    ]

    execute <<~SQL
      CREATE TRIGGER entries_fts_after_insert AFTER INSERT ON entries BEGIN
        INSERT INTO entries_fts (rowid, title, plain_text) VALUES (new.id, new.title, new.plain_text);
      END
    SQL

    # Backfill so Entries stored before this change can be matched too, then
    # index every Entry, including ones inserted before the trigger existed.
    Entry.reset_column_information
    Entry.find_each do |entry|
      entry.update_column(:plain_text, Entry.plain_text_of(entry.content.presence || entry.summary))
    end
    execute "INSERT INTO entries_fts (entries_fts) VALUES ('rebuild')"
  end

  def down
    execute "DROP TRIGGER IF EXISTS entries_fts_after_insert"
    drop_virtual_table :entries_fts, :fts5, []
    remove_column :entries, :plain_text
  end
end
