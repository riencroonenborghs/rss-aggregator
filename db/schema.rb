# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_03_004235) do
  create_table "entries", force: :cascade do |t|
    t.integer "source_id", null: false
    t.string "identifier", null: false
    t.string "title"
    t.string "link"
    t.string "author"
    t.datetime "published_at", null: false
    t.datetime "first_seen_at", null: false
    t.text "summary"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "normalised_link"
    t.integer "duplicate_of_id"
    t.string "normalised_title"
    t.index ["duplicate_of_id"], name: "index_entries_on_duplicate_of_id"
    t.index ["normalised_link"], name: "index_entries_on_normalised_link"
    t.index ["published_at"], name: "index_entries_on_published_at"
    t.index ["source_id", "identifier"], name: "index_entries_on_source_id_and_identifier", unique: true
    t.index ["source_id"], name: "index_entries_on_source_id"
  end

  create_table "sources", force: :cascade do |t|
    t.string "url", null: false
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_fetched_at"
    t.text "last_error"
    t.datetime "last_error_at"
    t.string "etag"
    t.string "last_modified"
    t.index ["url"], name: "index_sources_on_url", unique: true
  end

  add_foreign_key "entries", "entries", column: "duplicate_of_id"
  add_foreign_key "entries", "sources"
end
