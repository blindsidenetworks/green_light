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
require 'uri'
require 'i18n/language/mapping'

module ApplicationHelper
  include MeetingsHelper
  include BbbApi
  include I18n::Language::Mapping

  # Gets all configured omniauth providers.
  def configured_providers
    Rails.configuration.providers.select do |provider|
      Rails.configuration.send("omniauth_#{provider}")
    end
  end

  # Determines which providers can show a login button in the login modal.
  def iconset_providers
    providers = configured_providers & [:google, :twitter, :office365, :ldap]

    providers.delete(:twitter) if session[:old_twitter_user_id]

    providers
  end

  # Generates the login URL for a specific provider.
  def omniauth_login_url(provider)
    if provider == :ldap
      ldap_signin_path
    else
      "#{Rails.configuration.relative_url_root}/auth/#{provider}"
    end
  end

  # Determine if Greenlight is configured to allow user signups.
  def allow_user_signup?
    Rails.configuration.allow_user_signup
  end

  # Determines if the BigBlueButton endpoint is the default.
  def bigbluebutton_endpoint_default?
    Rails.configuration.bigbluebutton_endpoint_default == Rails.configuration.bigbluebutton_endpoint
  end

  # Returns language selection options
  def language_options
    locales = I18n.available_locales
    language_opts = [['<<<< ' + t("language_default") + ' >>>>', "default"]]
    locales.each do |locale|
      language_mapping = I18n::Language::Mapping.language_mapping_list[locale.to_s.gsub("_", "-")]
      language_opts.push([language_mapping["nativeName"], locale.to_s])
    end
    language_opts.sort
  end

  # Parses markdown for rendering.
  def markdown(text)
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML,
      no_intra_emphasis: true,
      fenced_code_blocks: true,
      disable_indented_code_blocks: true,
      autolink: true,
      tables: true,
      underline: true,
      highlight: true)

    markdown.render(text).html_safe
  end

  def allow_greenlight_accounts?
    return Rails.configuration.allow_user_signup unless Rails.configuration.loadbalanced_configuration
    return false unless @user_domain && !@user_domain.empty? && Rails.configuration.allow_user_signup
    return false if @user_domain == "greenlight"
    # Proceed with retrieving the provider info
    begin
      provider_info = retrieve_provider_info(@user_domain, 'api2', 'getUserGreenlightCredentials')
      provider_info['provider'] == 'greenlight'
    rescue => e
      logger.info e
      false
    end
  end

  # Return all the translations available in the client side through javascript
  def current_translations
    @translations ||= I18n.backend.send(:translations)
    @translations[I18n.locale]
  end

  # Return the fallback translations available in the client side through javascript
  def fallback_translations
    @fallback_translations ||= I18n.backend.send(:translations)
    @fallback_translations[I18n.default_locale]
  end

  # Returns the page that the logo redirects to when clicked on
  def home_page
    return root_path unless current_user
    return admins_path if current_user.has_role? :super_admin
    current_user.main_room
  end

  def role_colour(role)
    role.colour || Rails.configuration.primary_color_default
  end

  def translated_role_name(role)
    if role.name == "denied"
      I18n.t("roles.banned")
    elsif role.name == "pending"
      I18n.t("roles.pending")
    elsif role.name == "admin"
      I18n.t("roles.admin")
    elsif role.name == "user"
      I18n.t("roles.user")
    else
      role.name
    end
  end

  def can_reset_password
    # Check if admin is editting user and user is a greenlight account
    Rails.configuration.enable_email_verification &&
      Rails.application.routes.recognize_path(request.env['PATH_INFO'])[:action] == "edit_user" &&
      @user.greenlight_account?
  end

  def google_analytics_url
    "https://www.googletagmanager.com/gtag/js?id=#{ENV['GOOGLE_ANALYTICS_TRACKING_ID']}"
  end

  def valid_url?(input)
    uri = URI.parse(input)
    !uri.host.nil?
  rescue URI::InvalidURIError
    false
  end
end
