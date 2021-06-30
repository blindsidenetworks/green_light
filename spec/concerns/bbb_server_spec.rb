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

require "rails_helper"
require 'bigbluebutton_api'

describe BbbServer do
  include BbbServer

  let(:bbb_server) { BigBlueButton::BigBlueButtonApi.new("http://bbb.example.com/bigbluebutton/api", "secret", "0.8") }

  before do
    @settings = Setting.find_or_create_by(provider: "provider1")
    @user = create(:user)
    @room = @user.main_room
  end

  context "#running?" do
    it "should return false when not running" do
      expect(room_running?(@room.bbb_id)).to be false
    end

    it "should return true when running" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)
      expect(room_running?(@room.bbb_id)).to be true
    end
  end

  context "#start_session" do
    it "should update latest session info" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:create_meeting).and_return(
        messageKey: "",
        createTime: "1611793449622"
      )

      expect do
        start_session(@room)
      end.to change { @room.sessions }.by(1)

      expect(@room.last_session).not_to be nil
    end
  end

  context "#join_path" do
    it "should return correct join URL for user" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:get_meeting_info).and_return(
        attendeePW: @room.attendee_pw,
      )
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:create_meeting).and_return(
        messageKey: "",
        createTime: "1611793449622"
      )

      endpoint = Rails.configuration.bigbluebutton_endpoint
      secret = Rails.configuration.bigbluebutton_secret
      fullname = "&fullName=Example"
      join_via_html5 = "&join_via_html5=true"
      meeting_id = "&meetingID=#{@room.bbb_id}"
      password = "&password=#{@room.attendee_pw}"
      time = "createTime=1611793449622"

      query = time + fullname + join_via_html5 + meeting_id + password
      checksum_string = "join#{query + secret}"

      checksum = OpenSSL::Digest.digest('sha1', checksum_string).unpack1("H*")
      expect(join_path(@room, "Example")).to eql("#{endpoint}join?#{query}&checksum=#{checksum}")
    end
  end

  context "#recordings" do
    it "publishes a recording" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:publish_recordings).and_return(
        returncode: true, published: true
      )

      expect(publish_recording(Faker::IDNumber.valid))
        .to contain_exactly([:returncode, true], [:published, true])
    end

    it "unpublishes a recording" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:publish_recordings).and_return(
        returncode: true, published: false
      )

      expect(unpublish_recording(Faker::IDNumber.valid))
        .to contain_exactly([:returncode, true], [:published, false])
    end

    it "deletes the recording" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:delete_recordings).and_return(
        returncode: true, deleted: true
      )

      expect(delete_recording(Faker::IDNumber.valid))
        .to contain_exactly([:returncode, true], [:deleted, true])
    end
  end
end
