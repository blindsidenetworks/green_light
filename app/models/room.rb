# frozen_string_literal: true

# BigBlueButton open source conferencing system - http://www.bigbluebutton.org/.
#
# Copyright (c) 2018 BigBlueButton Inc. and by respective authors (see below).
#
# This program is free software; you can redistribute it and/or modify it under the
# terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 3.0 of the License, or (at your option) any later
# version.
#
# BigBlueButton is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along
# with BigBlueButton; if not, see <http://www.gnu.org/licenses/>.

require 'bbb_api'
require 'sha3'

class Room < ApplicationRecord
  include Deleteable

  before_create :setup

  before_destroy :destroy_presentation

  validates :name, presence: true

  belongs_to :owner, class_name: 'User', foreign_key: :user_id
  has_many :shared_access

  has_one_attached :presentation

  class << self
    include Queries

    def admins_search(string)
      like = like_text
      search_query = "rooms.name #{like} :search OR rooms.uid #{like} :search OR users.email #{like} :search" \
      " OR users.#{created_at_text} #{like} :search"

      search_param = "%#{sanitize_sql_like(string)}%"
      where(search_query, search: search_param)
    end

    def admins_order(column, direction, running_ids)
      # Include the owner of the table
      table = joins(:owner)

      # Rely on manual ordering if trying to sort by status
      return order_by_status(table, running_ids) if column == "status"

      return table.order(Arel.sql("COALESCE(rooms.last_session,rooms.created_at) DESC")) if column == "created_at"

      return table.order(Arel.sql("rooms.#{column} #{direction}")) if table.column_names.include?(column)

      return table.order(Arel.sql("#{column} #{direction}")) if column == "users.name"

      table
    end
  end

  # Determines if a user owns a room.
  def owned_by?(user)
    user_id == user&.id
  end

  def shared_users
    User.where(id: shared_access.pluck(:user_id))
  end

  def shared_with?(user)
    return false if user.nil?
    shared_users.include?(user)
  end

  # Determines the invite path for the room.
  def invite_path
    "#{Rails.configuration.relative_url_root}/#{CGI.escape(uid)}"
  end

  # Notify waiting users that a meeting has started.
  def notify_waiting
    ActionCable.server.broadcast("#{uid}_waiting_channel", action: "started")
  end

  def phone_pin
    (SHA3::Digest.hexdigest(:sha224, uid).unpack("n").first % 100000).to_s.rjust(5, "1")
  end

  # Return table with the running rooms first
  def self.order_by_status(table, ids)
    return table if ids.blank?

    # Get active rooms first
    active_rooms = table.where(bbb_id: ids)

    # Get other rooms sorted by last session date || created at date (whichever is higher)
    inactive_rooms = table.where.not(bbb_id: ids).order("COALESCE(rooms.last_session,rooms.created_at) DESC")

    active_rooms + inactive_rooms
  end

  private

  # Generates a uid for the room and BigBlueButton.
  def setup
    self.uid = random_room_uid
    self.bbb_id = unique_bbb_id
    self.moderator_pw = RandomPassword.generate(length: 12)
    self.attendee_pw = RandomPassword.generate(length: 12)
  end

  # Generates a fully random room uid.
  def random_room_uid
    # 6 character long random string of chars from a..z and 0..9
    full_chunk = SecureRandom.alphanumeric(9).downcase

    [owner.name_chunk, full_chunk[0..2], full_chunk[3..5], full_chunk[6..8]].join("-")
  end

  # Generates a unique bbb_id based on uuid.
  def unique_bbb_id
    loop do
      bbb_id = SecureRandom.alphanumeric(40).downcase
      break bbb_id unless Room.exists?(bbb_id: bbb_id)
    end
  end

  # Before destroying the room, make sure you also destroy the presentation attached
  def destroy_presentation
    presentation.purge if presentation.attached?
  end
end
