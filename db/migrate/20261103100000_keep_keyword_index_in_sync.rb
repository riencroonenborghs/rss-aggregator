# frozen_string_literal: true

# Keeps the Keyword index in step with Entries as they're updated and deleted,
# including by `delete_all` and `update_all`, which skip model callbacks. See
# docs/adr/0002-keyword-matching-with-sqlite-fts5.md.
class KeepKeywordIndexInSync < ActiveRecord::Migration[8.1]
  def up
    # An external-content index removes a row by being told the values it
    # indexed, so both triggers pass the old title and plain text.
    execute <<~SQL
      CREATE TRIGGER entries_fts_after_delete AFTER DELETE ON entries BEGIN
        INSERT INTO entries_fts (entries_fts, rowid, title, plain_text) VALUES ('delete', old.id, old.title, old.plain_text);
      END
    SQL

    # Only changes to indexed text touch the index, so re-pointing Duplicates
    # (as Source removal does) costs nothing.
    execute <<~SQL
      CREATE TRIGGER entries_fts_after_update AFTER UPDATE OF title, plain_text ON entries BEGIN
        INSERT INTO entries_fts (entries_fts, rowid, title, plain_text) VALUES ('delete', old.id, old.title, old.plain_text);
        INSERT INTO entries_fts (rowid, title, plain_text) VALUES (new.id, new.title, new.plain_text);
      END
    SQL

    # Entries updated or deleted before these triggers existed left the index
    # out of step; a 'delete' with values it never indexed would corrupt it.
    # Rebuild it from the entries table.
    execute "INSERT INTO entries_fts (entries_fts) VALUES ('rebuild')"
  end

  def down
    execute "DROP TRIGGER IF EXISTS entries_fts_after_update"
    execute "DROP TRIGGER IF EXISTS entries_fts_after_delete"
  end
end
