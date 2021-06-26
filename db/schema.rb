# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2021_01_26_001733) do

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "features", force: :cascade do |t|
    t.integer "setting_id"
    t.string "name", null: false
    t.string "value"
    t.boolean "enabled", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_features_on_name"
    t.index ["setting_id"], name: "index_features_on_setting_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email", null: false
    t.string "provider", null: false
    t.string "invite_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invite_token"], name: "index_invitations_on_invite_token"
    t.index ["provider"], name: "index_invitations_on_provider"
  end

  create_table "role_permissions", force: :cascade do |t|
    t.string "name"
    t.string "value", default: ""
    t.boolean "enabled", default: false
    t.integer "role_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name"
    t.integer "priority", default: 9999
    t.boolean "can_create_rooms", default: false
    t.boolean "send_promoted_email", default: false
    t.boolean "send_demoted_email", default: false
    t.boolean "can_edit_site_settings", default: false
    t.boolean "can_edit_roles", default: false
    t.boolean "can_manage_users", default: false
    t.string "colour"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "provider"], name: "index_roles_on_name_and_provider", unique: true
    t.index ["name"], name: "index_roles_on_name"
    t.index ["priority", "provider"], name: "index_roles_on_priority_and_provider", unique: true
  end

  create_table "rooms", force: :cascade do |t|
    t.integer "user_id"
    t.string "name"
    t.string "uid"
    t.string "bbb_id"
    t.integer "sessions", default: 0
    t.datetime "last_session"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "room_settings", default: "{ }"
    t.string "moderator_pw"
    t.string "attendee_pw"
    t.string "access_code"
    t.boolean "deleted", default: false, null: false
    t.string "moderator_access_code"
    t.index ["bbb_id"], name: "index_rooms_on_bbb_id"
    t.index ["deleted"], name: "index_rooms_on_deleted"
    t.index ["last_session"], name: "index_rooms_on_last_session"
    t.index ["name"], name: "index_rooms_on_name"
    t.index ["sessions"], name: "index_rooms_on_sessions"
    t.index ["uid"], name: "index_rooms_on_uid"
    t.index ["user_id"], name: "index_rooms_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "provider", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider"], name: "index_settings_on_provider"
  end

  create_table "shared_accesses", force: :cascade do |t|
    t.integer "room_id"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_shared_accesses_on_room_id"
    t.index ["user_id"], name: "index_shared_accesses_on_user_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.string "name"
    t.string "value", default: ""
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "room_id"
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "username"
    t.string "email"
    t.string "social_uid"
    t.string "image"
    t.string "password_digest"
    t.boolean "accepted_terms", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "email_verified", default: false
    t.string "language", default: "default"
    t.string "reset_digest"
    t.datetime "reset_sent_at"
    t.string "activation_digest"
    t.datetime "activated_at"
    t.boolean "deleted", default: false, null: false
    t.integer "role_id"
    t.datetime "last_login"
    t.index ["created_at"], name: "index_users_on_created_at"
    t.index ["deleted"], name: "index_users_on_deleted"
    t.index ["email"], name: "index_users_on_email"
    t.index ["password_digest"], name: "index_users_on_password_digest", unique: true
    t.index ["provider"], name: "index_users_on_provider"
    t.index ["role_id"], name: "index_users_on_role_id"
    t.index ["room_id"], name: "index_users_on_room_id"
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "role_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

end
