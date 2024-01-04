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

ActiveRecord::Schema[7.1].define(version: 0) do
  create_table "duplicate_url_reports", id: { type: :integer }, charset: "utf8", force: :cascade do |t|
    t.text "other_pids", null: false
    t.datetime "last_checked", precision: nil
    t.integer "pid_id"
    t.index ["pid_id"], name: "index_duplicate_url_reports_pid"
  end

  create_table "groups", id: { type: :string, limit: 10 }, charset: "utf8", force: :cascade do |t|
    t.string "name", limit: 200, null: false
    t.string "description", limit: 250
    t.string "host", limit: 30
  end

  create_table "interesteds", primary_key: ["group_id", "pid_id"], charset: "utf8", force: :cascade do |t|
    t.string "group_id", limit: 10, null: false
    t.integer "pid_id", null: false
    t.index ["group_id"], name: "index_interesteds_group"
    t.index ["pid_id"], name: "index_interesteds_pid"
  end

  create_table "invalid_url_reports", id: { type: :integer }, charset: "utf8", force: :cascade do |t|
    t.integer "http_code", null: false
    t.datetime "last_checked", precision: nil
    t.integer "pid_id"
    t.index ["pid_id"], name: "index_invalid_url_reports_pid"
  end

  create_table "maintainers", primary_key: ["group_id", "user_id"], charset: "utf8", force: :cascade do |t|
    t.string "group_id", limit: 10, null: false
    t.integer "user_id", null: false
    t.index ["group_id"], name: "index_maintainers_group"
    t.index ["user_id"], name: "index_maintainers_user"
  end

  create_table "pid_versions", id: { type: :integer }, charset: "utf8", force: :cascade do |t|
    t.boolean "deactivated", default: false
    t.string "change_category", limit: 20, null: false
    t.string "url", limit: 2000, null: false
    t.string "username", limit: 20, null: false
    t.string "group", limit: 20
    t.datetime "created_at", precision: nil, null: false
    t.string "notes", limit: 250
    t.string "host", limit: 30
    t.integer "pid_id", null: false
    t.index ["pid_id"], name: "index_pid_versions_pid"
  end

  create_table "pids", id: { type: :integer }, charset: "utf8", force: :cascade do |t|
    t.boolean "deactivated", default: false
    t.string "change_category", limit: 20, null: false
    t.string "url", limit: 2000, null: false
    t.string "username", limit: 50, null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "modified_at", precision: nil, null: false
    t.string "notes", limit: 250
    t.string "host", limit: 30
    t.string "group_id", limit: 10, null: false
    t.integer "invalid_url_report_id"
    t.integer "duplicate_url_report_id"
    t.index ["created_at"], name: "index_pids_created_at"
    t.index ["deactivated"], name: "index_pids_deactivated"
    t.index ["duplicate_url_report_id"], name: "index_pids_duplicate_url_report"
    t.index ["group_id"], name: "index_pids_group"
    t.index ["invalid_url_report_id"], name: "index_pids_invalid_url_report"
    t.index ["modified_at"], name: "index_pids_modified_at"
  end

  create_table "skip_checks", primary_key: "domain", id: { type: :string, limit: 50 }, charset: "utf8", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "group", limit: 10
    t.index ["created_at"], name: "index_skip_checks_created_at"
  end

  create_table "users", id: { type: :integer }, charset: "utf8", force: :cascade do |t|
    t.string "login", limit: 20, null: false
    t.string "name", limit: 100, null: false
    t.string "email", limit: 100, null: false
    t.string "affiliation", limit: 100
    t.boolean "active", default: true
    t.boolean "locked", default: false
    t.integer "locked_timer"
    t.integer "failed_login_attempts", default: 0
    t.date "last_login"
    t.integer "reset_attempts", default: 0
    t.string "reset_code", limit: 50
    t.integer "reset_timer"
    t.boolean "super", default: false
    t.string "hashed_password", limit: 50, null: false
    t.string "salt", limit: 50, null: false
    t.datetime "created_at", precision: nil
    t.string "host", limit: 30
    t.boolean "read_only", default: false
    t.string "group_id", limit: 10
    t.index ["group_id"], name: "index_users_group"
    t.index ["login"], name: "unique_users_login", unique: true
  end

  # add_foreign_key "duplicate_url_reports", "pids", name: "duplicate_url_reports_pid_fk"
  # add_foreign_key "interesteds", "groups", name: "interesteds_group_fk"
  # add_foreign_key "interesteds", "pids", name: "interesteds_pid_fk"
  # add_foreign_key "invalid_url_reports", "pids", name: "invalid_url_reports_pid_fk"
  # add_foreign_key "maintainers", "groups", name: "maintainers_group_fk"
  # add_foreign_key "maintainers", "users", name: "maintainers_user_fk"
  # add_foreign_key "pid_versions", "pids", name: "pid_versions_pid_fk"
  # add_foreign_key "pids", "duplicate_url_reports", name: "pids_duplicate_url_report_fk"
  # add_foreign_key "pids", "groups", name: "pids_group_fk"
  # add_foreign_key "pids", "invalid_url_reports", name: "pids_invalid_url_report_fk"
  # add_foreign_key "users", "groups", name: "users_group_fk"
end