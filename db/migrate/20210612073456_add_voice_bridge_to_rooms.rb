class AddVoiceBridgeToRooms < ActiveRecord::Migration[5.2]
  def change
    add_column :rooms, :voice_bridge, :integer, null: true, default: nil
    add_index :rooms, :voice_bridge
  end
end
