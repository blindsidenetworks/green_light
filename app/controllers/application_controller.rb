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

class ApplicationController < ActionController::Base
  include BbbServer
  include Errors

  before_action :block_unknown_hosts, :redirect_to_https, :set_user_domain, :set_user_settings, :maintenance_mode?,
  :migration_error?, :user_locale, :check_admin_password, :check_user_role

  protect_from_forgery with: :exceptions

  # Retrieves the current user.
  def current_user
    @current_user ||= User.includes(:role, :main_room).find_by(id: session[:user_id])

    if Rails.configuration.loadbalanced_configuration && (@current_user && !@current_user.has_role?(:super_admin) &&
         @current_user.provider != @user_domain)
        @current_user = nil
        session.clear
      end

    @current_user
  end
  helper_method :current_user

  def bbb_server
    @bbb_server ||= Rails.configuration.loadbalanced_configuration ? bbb(@user_domain) : bbb("greenlight")
  end

  # Block unknown hosts to mitigate host header injection attacks
  def block_unknown_hosts
    return if Rails.configuration.hosts.blank?
    raise UnsafeHostError, "#{request.host} is not a safe host" unless Rails.configuration.hosts.include?(request.host)
  end

  # Force SSL
  def redirect_to_https
    if Rails.configuration.loadbalanced_configuration && request.headers["X-Forwarded-Proto"] == "http"
      redirect_to protocol: "https://"
    end
  end

  # Sets the user domain variable
  def set_user_domain
    if Rails.env.test? || !Rails.configuration.loadbalanced_configuration
      @user_domain = "greenlight"
    else
      @user_domain = parse_user_domain(request.host)

      check_provider_exists
    end
  end

  # Sets the settinfs variable
  def set_user_settings
    @settings = Setting.includes(:features).find_or_create_by(provider: @user_domain)
  end

  # Redirects the user to a Maintenance page if turned on
  def maintenance_mode?
    if ENV["MAINTENANCE_MODE"] == "true"
      render "errors/greenlight_error", status: 503, formats: :html,
        locals: {
          status_code: 503,
          message: I18n.t("errors.maintenance.message"),
          help: I18n.t("errors.maintenance.help"),
        }
    end

    maintenance_string = @settings.get_value("Maintenance Banner").presence || Rails.configuration.maintenance_window
    if maintenance_string.present? && cookies[:maintenance_window] != maintenance_string
      flash.now[:maintenance] = maintenance_string
    end
  end

  # Show an information page when migration fails and there is a version error.
  def migration_error?
    render :migration_error, status: 500 unless ENV["DB_MIGRATE_FAILED"].blank?
  end

  # Sets the appropriate locale.
  def user_locale(user = current_user)
    locale = if user && user.language != 'default'
      user.language
    else
      Rails.configuration.default_locale.presence || http_accept_language.language_region_compatible_from(I18n.available_locales)
    end

    begin
      I18n.locale = locale.tr('-', '_') unless locale.nil?
    rescue
      # Default to English if there are any issues in language
      logger.error("Support: User locale is not supported (#{locale}")
      I18n.locale = "en"
    end
  end

  # Checks to make sure that the admin has changed his password from the default
  def check_admin_password
    if current_user&.has_role?(:admin) && current_user.email == "admin@example.com" &&
       current_user&.greenlight_account? && current_user&.authenticate(Rails.configuration.admin_password_default)

      flash.now[:alert] = I18n.t("default_admin",
        edit_link: change_password_path(user_uid: current_user.uid)).html_safe
    end
  end

  # Checks if the user is banned and logs him out if he is
  def check_user_role
    if current_user&.has_role? :denied
      session.delete(:user_id)
      redirect_to root_path, flash: { alert: I18n.t("registration.banned.fail") }
    elsif current_user&.has_role? :pending
      session.delete(:user_id)
      redirect_to root_path, flash: { alert: I18n.t("registration.approval.fail") }
    end
  end

  # Relative root helper (when deploying to subdirectory).
  def relative_root
    Rails.configuration.relative_url_root || ""
  end
  helper_method :relative_root

  # Determines if the BigBlueButton endpoint is configured (or set to default).
  def bigbluebutton_endpoint_default?
    return false if Rails.configuration.loadbalanced_configuration
    Rails.configuration.bigbluebutton_endpoint_default == Rails.configuration.bigbluebutton_endpoint
  end
  helper_method :bigbluebutton_endpoint_default?

  def allow_greenlight_accounts?
    return Rails.configuration.allow_user_signup unless Rails.configuration.loadbalanced_configuration
    return false unless @user_domain && !@user_domain.empty? && Rails.configuration.allow_user_signup
    return false if @user_domain == "greenlight"
    # Proceed with retrieving the provider info
    begin
      provider_info = retrieve_provider_info(@user_domain, 'api2', 'getUserGreenlightCredentials')
      provider_info['provider'] == 'greenlight'
    rescue => e
      logger.error "Error in checking if greenlight accounts are allowed: #{e}"
      false
    end
  end
  helper_method :allow_greenlight_accounts?

  # Determine if Greenlight is configured to allow user signups.
  def allow_user_signup?
    Rails.configuration.allow_user_signup
  end
  helper_method :allow_user_signup?

  # Gets all configured omniauth providers.
  def configured_providers
    Rails.configuration.providers.select do |provider|
      Rails.configuration.send("omniauth_#{provider}")
    end
  end
  helper_method :configured_providers

  # Indicates whether users are allowed to share rooms
  def shared_access_allowed
    @settings.get_value("Shared Access") == "true"
  end
  helper_method :shared_access_allowed

  # Indicates whether users are allowed to share rooms
  def recording_consent_required?
    @settings.get_value("Require Recording Consent") == "true"
  end
  helper_method :recording_consent_required?

  # Indicates whether users are allowed to add moderator access codes to rooms
  def moderator_code_allowed?
    @settings.get_value("Room Configuration Moderator Access Codes") == "optional"
  end
  helper_method :moderator_code_allowed?

  # Shows global setting "authentication is required to access rooms"
  def global_room_authentication_required?
    @settings.get_value("Room Authentication") == "true"
  end
  helper_method :global_room_authentication_required?

  # Indicates whether users are allowed to require authentication to join rooms
  def room_require_authentication_allowed?
    @settings.get_value("Room Configuration Require Authentication To Join") == "optional"
  end
  helper_method :room_require_authentication_allowed?
  
  # Returns a list of allowed file types
  def allowed_file_types
    Rails.configuration.allowed_file_types
  end
  helper_method :allowed_file_types

  # Allows admins to edit a user's details
  def can_edit_user?(user_to_edit, editting_user)
    return user_to_edit.greenlight_account? if user_to_edit == editting_user

    editting_user.admin_of?(user_to_edit, "can_manage_users")
  end
  helper_method :can_edit_user?

  # Returns the page that the logo redirects to when clicked on
  def home_page
    return admins_path if current_user.has_role? :super_admin
    return current_user.main_room if current_user.role.get_permission("can_create_rooms")
    cant_create_rooms_path
  end
  helper_method :home_page

  # Parses the url for the user domain
  def parse_user_domain(hostname)
    return hostname.split('.').first if Rails.configuration.url_host.empty?
    Rails.configuration.url_host.split(',').each do |url_host|
      return hostname.chomp(url_host).chomp('.') if hostname.include?(url_host)
    end
    ''
  end

  # Include user domain in lograge logs
  def append_info_to_payload(payload)
    super
    payload[:host] = @user_domain
  end

  # Manually handle BigBlueButton errors
  rescue_from BigBlueButton::BigBlueButtonException do |ex|
    logger.error "BigBlueButtonException: #{ex}"
    render "errors/bigbluebutton_error"
  end

  # Manually deal with 401 errors
  rescue_from CanCan::AccessDenied do |_exception|
    if current_user
      render "errors/greenlight_error"
    else
      # Store the current url as a cookie to redirect to after sigining in
      cookies[:return_to] = request.url

      # Get the correct signin path
      path = if allow_greenlight_accounts?
        signin_path
      elsif Rails.configuration.loadbalanced_configuration
        "#{Rails.configuration.relative_url_root}/auth/bn_launcher"
      else
        signin_path
      end

      redirect_to path
    end
  end

  private

  def check_provider_exists
    # Checks to see if the user exists
    begin
      # Check if the session has already checked that the user exists
      # and return true if they did for this domain
      return if session[:provider_exists] == @user_domain

      retrieve_provider_info(@user_domain, 'api2', 'getUserGreenlightCredentials')

      # Add a session variable if the provider exists
      session[:provider_exists] = @user_domain
    rescue => e
      logger.error "Error in retrieve provider info: #{e}"
      @hide_signin = true
      case e.message
      when "No user with that id exists"
        set_default_settings

        render "errors/greenlight_error", locals: { message: I18n.t("errors.not_found.user_not_found.message"),
          help: I18n.t("errors.not_found.user_not_found.help") }
      when "Provider not included."
        set_default_settings

        render "errors/greenlight_error", locals: { message: I18n.t("errors.not_found.user_missing.message"),
          help: I18n.t("errors.not_found.user_missing.help") }
      when "That user has no configured provider."
        if Setting.exists?(provider: @user_domain)
          # Keep the branding
          @settings = Setting.find_by(provider: @user_domain)
        else
          set_default_settings
        end

        render "errors/greenlight_error", locals: { status_code: 501,
          message: I18n.t("errors.no_provider.message"),
          help: I18n.t("errors.no_provider.help") }
      else
        set_default_settings

        render "errors/greenlight_error", locals: { status_code: 500, message: I18n.t("errors.internal.message"),
          help: I18n.t("errors.internal.help"), display_back: true }
      end
    end
  end

  def set_default_settings
    # Use the default site settings
    @user_domain = "greenlight"
    @settings = Setting.find_or_create_by(provider: @user_domain)
  end
end
