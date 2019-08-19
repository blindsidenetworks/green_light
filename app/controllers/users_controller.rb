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

class UsersController < ApplicationController
  include Pagy::Backend
  include Authenticator
  include Emailer
  include Registrar
  include Recorder
  include Rolify

  before_action :find_user, only: [:edit, :change_password, :delete_account, :update, :destroy]
  before_action :ensure_unauthenticated, only: [:new, :create, :signin]
  before_action :check_admin_of, only: [:edit, :change_password, :delete_account]

  # POST /u
  def create
    # Verify that GreenLight is configured to allow user signup.
    return unless Rails.configuration.allow_user_signup

    @user = User.new(user_params)
    @user.provider = @user_domain

    # User or recpatcha is not valid
    render(:new) && return unless valid_user_or_captcha

    # Redirect to root if user token is either invalid or expired
    return redirect_to root_path, flash: { alert: I18n.t("registration.invite.fail") } unless passes_invite_reqs

    # User has passed all validations required
    @user.save

    logger.info "Support: #{@user.email} user has been created."

    # Set user to pending and redirect if Approval Registration is set
    if approval_registration
      @user.add_role :pending

      return redirect_to root_path,
        flash: { success: I18n.t("registration.approval.signup") } unless Rails.configuration.enable_email_verification
    end

    send_registration_email

    # Sign in automatically if email verification is disabled or if user is already verified.
    login(@user) && return if !Rails.configuration.enable_email_verification || @user.email_verified

    send_activation_email(@user)

    redirect_to root_path
  end

  # GET /signin
  def signin
    check_if_twitter_account

    providers = configured_providers
    if (!allow_user_signup? || !allow_greenlight_accounts?) && providers.count == 1 &&
       !Rails.configuration.loadbalanced_configuration
      provider_path = if Rails.configuration.omniauth_ldap
        ldap_signin_path
      else
        "#{Rails.configuration.relative_url_root}/auth/#{providers.first}"
      end

      return redirect_to provider_path
    end
  end

  # GET /ldap_signin
  def ldap_signin
  end

  # GET /signup
  def new
    return redirect_to root_path unless Rails.configuration.allow_user_signup

    # Check if the user needs to be invited
    if invite_registration
      redirect_to root_path, flash: { alert: I18n.t("registration.invite.no_invite") } unless params[:invite_token]

      session[:invite_token] = params[:invite_token]
    end

    check_if_twitter_account(true)

    @user = User.new
  end

  # GET /u/:user_uid/edit
  def edit
    redirect_to root_path unless current_user
  end

  # GET /u/:user_uid/change_password
  def change_password
    redirect_to edit_user_path unless current_user.greenlight_account?
  end

  # GET /u/:user_uid/delete_account
  def delete_account
  end

  # PATCH /u/:user_uid/edit
  def update
    redirect_path = current_user.admin_of?(@user) ? admins_path : edit_user_path(@user)

    if params[:setting] == "password"
      # Update the users password.
      errors = {}

      if @user.authenticate(user_params[:password])
        # Verify that the new passwords match.
        if user_params[:new_password] == user_params[:password_confirmation]
          @user.password = user_params[:new_password]
        else
          # New passwords don't match.
          errors[:password_confirmation] = "doesn't match"
        end
      else
        # Original password is incorrect, can't update.
        errors[:password] = "is incorrect"
      end

      if errors.empty? && @user.save
        # Notify the user that their account has been updated.
        redirect_to redirect_path, flash: { success: I18n.t("info_update_success") }
      else
        # Append custom errors.
        errors.each { |k, v| @user.errors.add(k, v) }
        render :edit, params: { settings: params[:settings] }
      end
    else
      if @user.update_attributes(user_params)
        @user.update_attributes(email_verified: false) if user_params[:email] != @user.email

        user_locale(@user)

        if update_roles(params[:user][:role_ids])
          return redirect_to redirect_path, flash: { success: I18n.t("info_update_success") }
        else
          flash[:alert] = I18n.t("administrator.roles.invalid_assignment")
        end
      end

      render :edit, params: { settings: params[:settings] }
    end
  end

  # DELETE /u/:user_uid
  def destroy
    logger.info "Support: #{current_user.email} is deleting #{@user.email}."

    self_delete = current_user == @user
    begin
      if current_user && (self_delete || current_user.admin_of?(@user))
        @user.destroy
        session.delete(:user_id) if self_delete

        return redirect_to admins_path, flash: { success: I18n.t("administrator.flash.delete") } unless self_delete
      end
    rescue => e
      logger.error "Support: Error in user deletion: #{e}"
      flash[:alert] = I18n.t(params[:message], default: I18n.t("administrator.flash.delete_fail"))
    end

    redirect_to root_path
  end

  # GET /u/:user_uid/recordings
  def recordings
    if current_user && current_user.uid == params[:user_uid]
      @search, @order_column, @order_direction, recs =
        all_recordings(current_user.rooms.pluck(:bbb_id), params.permit(:search, :column, :direction), true)
      @pagy, @recordings = pagy_array(recs)
    else
      redirect_to root_path
    end
  end

  # GET | POST /terms
  def terms
    redirect_to '/404' unless Rails.configuration.terms

    if params[:accept] == "true"
      current_user.update_attributes(accepted_terms: true)
      login(current_user)
    end
  end

  private

  def find_user
    @user = User.where(uid: params[:user_uid]).includes(:roles).first
  end

  def ensure_unauthenticated
    redirect_to current_user.main_room if current_user && params[:old_twitter_user_id].nil?
  end

  def user_params
    params.require(:user).permit(:name, :email, :image, :password, :password_confirmation,
      :new_password, :provider, :accepted_terms, :language)
  end

  def send_registration_email
    if invite_registration
      send_invite_user_signup_email(@user)
    elsif approval_registration
      send_approval_user_signup_email(@user)
    end
  end

  # Checks that the user is allowed to edit this user
  def check_admin_of
    redirect_to current_user.main_room if current_user && @user != current_user && !current_user.admin_of?(@user)
  end
end
