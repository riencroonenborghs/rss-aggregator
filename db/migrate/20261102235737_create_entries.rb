# frozen_string_literal: true

class CreateEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :entries do |t|
      t.references :source, null: false, foreign_key: true
      t.string :identifier, null: false
      t.string :title
      t.string :link
      t.string :author
      t.datetime :published_at, null: false
      t.datetime :first_seen_at, null: false
      t.text :summary
      t.text :content

      t.timestamps
    end

    add_index :entries, [ :source_id, :identifier ], unique: true
    add_index :entries, :published_at
  end
end
