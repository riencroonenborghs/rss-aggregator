# frozen_string_literal: true

class AddNormalisedTitleToEntries < ActiveRecord::Migration[8.1]
  def up
    add_column :entries, :normalised_title, :string

    # Backfill so Entries stored before this change can be matched too.
    Entry.reset_column_information
    Entry.where.not(title: nil).find_each do |entry|
      entry.update_column(:normalised_title, Entry.normalise_title(entry.title))
    end
  end

  def down
    remove_column :entries, :normalised_title
  end
end
