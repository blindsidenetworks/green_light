# frozen_string_literal: true

namespace :voice_bridge do
  desc "Initialize voice_bridge values automatically"
  task :init, [] => :environment do |_task, args|
    # Initialize voice_bridge if needed
    if Rails.configuration.room_features.include? "phone-call"
        Room.find_each do |room|
            room.update_attributes(voice_bridge: Room.generate_voice_bridge()) if room.voice_bridge.blank?
        end
    else
        Room.find_each do |room|
            room.update_attributes(voice_bridge: nil)
        end
    end
  end
end