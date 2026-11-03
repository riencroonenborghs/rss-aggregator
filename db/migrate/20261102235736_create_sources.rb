# frozen_string_literal: true

class CreateSources < ActiveRecord::Migration[8.1]
  def change
    create_table :sources do |t|
      t.string :url, null: false, index: { unique: true }
      t.string :name

      t.timestamps
    end
  end
end
