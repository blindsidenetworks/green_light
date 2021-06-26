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

def random_valid_room_params
  {
    room: {
      name: Faker::Name.first_name,
      auto_join: false,
    },
  }
end

describe RoomsController, type: :controller do
  include Recorder
  include BbbServer

  let(:bbb_server) { BigBlueButton::BigBlueButtonApi.new("http://bbb.example.com/bigbluebutton/api", "secret", "0.8") }

  describe "GET #show" do
    before do
      @user = create(:user)
      @owner = create(:user)
    end

    it "should fetch recordings and room state if user is owner" do
      @request.session[:user_id] = @owner.id

      get :show, params: { room_uid: @owner.main_room }

      expect(assigns(:recordings)).to eql(recordings(@owner.main_room.bbb_id))
    end

    it "should be able to search recordings if user is owner" do
      @request.session[:user_id] = @owner.id

      get :show, params: { room_uid: @owner.main_room, search: :none }

      expect(assigns(:recordings)).to eql([])
    end

    it "should render join if user is not owner" do
      @request.session[:user_id] = @user.id

      get :show, params: { room_uid: @owner.main_room }

      expect(response).to render_template(:join)
    end

    it "should be able to search public recordings if user is not owner" do
      @request.session[:user_id] = @user.id

      get :show, params: { room_uid: @owner.main_room, search: :none }

      expect(assigns(:recordings)).to eql(nil)
    end

    it "should raise if room is not valid" do
      expect do
        get :show, params: { room_uid: "non_existent" }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "redirects to root if owner of room is not verified" do
      allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)
      @owner.update_attribute(:email_verified, false)

      post :show, params: { room_uid: @owner.main_room }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "sets the join name to cookie[:greenlight_name] if it exists" do
      name = Faker::Games::Pokemon.name
      @request.cookies[:greenlight_name] = name

      get :show, params: { room_uid: @owner.main_room }

      expect(assigns(:name)).to eql(name)
    end

    it "sets the join name to blank if user isnt signed in" do
      get :show, params: { room_uid: @owner.main_room }

      expect(assigns(:name)).to eql("")
    end

    it "redirects to admin if user is a super_admin" do
      @request.session[:user_id] = @owner.id
      @owner.set_role :super_admin

      get :show, params: { room_uid: @owner.main_room, search: :none }

      expect(response).to redirect_to(admins_path)
    end

    it "redirects to root if the providers dont match" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(BbbServer).to receive(:room_running?).and_return(true)

      @owner.update_attribute(:provider, "provider1")
      @user.update_attribute(:provider, "provider2")

      @request.session[:user_id] = @user.id
      get :show, params: { room_uid: @owner.main_room }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "redirects to root if owner is pending" do
      @request.session[:user_id] = @owner.id
      @owner.set_role :pending

      get :show, params: { room_uid: @owner.main_room, search: :none }

      expect(response).to redirect_to(root_path)
    end

    it "redirects to root if owner is banned" do
      @request.session[:user_id] = @owner.id
      @owner.set_role :denied

      get :show, params: { room_uid: @owner.main_room, search: :none }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #cant_create_rooms" do
    before do
      @user = create(:user)
      @owner = create(:user)
    end

    it "renders cant_create_rooms if user doesn't have permission to create rooms and has no shared rooms" do
      @user.role.update_permission("can_create_rooms", "false")

      @request.session[:user_id] = @user.id

      get :cant_create_rooms

      expect(response).to render_template(:cant_create_rooms)
    end

    it "displays the room if the user can't create rooms but has a shared room" do
      @user.role.update_permission("can_create_rooms", "false")

      SharedAccess.create(room_id: @owner.main_room.id, user_id: @user.id)

      @request.session[:user_id] = @user.id

      get :cant_create_rooms

      expect(response).to redirect_to(@owner.main_room)
    end
  end

  describe "POST #create" do
    before do
      @owner = create(:user)
    end

    it "should create room with name and correct settings" do
      @request.session[:user_id] = @owner.id
      name = Faker::Games::Pokemon.name

      room_params = { name: name, mute_on_join: "1",
        require_moderator_approval: "1", anyone_can_start: "1", all_join_moderator: "1" }
      json_room_settings = "{\"muteOnStart\":true,\"requireModeratorApproval\":true," \
        "\"anyoneCanStart\":true,\"joinModerator\":true,\"recording\":false,\"requireAuthenticationToJoin\":false}"

      post :create, params: { room: room_params }

      r = @owner.rooms.last
      expect(r.name).to eql(name)
      expect(r.owner).to eql(@owner)
      expect(r.room_settings).to eql(json_room_settings)
      expect(response).to redirect_to(r)
    end

    it "should respond with JSON object of the room_settings" do
      @request.session[:user_id] = @owner.id

      @owner.main_room.update_attribute(:room_settings, { muteOnStart: true, requireModeratorApproval: true,
      anyoneCanStart: true, joinModerator: true }.to_json)

      json_room_settings = { "anyoneCanStart" => true,
                             "joinModerator" => true,
                             "muteOnStart" => true,
                             "requireModeratorApproval" => true }

      get :room_settings, params: { room_uid: @owner.main_room }, format: :json

      expect(JSON.parse(response.body)).to eql(json_room_settings)
    end

    it "should redirect to root if not logged in" do
      expect do
        name = Faker::Games::Pokemon.name
        post :create, params: { room: { name: name } }
      end.to change { Room.count }.by(0)

      expect(response).to redirect_to(root_path)
    end

    it "should redirect back to main room with error if it fails" do
      @request.session[:user_id] = @owner.id

      room_params = { name: "", mute_on_join: "1" }

      post :create, params: { room: room_params }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(@owner.main_room)
    end

    it "redirects to main room if room limit is reached" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return(1)

      @request.session[:user_id] = @owner.id

      room_params = { name: Faker::Games::Pokemon.name, mute_on_join: "1" }

      post :create, params: { room: room_params }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(@owner.main_room)
    end
  end

  describe "POST #join" do
    before do
      @user = create(:user)
      @owner = create(:user)
      @room = @owner.main_room
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:create_meeting).and_return(
        messageKey: "",
        createTime: "1611793449622"
      )
    end

    it "should use account name if user is logged in and meeting running" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: @room, join_name: @user.name }

      expect(response).to redirect_to(join_path(@owner.main_room, @user.name, {}, @user.uid))
    end

    it "should use join name if user is not logged in and meeting running" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)
      post :join, params: { room_uid: @room, join_name: "Join Name" }

      expect(response).to redirect_to(join_path(@owner.main_room, "Join Name", {}, response.cookies["guest_id"]))
    end

    it "should use join name if user is not logged in and meeting running and moderator access code is enabled and set" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)
      allow_any_instance_of(Setting).to receive(:get_value).and_call_original
      allow_any_instance_of(Setting).to receive(:get_value)
        .with("Room Configuration Moderator Access Codes").and_return("optional")

      room = Room.new(name: "test", moderator_access_code: "abcdef")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      post :join, params: { room_uid: room, join_name: "Join Name" }, session: { moderator_access_code: "abcdef" }

      expect(response).to redirect_to(join_path(room, "Join Name", { user_is_moderator: true }, response.cookies["guest_id"]))
    end

    it "should render wait if meeting isn't running" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: @room, join_name: @user.name }

      expect(response).to render_template(:wait)
    end

    it "should join the room if the room has the anyone_can_start setting" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)
      allow_any_instance_of(Setting).to receive(:get_value).and_return("optional")

      room = Room.new(name: "test")
      room.room_settings = "{\"muteOnStart\":false,\"joinViaHtml5\":false,\"anyoneCanStart\":true}"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to redirect_to(join_path(room, @user.name, { user_is_moderator: false }, @user.uid))
    end

    it "doesn't join the room if the room has the anyone_can_start setting but config is disabled" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)
      allow_any_instance_of(Setting).to receive(:get_value).and_return("disabled")

      room = Room.new(name: "test")
      room.room_settings = "{\"muteOnStart\":false,\"joinViaHtml5\":false,\"anyoneCanStart\":true}"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to render_template(:wait)
    end

    it "joins the room if the room doesn't have the anyone_can_start setting but config is set to enabled" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)
      allow_any_instance_of(Setting).to receive(:get_value).and_return("enabled")

      room = Room.new(name: "test")
      room.room_settings = "{\"anyoneCanStart\":false}"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to redirect_to(join_path(room, @user.name, { user_is_moderator: true }, @user.uid))
    end

    it "joins the room as moderator if room has the all_join_moderator setting" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return("optional")
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      room = Room.new(name: "test")
      room.room_settings = "{\"joinModerator\":true}"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to redirect_to(join_path(room, @user.name, { user_is_moderator: true }, @user.uid))
    end

    it "joins the room as moderator if room doesn't have all_join_moderator but config is set to enabled" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return("enabled")
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      room = Room.new(name: "test")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to redirect_to(join_path(room, @user.name, { user_is_moderator: true }, @user.uid))
    end

    it "doesn't join the room as moderator if room has the all_join_moderator setting but config is set to disabled" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return("disabled")
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      room = Room.new(name: "test")
      room.room_settings = "{\"joinModerator\":true}"
      room.owner = @owner
      room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: room, join_name: @user.name }

      expect(response).to redirect_to(join_path(room, @user.name, { user_is_moderator: false }, @user.uid))
    end

    it "should render wait if the correct access code is supplied" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)

      protected_room = Room.new(name: 'test', access_code: "123456")
      protected_room.owner = @owner
      protected_room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: protected_room, join_name: @user.name }, session: { access_code: "123456" }

      expect(response).to render_template(:wait)
    end

    it "should redirect to login if the correct access code isn't supplied" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(false)

      protected_room = Room.new(name: 'test', access_code: "123456")
      protected_room.owner = @owner
      protected_room.save

      @request.session[:user_id] = @user.id
      post :join, params: { room_uid: protected_room, join_name: @user.name }, session: { access_code: "123455" }

      expect(response).to redirect_to room_path(protected_room.uid)
    end

    it "should join the room as moderator if the user has the moderator_access code (and regular access code is not set)" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)
      allow_any_instance_of(Setting).to receive(:get_value).and_call_original
      allow_any_instance_of(Setting).to receive(:get_value)
        .with("Room Configuration Moderator Access Codes").and_return("optional")

      room = Room.new(name: "test", moderator_access_code: "abcdef")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      post :join, params: { room_uid: room, join_name: "Join Name" }, session: { moderator_access_code: "abcdef" }

      expect(response).to redirect_to(join_path(room, "Join Name", { user_is_moderator: true }, response.cookies["guest_id"]))
    end

    it "should join the room as moderator if the user has the moderator_access code (and regular access code is set)" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)
      allow_any_instance_of(Setting).to receive(:get_value).and_call_original
      allow_any_instance_of(Setting).to receive(:get_value)
        .with("Room Configuration Moderator Access Codes").and_return("optional")

      room = Room.new(name: "test", access_code: "123456", moderator_access_code: "abcdef")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      post :join, params: { room_uid: room, join_name: "Join Name" }, session: { moderator_access_code: "abcdef" }

      expect(response).to redirect_to(join_path(room, "Join Name", { user_is_moderator: true }, response.cookies["guest_id"]))
    end

    it "should redirect to login if a wrong moderator access code is supplied" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      room = Room.new(name: "test", access_code: "123456", moderator_access_code: "abcdef")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      post :join, params: { room_uid: room, join_name: "Join Name" }, session: { moderator_access_code: "abcdee" }

      expect(response).to redirect_to room_path(room.uid)
    end

    it "should redirect to login if a 'empty' moderator access code is supplied and moderator code is not set" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      room = Room.new(name: "test", access_code: "123456")
      room.room_settings = "{ }"
      room.owner = @owner
      room.save

      post :join, params: { room_uid: room, join_name: "Join Name" }, session: { moderator_access_code: nil }

      expect(response).to redirect_to room_path(room.uid)
    end

    it "should join owner as moderator if meeting running" do
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:is_meeting_running?).and_return(true)

      @request.session[:user_id] = @owner.id
      post :join, params: { room_uid: @room, join_name: @owner.name }

      expect(response).to redirect_to(join_path(@owner.main_room, @owner.name, { user_is_moderator: true }, @owner.uid))
    end

    it "redirects to root if owner of room is not verified" do
      allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)
      @owner.update_attribute(:email_verified, false)

      post :join, params: { room_uid: @room, join_name: @owner.name }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "should not allow the user to join if the user isn't signed in and room authentication is required" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return("true")

      post :join, params: { room_uid: @room }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(root_path)
    end

    it "redirects to root if owner is pending" do
      @request.session[:user_id] = @owner.id
      @owner.set_role :pending

      post :join, params: { room_uid: @room }

      expect(response).to redirect_to(root_path)
    end

    it "redirects to root if owner is banned" do
      @request.session[:user_id] = @owner.id
      @owner.set_role :denied

      post :join, params: { room_uid: @room }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "DELETE #destroy" do
    before do
      @user = create(:user)
      @secondary_room = create(:room, owner: @user)
    end

    it "should delete room and redirect to main room" do
      @request.session[:user_id] = @user.id

      expect do
        delete :destroy, params: { room_uid: @secondary_room }
      end.to change { Room.count }.by(-1)

      expect(response).to redirect_to(@user.main_room)
    end

    it "should not delete room if not owner" do
      random_user = create(:user)
      @request.session[:user_id] = random_user.id

      expect do
        delete :destroy, params: { room_uid: @user.main_room }
      end.to change { Room.count }.by(0)
    end

    it "should not delete room not logged in" do
      expect do
        delete :destroy, params: { room_uid: @user.main_room }
      end.to change { Room.count }.by(0)
    end

    it "allows admin to delete room" do
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      expect do
        delete :destroy, params: { room_uid: @secondary_room }
      end.to change { Room.count }.by(-1)

      expect(response).to redirect_to(@admin.main_room)
    end

    it "does not allow admin to delete a users home room" do
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      expect do
        delete :destroy, params: { room_uid: @user.main_room }
      end.to change { Room.count }.by(0)

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(@admin.main_room)
    end

    it "does not allow an admin from a different context to delete room" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)

      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      expect do
        delete :destroy, params: { room_uid: @secondary_room }
      end.to change { Room.count }.by(0)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #start" do
    before do
      @user = create(:user)
      @other_room = create(:room)

      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:get_meeting_info).and_return(
        moderatorPW: "modpass",
        attendeePW: "attpass",
      )
      allow_any_instance_of(BigBlueButton::BigBlueButtonApi).to receive(:create_meeting).and_return(
        messageKey: "",
        createTime: "1611793449622"
      )
    end

    it "should redirect to join path if owner" do
      @request.session[:user_id] = @user.id
      post :start, params: { room_uid: @user.main_room }

      expect(response).to redirect_to(join_path(@user.main_room, @user.name, { user_is_moderator: true }, @user.uid))
    end

    it "should bring to room if not owner" do
      @request.session[:user_id] = @user.id
      post :start, params: { room_uid: @other_room }

      expect(response).to redirect_to(root_path)
    end

    it "should bring to root if not authenticated" do
      post :start, params: { room_uid: @other_room }

      expect(response).to redirect_to(root_path)
    end

    it "redirects to join path if admin" do
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :start, params: { room_uid: @user.main_room }

      expect(response).to redirect_to(join_path(@user.main_room, @admin.name, { user_is_moderator: true }, @admin.uid))
    end

    it "redirects to root path if not admin of current user" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :start, params: { room_uid: @user.main_room }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #update_settings" do
    before do
      @user = create(:user)
      @secondary_room = create(:room, owner: @user)
    end

    it "properly updates room name through the room settings modal and redirects to current page" do
      @request.session[:user_id] = @user.id
      name = Faker::Name.first_name

      room_params = { room_uid: @secondary_room.uid, room: { name: name } }

      expect { post :update_settings, params: room_params }.to change { @secondary_room.reload.name }
        .from(@secondary_room.name).to(name)
      expect(response).to redirect_to(@secondary_room)
    end

    it "properly updates room settings through the room settings modal and redirects to current page" do
      @request.session[:user_id] = @user.id

      room_params = { mute_on_join: "1", name: @secondary_room.name, recording: "1" }
      formatted_room_params = "{\"muteOnStart\":true,\"requireModeratorApproval\":false," \
        "\"anyoneCanStart\":false,\"joinModerator\":false,\"recording\":true,\"requireAuthenticationToJoin\":false}" # JSON string format

      expect { post :update_settings, params: { room_uid: @secondary_room.uid, room: room_params } }
        .to change { @secondary_room.reload.room_settings }
        .from(@secondary_room.room_settings).to(formatted_room_params)
      expect(response).to redirect_to(@secondary_room)
    end

    it "properly updates room name through room header and redirects to current page" do
      @request.session[:user_id] = @user.id

      patch :update_settings, params: { room_uid: @secondary_room, setting: :rename_header, room_name: :name }

      expect(response).to redirect_to(@secondary_room)
    end

    it "allows admin to update room settings" do
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      room_params = { mute_on_join: "1", name: @secondary_room.name }
      formatted_room_params = "{\"muteOnStart\":true,\"requireModeratorApproval\":false," \
        "\"anyoneCanStart\":false,\"joinModerator\":false,\"recording\":false,\"requireAuthenticationToJoin\":false}" # JSON string format

      expect { post :update_settings, params: { room_uid: @secondary_room.uid, room: room_params } }
        .to change { @secondary_room.reload.room_settings }
        .from(@secondary_room.room_settings).to(formatted_room_params)
      expect(response).to redirect_to(@secondary_room)
    end

    it "does not allow admins from a different context to update room settings" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      room_params = { mute_on_join: "1", name: @secondary_room.name }

      expect { post :update_settings, params: { room_uid: @secondary_room.uid, room: room_params } }
        .not_to change { @secondary_room.reload.room_settings }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #logout" do
    before do
      @user = create(:user)
      @room = @user.main_room
    end

    it "redirects to the correct room" do
      @request.session[:user_id] = @user.id

      get :logout, params: { room_uid: @room }

      expect(response).to redirect_to(@room)
    end
  end

  describe "POST #login" do
    before do
      @user = create(:user)
      @room = @user.main_room
      @room.access_code = "123456"
      @room.save
    end

    it "should redirect to show with valid access code" do
      post :login, params: { room_uid: @room.uid, room: { access_code: "123456" } }

      expect(response).to redirect_to room_path(@room.uid)
      expect(flash[:alert]).to be_nil
    end

    it "should redirect to show with valid moderator_access_code as regular access_code" do
      allow_any_instance_of(Setting).to receive(:get_value).and_call_original
      allow_any_instance_of(Setting).to receive(:get_value)
        .with("Room Configuration Moderator Access Codes").and_return("optional")

      @room.moderator_access_code = "abcdef"
      @room.save

      post :login, params: { room_uid: @room.uid, room: { access_code: "abcdef" } }

      expect(response).to redirect_to room_path(@room.uid)
      expect(flash[:alert]).to be_nil
      expect(session[:moderator_access_code]).to eq("abcdef")
    end

    it "should redirect to show with and notify user of invalid access code" do
      post :login, params: { room_uid: @room.uid, room: { access_code: "123455" } }

      expect(response).to redirect_to room_path(@room.uid)
      expect(flash[:alert]).to eq(I18n.t("room.access_code_required"))
    end

    it "should redirect to show and notify user of invalid moderator access code" do
      @room.moderator_access_code = "abcdef"
      @room.save

      post :login, params: { room_uid: @room.uid, room: { moderator_access_code: "abcdee" } }

      expect(response).to redirect_to room_path(@room.uid)
      expect(flash[:alert]).to eq(I18n.t("room.access_code_required"))
    end

    it "it should redirect to show with valid moderator access code and disabled moderator codes setting" do
      allow_any_instance_of(Setting).to receive(:get_value).and_call_original
      allow_any_instance_of(Setting).to receive(:get_value).with("Moderator Access Codes").and_return("false")

      @room.moderator_access_code = "abcdef"
      @room.save

      post :join, params: { room_uid: @room, join_name: "Join Name" }, session: { moderator_access_code: "abcdef" }

      expect(response).to redirect_to room_path(@room.uid)
      expect(flash[:alert]).to eq(I18n.t("room.access_code_required"))
    end
  end

  describe "POST join_specific_room" do
    before do
      @user = create(:user)
      @user1 = create(:user)
    end

    it "should display flash if the user doesn't supply a valid uid" do
      @request.session[:user_id] = @user.id

      post :join_specific_room, params: { join_room: { url: "abc" } }

      expect(flash[:alert]).to eq(I18n.t("room.no_room.invalid_room_uid"))
      expect(response).to redirect_to cant_create_rooms_path
    end

    it "should redirect the user to the room uid they supplied" do
      post :join_specific_room, params: { join_room: { url: @user1.main_room } }

      expect(response).to redirect_to room_path(@user1.main_room)
    end

    it "should redirect the user to the room join url they supplied" do
      post :join_specific_room, params: { join_room: { url: room_path(@user1.main_room) } }

      expect(response).to redirect_to room_path(@user1.main_room)
    end
  end

  describe "POST #shared_access" do
    before do
      @user = create(:user)
      @room = create(:room, owner: @user)
      @user1 = create(:user)
      allow(Rails.configuration).to receive(:shared_access_default).and_return("true")
    end

    it "shares a room with another user" do
      @request.session[:user_id] = @user.id

      post :shared_access, params: { room_uid: @room.uid, add: [@user1.uid] }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true
      expect(flash[:success]).to be_present
      expect(response).to redirect_to room_path(@room)
    end

    it "allows a user to view a shared room and start it" do
      @request.session[:user_id] = @user.id
      post :shared_access, params: { room_uid: @room.uid, add: [@user1.uid] }

      allow(controller).to receive(:current_user).and_return(@user1)
      get :show, params: { room_uid: @room.uid }
      expect(response).to render_template(:show)
    end

    it "unshares a room from the user if they are removed from the list" do
      SharedAccess.create(room_id: @room.id, user_id: @user1.id)
      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true

      @request.session[:user_id] = @user.id
      post :shared_access, params: { room_uid: @room.uid, add: [] }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be false
      expect(flash[:success]).to be_present
      expect(response).to redirect_to room_path(@room)
    end

    it "doesn't allow a user to share a room they don't own" do
      @request.session[:user_id] = @user1.id

      post :shared_access, params: { room_uid: @room.uid, add: [@user1.uid] }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be false
      expect(response).to redirect_to root_path
    end

    it "disables shared room functionality if the site setting is disabled" do
      allow_any_instance_of(Setting).to receive(:get_value).and_return("false")

      @request.session[:user_id] = @user.id
      post :shared_access, params: { room_uid: @room.uid, add: [@user1.uid] }
      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true

      allow(controller).to receive(:current_user).and_return(@user1)
      get :show, params: { room_uid: @room.uid }
      expect(response).to render_template(:join)
    end

    it "allows admins to update room access" do
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :shared_access, params: { room_uid: @room.uid, add: [@user1.uid] }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true
      expect(flash[:success]).to be_present
      expect(response).to redirect_to room_path(@room)
    end

    it "redirects to root path if not admin of current user" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :shared_access, params: { room_uid: @room.uid, add: [] }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #remove_shared_access" do
    before do
      @user = create(:user)
      @room = create(:room, owner: @user)
      @user1 = create(:user)
      allow(Rails.configuration).to receive(:shared_access_default).and_return("true")
    end

    it "unshares a room from the user if they click the remove button" do
      SharedAccess.create(room_id: @room.id, user_id: @user1.id)
      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true

      @request.session[:user_id] = @user1.id
      post :remove_shared_access, params: { room_uid: @room.uid, user_id: @user1.id }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be false
      expect(flash[:success]).to be_present
      expect(response).to redirect_to @user1.main_room
    end

    it "doesn't allow some random user to change share access" do
      @user2 = create(:user)

      SharedAccess.create(room_id: @room.id, user_id: @user1.id)
      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true

      @request.session[:user_id] = @user2.id
      post :remove_shared_access, params: { room_uid: @room.uid, user_id: @user1.id }

      expect(SharedAccess.exists?(room_id: @room.id, user_id: @user1.id)).to be true
      expect(response).to redirect_to root_path
    end
  end

  describe "POST #preupload_presentation" do
    before do
      @user = create(:user)
      @file = fixture_file_upload('files/sample.pdf', 'application/pdf')
      @invalid_file = fixture_file_upload('files/invalid.bmp', 'image/bmp')
      allow(Rails.configuration).to receive(:preupload_presentation_default).and_return("true")
    end

    it "adds a presentation to the room" do
      @request.session[:user_id] = @user.id

      post :preupload_presentation, params: { room_uid: @user.main_room, room: { presentation: @file } }

      expect(@user.main_room.presentation.attached?).to be true
      expect(flash[:success]).to be_present
      expect(response).to redirect_to @user.main_room
    end

    it "rejects file types that are not allowed" do
      @request.session[:user_id] = @user.id

      post :preupload_presentation, params: { room_uid: @user.main_room, room: { presentation: @invalid_file } }

      expect(@user.main_room.presentation.attached?).to be false
      expect(flash[:alert]).to be_present
      expect(response).to redirect_to @user.main_room
    end

    it "allows admins to add a presentation to the room" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(true)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :preupload_presentation, params: { room_uid: @user.main_room, room: { presentation: @file } }

      expect(@user.main_room.presentation.attached?).to be true
      expect(flash[:success]).to be_present
      expect(response).to redirect_to @user.main_room
    end

    it "redirects to root path if not admin of current user" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :preupload_presentation, params: { room_uid: @user.main_room, room: { presentation: @file } }

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #remove_presentation" do
    before do
      @user = create(:user)
      @user.main_room.presentation.attach(fixture_file_upload('files/sample.pdf', 'application/pdf'))
      allow(Rails.configuration).to receive(:shared_access_default).and_return("true")
    end

    it "removes a presentation from a room" do
      @request.session[:user_id] = @user.id

      expect(@user.main_room.presentation.attached?).to be true

      post :remove_presentation, params: { room_uid: @user.main_room }

      @user.main_room.reload

      expect(@user.main_room.presentation.attached?).to be false
      expect(flash[:success]).to be_present
      expect(response).to redirect_to @user.main_room
    end

    it "allows admins to remove a presentation from a room" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(true)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      expect(@user.main_room.presentation.attached?).to be true

      post :remove_presentation, params: { room_uid: @user.main_room }

      @user.main_room.reload

      expect(@user.main_room.presentation.attached?).to be false
      expect(flash[:success]).to be_present
      expect(response).to redirect_to @user.main_room
    end

    it "redirects to root path if not admin of current user" do
      allow_any_instance_of(User).to receive(:admin_of?).and_return(false)
      @admin = create(:user)
      @admin.set_role :admin
      @request.session[:user_id] = @admin.id

      post :preupload_presentation, params: { room_uid: @user.main_room, room: { presentation: @file } }

      expect(response).to redirect_to(root_path)
    end
  end
end
