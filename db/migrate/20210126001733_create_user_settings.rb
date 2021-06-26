# frozen_string_literal: true

class CreateUserSettings < ActiveRecord::Migration[5.2]
  def change
    create_table :user_settings do |t|
      t.string :name
      t.string :value, default: ""
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
