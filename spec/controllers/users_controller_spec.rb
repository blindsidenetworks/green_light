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

def random_valid_user_params
  pass = Faker::Internet.password(min_length: 8)
  {
    user: {
      name: Faker::Name.first_name,
      email: Faker::Internet.email,
      password: pass,
      password_confirmation: pass,
      accepted_terms: true,
      email_verified: true,
    },
  }
end

describe UsersController, type: :controller do
  let(:invalid_params) do
    {
      user: {
        name: "Invalid",
        email: "example.com",
        password: "pass",
        password_confirmation: "invalid",
        accepted_terms: false,
        email_verified: false,
      },
    }
  end

  describe "GET #edit" do
    it "renders the edit template" do
      user = create(:user)

      @request.session[:user_id] = user.id

      get :edit, params: { user_uid: user.uid }

      expect(response).to render_template(:edit)
    end

    it "does not allow you to edit other users if you're not an admin" do
      user = create(:user)
      user2 = create(:user)

      @request.session[:user_id] = user.id

      get :edit, params: { user_uid: user2.uid }

      expect(response).to redirect_to(root_path)
    end

    it "allows admins to edit other users" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
      controller.instance_variable_set(:@user_domain, "provider1")

      user = create(:user, provider: "provider1")
      user.set_role :admin
      user2 = create(:user, provider: "provider1")

      @request.session[:user_id] = user.id

      get :edit, params: { user_uid: user2.uid }

      expect(response).to render_template(:edit)
    end

    it "redirect to root if user isn't signed in" do
      user = create(:user)

      get :edit, params: { user_uid: user }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET #join_settings" do
    it "renders the join settings template" do
      user = create(:user)

      @request.session[:user_id] = user.id

      get :join_settings, params: { user_uid: user.uid }

      expect(response).to render_template(:join_settings)
    end

    it "redirect to root if user try to go to join setting page and isn't signed in" do
      user = create(:user)

      get :join_settings, params: { user_uid: user }
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #create" do
    context "allow greenlight accounts" do
      before { allow(Rails.configuration).to receive(:allow_user_signup).and_return(true) }
      before { allow(Rails.configuration).to receive(:enable_email_verification).and_return(false) }

      it "redirects to user room on successful create" do
        params = random_valid_user_params
        post :create, params: params

        u = User.find_by(name: params[:user][:name], email: params[:user][:email])

        expect(u).to_not be_nil
        expect(u.name).to eql(params[:user][:name])

        expect(response).to redirect_to(room_path(u.main_room))
      end

      it "user saves with greenlight provider" do
        params = random_valid_user_params
        post :create, params: params

        u = User.find_by(name: params[:user][:name], email: params[:user][:email])

        expect(u.provider).to eql("greenlight")
      end

      it "renders #new on unsuccessful save" do
        post :create, params: invalid_params

        expect(response).to render_template(:new)
      end

      it "sends activation email if email verification is on" do
        allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)

        params = random_valid_user_params
        expect { post :create, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)

        u = User.find_by(name: params[:user][:name], email: params[:user][:email])

        expect(u).to_not be_nil
        expect(u.name).to eql(params[:user][:name])

        expect(flash[:success]).to be_present
        expect(response).to redirect_to(root_path)
      end

      it "correctly sets the last_login field after the user is created" do
        params = random_valid_user_params
        post :create, params: params

        u = User.find_by(name: params[:user][:name], email: params[:user][:email])

        expect(u.last_login).to_not be_nil
      end

      context "email mapping" do
        before do
          @role1 = Role.create(name: "role1", priority: 2, provider: "greenlight")
          @role2 = Role.create(name: "role2", priority: 3, provider: "greenlight")
          allow_any_instance_of(Setting).to receive(:get_value).and_return("-123@test.com=role1,@testing.com=role2")
        end

        it "correctly sets users role if email mapping is set" do
          params = random_valid_user_params
          params[:user][:email] = "test-123@test.com"

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])

          expect(u.role).to eq(@role1)
        end

        it "correctly sets users role if email mapping is set (second test)" do
          params = random_valid_user_params
          params[:user][:email] = "test@testing.com"

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])

          expect(u.role).to eq(@role2)
        end

        it "defaults to user if no mapping matches" do
          params = random_valid_user_params
          params[:user][:email] = "test@testing1.com"

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])

          expect(u.role).to eq(Role.find_by(name: "user", provider: "greenlight"))
        end
      end
    end

    context "disallow greenlight accounts" do
      before { allow(Rails.configuration).to receive(:allow_user_signup).and_return(false) }

      it "redirect to root on attempted create" do
        params = random_valid_user_params
        post :create, params: params

        u = User.find_by(name: params[:user][:name], email: params[:user][:email])

        expect(u).to be_nil
      end
    end

    context "allow email verification" do
      before do
        allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)
      end

      it "should raise if there there is a delivery failure" do
        params = random_valid_user_params

        expect do
          post :create, params: params
          raise :anyerror
        end.to raise_error { :anyerror }
      end

      context "enable invite registration" do
        before do
          allow_any_instance_of(Registrar).to receive(:invite_registration).and_return(true)
          allow(Rails.configuration).to receive(:allow_user_signup).and_return(true)
          @user = create(:user, provider: "greenlight")
          @admin = create(:user, provider: "greenlight", email: "test@example.com")
          @admin.set_role :admin
        end

        it "should notify admins that user signed up" do
          params = random_valid_user_params
          invite = Invitation.create(email: params[:user][:email], provider: "greenlight")
          @request.session[:invite_token] = invite.invite_token

          expect { post :create, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)
        end

        it "allows the user to signup if they are invited" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(false)

          params = random_valid_user_params
          invite = Invitation.create(email: params[:user][:name], provider: "greenlight")
          @request.session[:invite_token] = invite.invite_token

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])
          expect(response).to redirect_to(u.main_room)
        end

        it "verifies the user if they sign up with the email they receieved the invite with" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)

          params = random_valid_user_params
          invite = Invitation.create(email: params[:user][:email], provider: "greenlight")
          @request.session[:invite_token] = invite.invite_token

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])
          expect(response).to redirect_to(u.main_room)
        end

        it "asks the user to verify if they signup with a different email" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)

          params = random_valid_user_params
          invite = Invitation.create(email: Faker::Internet.email, provider: "greenlight")
          @request.session[:invite_token] = invite.invite_token

          post :create, params: params

          expect(User.exists?(name: params[:user][:name], email: params[:user][:email])).to eq(true)
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(root_path)
        end
      end

      context "enable approval registration" do
        before do
          allow_any_instance_of(Registrar).to receive(:approval_registration).and_return(true)
          allow(Rails.configuration).to receive(:allow_user_signup).and_return(true)
          @user = create(:user, provider: "greenlight")
          @admin = create(:user, provider: "greenlight", email: "test@example.com")
          @admin.set_role :admin
        end

        it "allows any user to sign up" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(false)

          params = random_valid_user_params

          post :create, params: params

          expect(User.exists?(name: params[:user][:name], email: params[:user][:email])).to eq(true)
          expect(flash[:success]).to be_present
          expect(response).to redirect_to(root_path)
        end

        it "sets the user to pending on sign up" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(false)

          params = random_valid_user_params

          post :create, params: params

          u = User.find_by(name: params[:user][:name], email: params[:user][:email])

          expect(u.has_role?(:pending)).to eq(true)
        end

        it "notifies admins that a user signed up" do
          allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)

          params = random_valid_user_params

          expect { post :create, params: params }.to change { ActionMailer::Base.deliveries.count }.by(2)
        end
      end
    end

    it "redirects to main room if already authenticated" do
      user = create(:user)
      @request.session[:user_id] = user.id

      post :create, params: random_valid_user_params
      expect(response).to redirect_to(room_path(user.main_room))
    end
  end

  describe "POST #update" do
    it "properly updates usser attributes" do
      user = create(:user)
      @request.session[:user_id] = user.id

      params = random_valid_user_params
      post :update, params: params.merge!(user_uid: user)
      user.reload

      expect(user.name).to eql(params[:user][:name])
      expect(user.email).to eql(params[:user][:email])
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(edit_user_path(user))
    end

    it "properly updates user attributes" do
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(false)
      user = create(:user)
      @request.session[:user_id] = user.id

      params = random_valid_user_params
      post :update, params: params.merge!(user_uid: user)
      user.reload

      expect(user.name).not_to eql(params[:user][:name])
      expect(user.email).not_to eql(params[:user][:email])
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(edit_user_path(user))
    end

    it "allows admins to update a non local accounts name/email" do
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(false)
      user = create(:user)
      admin = create(:user).set_role :admin
      @request.session[:user_id] = admin.id

      params = random_valid_user_params
      post :update, params: params.merge!(user_uid: user)
      user.reload

      expect(user.name).to eql(params[:user][:name])
      expect(user.email).to eql(params[:user][:email])
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(admins_path)
    end

    it "renders #edit on unsuccessful save" do
      @user = create(:user)
      @request.session[:user_id] = @user.id

      post :update, params: invalid_params.merge!(user_uid: @user)
      expect(response).to render_template(:edit)
    end

    context 'Roles updates' do
      it "should fail to update roles if users tries to add a role with a higher priority than their own" do
        user = create(:user)
        @request.session[:user_id] = user.id

        user_role = user.role

        user_role.update_permission("can_manage_users", "true")

        user_role.save!

        tmp_role = Role.create(name: "test", priority: -4, provider: "greenlight")

        params = random_valid_user_params
        post :update, params: params.merge!(user_uid: user, user: { role_id: tmp_role.id.to_s })

        expect(flash[:alert]).to eq(I18n.t("administrator.roles.invalid_assignment"))
        expect(response).to render_template(:edit)
      end

      it "should successfuly add roles to the user" do
        allow(Rails.configuration).to receive(:enable_email_verification).and_return(true)

        user = create(:user)
        admin = create(:user)

        admin.set_role :admin

        @request.session[:user_id] = admin.id

        tmp_role1 = Role.create(name: "test1", priority: 2, provider: "greenlight")
        tmp_role1.update_permission("send_promoted_email", "true")

        params = random_valid_user_params
        params.merge!(user_uid: user, user: { role_id: tmp_role1.id.to_s })

        expect { post :update, params: params }.to change { ActionMailer::Base.deliveries.count }.by(1)

        user.reload
        expect(user.role.name).to eq("test1")
        expect(response).to redirect_to(admins_path)
      end

      it "creates the home room for a user if needed" do
        old_role = Role.create(name: "test1", priority: 2, provider: "greenlight")
        old_role.update_permission("can_create_rooms", "false")

        new_role = Role.create(name: "test2", priority: 3, provider: "greenlight")
        new_role.update_permission("can_create_rooms", "true")

        user = create(:user, role: old_role)
        admin = create(:user)

        admin.set_role :admin

        @request.session[:user_id] = admin.id

        params = random_valid_user_params
        params.merge!(user_uid: user, user: { role_id: new_role.id.to_s })

        expect(user.role.name).to eq("test1")
        expect(user.main_room).to be_nil

        post :update, params: params

        user.reload
        expect(user.role.name).to eq("test2")
        expect(user.main_room).not_to be_nil
        expect(response).to redirect_to(admins_path)
      end
    end
  end

  describe "POST #update_join_settings" do
    it "properly updates user join settings" do
      user = create(:user)
      @request.session[:user_id] = user.id
      allow(Rails.configuration).to receive(:join_settings_features).and_return("userdata-bbb_listen_only_mode")

      expect(user.user_settings[0]).to eql(nil)

      params = {
        user: {
          "userdata-bbb_listen_only_mode": 1,
        }
      }
      post :update_join_settings, params: params.merge!(user_uid: user)
      user.reload

      expect(user.user_settings[0][:value]).to eql("true")
      expect(flash[:success]).to be_present

      params = {
        user: {
          "userdata-bbb_listen_only_mode": 0,
        }
      }
      post :update_join_settings, params: params.merge!(user_uid: user)
      user.reload

      expect(user.user_settings[0][:value]).to eql("false")
      expect(flash[:success]).to be_present
    end
    it "should not update unrecognize user settings" do
      user = create(:user)
      @request.session[:user_id] = user.id

      allow(Rails.configuration).to receive(:join_settings_features).and_return("")

      settings_before = user.user_settings
      params = {
        user: {
          "userdata-bbb_listen_only_mode": 1,
        }
      }
      post :update_join_settings, params: params.merge!(user_uid: user)
      user.reload

      expect(user.user_settings.length).to eql(settings_before.length)
      expect(user.user_settings[0]).to eql(nil)
    end
    it "redirect to root if user isn't signed in" do
      user = create(:user)
      @request.session[:user_id] = user.id

      params = {
        user: {
          "userdata-bbb_listen_only_mode": 1,
        }
      }
      post :update_join_settings, params: params.merge!(user_uid: user)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST #update_password" do
    before do
      @user = create(:user)
      @password = Faker::Internet.password(min_length: 8)
    end

    it "properly updates users password" do
      @request.session[:user_id] = @user.id

      params = {
        user: {
          password: @user.password,
          new_password: @password,
          password_confirmation: @password,
        }
      }
      post :update_password, params: params.merge!(user_uid: @user)
      @user.reload

      expect(@user.authenticate(@password)).not_to be false
      expect(@user.errors).to be_empty
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(change_password_path(@user))
    end

    it "doesn't update the users password if initial password is incorrect" do
      @request.session[:user_id] = @user.id

      params = {
        user: {
          password: "incorrect_password",
          new_password: @password,
          password_confirmation: @password,
        }
      }
      post :update_password, params: params.merge!(user_uid: @user)
      @user.reload
      expect(@user.authenticate(@password)).to be false
      expect(response).to render_template(:change_password)
    end

    it "doesn't update the users password if new passwords don't match" do
      @request.session[:user_id] = @user.id

      params = {
        user: {
          password: "incorrect_password",
          new_password: @password,
          password_confirmation: "#{@password}_random_string",
        }
      }
      post :update_password, params: params.merge!(user_uid: @user)
      @user.reload
      expect(@user.authenticate(@password)).to be false
      expect(response).to render_template(:change_password)
    end
  end

  describe "DELETE #user" do
    before do
      allow(Rails.configuration).to receive(:allow_user_signup).and_return(true)
      Role.create_default_roles("provider1")
    end

    it "permanently deletes user" do
      user = create(:user)
      @request.session[:user_id] = user.id

      delete :destroy, params: { user_uid: user.uid }

      expect(User.include_deleted.find_by(uid: user.uid)).to be_nil
      expect(response).to redirect_to(root_path)
    end

    it "allows admins to tombstone users" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
      controller.instance_variable_set(:@user_domain, "provider1")

      user = create(:user, provider: "provider1")
      admin = create(:user, provider: "provider1")
      admin.set_role :admin
      @request.session[:user_id] = admin.id

      delete :destroy, params: { user_uid: user.uid }

      expect(User.deleted.find_by(uid: user.uid)).to be_present
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(admins_path)
    end

    it "allows admins to permanently delete users" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      allow_any_instance_of(BbbServer).to receive(:delete_all_recordings).and_return("")
      allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
      controller.instance_variable_set(:@user_domain, "provider1")

      user = create(:user, provider: "provider1")
      admin = create(:user, provider: "provider1")
      admin.set_role :admin
      @request.session[:user_id] = admin.id

      delete :destroy, params: { user_uid: user.uid, permanent: "true" }

      expect(User.include_deleted.find_by(uid: user.uid)).to be_nil
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(admins_path)
    end

    it "permanently deletes the users rooms if the user is permanently deleted" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      allow_any_instance_of(BbbServer).to receive(:delete_all_recordings).and_return("")
      allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider1")
      controller.instance_variable_set(:@user_domain, "provider1")

      user = create(:user, provider: "provider1")
      admin = create(:user, provider: "provider1")
      admin.set_role :admin
      @request.session[:user_id] = admin.id
      uid = user.main_room.uid

      expect(Room.find_by(uid: uid)).to be_present

      delete :destroy, params: { user_uid: user.uid, permanent: "true" }

      expect(Room.include_deleted.find_by(uid: uid)).to be_nil
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(admins_path)
    end

    it "doesn't allow admins of other providers to delete users" do
      allow(Rails.configuration).to receive(:loadbalanced_configuration).and_return(true)
      allow_any_instance_of(User).to receive(:greenlight_account?).and_return(true)
      allow_any_instance_of(ApplicationController).to receive(:set_user_domain).and_return("provider2")
      controller.instance_variable_set(:@user_domain, "provider2")

      user = create(:user, provider: "provider1")
      admin = create(:user, provider: "provider2")
      admin.set_role :admin
      @request.session[:user_id] = admin.id

      delete :destroy, params: { user_uid: user.uid }

      expect(flash[:alert]).to be_present
      expect(response).to redirect_to(admins_path)
    end
  end

  describe "GET | POST #terms" do
    before { allow(Rails.configuration).to receive(:allow_user_signup).and_return(true) }
    before { allow(Rails.configuration).to receive(:terms).and_return(false) }

    it "Redirects to 404 if terms is disabled" do
      post :terms, params: { accept: "false" }

      expect(response).to redirect_to('/404')
    end
  end

  describe "GET #recordings" do
    before do
      @user1 = create(:user)
      @user2 = create(:user)
    end

    it "redirects to root if the incorrect user tries to access the page" do
      get :recordings, params: { current_user: @user2, user_uid: @user1.uid }

      expect(response).to redirect_to(root_path)
    end
  end
end
