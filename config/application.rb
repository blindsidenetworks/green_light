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

require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Greenlight
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    def parse_bool(val, default = false)
      val = ActiveModel::Type::Boolean.new.cast(val)
      val.nil? ? default : val
    end

    # Use custom error routes.
    config.exceptions_app = routes

    # Configure I18n localization.
    config.i18n.available_locales = [:en]
    config.i18n.default_locale = :en

    # Check if a loadbalancer is configured.
    config.loadbalanced_configuration = ENV["LOADBALANCER_ENDPOINT"].present? && ENV["LOADBALANCER_SECRET"].present?

    # The default callback url that bn launcher will redirect to
    config.gl_callback_url = ENV["GL_CALLBACK_URL"]

    # Default credentials (test-install.blindsidenetworks.com/bigbluebutton).
    config.bigbluebutton_endpoint_default = "http://test-install.blindsidenetworks.com/bigbluebutton/api/"
    config.bigbluebutton_secret_default = "8cd8ef52e8e101574e400365b55e11a6"

    # Use standalone BigBlueButton server.
    config.bigbluebutton_endpoint = if ENV["BIGBLUEBUTTON_ENDPOINT"].present?
      ENV["BIGBLUEBUTTON_ENDPOINT"]
    else
      config.bigbluebutton_endpoint_default
    end

    config.bigbluebutton_secret = if ENV["BIGBLUEBUTTON_SECRET"].present?
      ENV["BIGBLUEBUTTON_SECRET"]
    else
      config.bigbluebutton_secret_default
    end

    # Fix endpoint format if required.
    config.bigbluebutton_endpoint += "/" unless config.bigbluebutton_endpoint.ends_with?('/')
    config.bigbluebutton_endpoint += "api/" if config.bigbluebutton_endpoint.ends_with?('bigbluebutton/')
    config.bigbluebutton_endpoint +=
      "bigbluebutton/api/" unless config.bigbluebutton_endpoint.ends_with?('bigbluebutton/api/')

    if config.loadbalanced_configuration
      # Settings for fetching credentials from a loadbalancer based on provider.
      config.loadbalancer_endpoint = ENV["LOADBALANCER_ENDPOINT"]
      config.loadbalancer_secret = ENV["LOADBALANCER_SECRET"]
      config.launcher_secret = ENV["LAUNCHER_SECRET"]

      # Fix endpoint format if required.
      config.loadbalancer_endpoint += "/" unless config.bigbluebutton_endpoint.ends_with?("/")
      config.loadbalancer_endpoint = config.loadbalancer_endpoint.chomp("api/")

      # Configure which settings are available to user on room creation/edit after creation
      config.url_host = ENV['URL_HOST'] || ''
    end

    # Specify the email address that all mail is sent from
    config.smtp_sender = ENV['SMTP_SENDER'] || "notifications@example.com"

    # Determine if GreenLight should enable email verification
    config.enable_email_verification = parse_bool(ENV['ALLOW_MAIL_NOTIFICATIONS'])

    # Determine if GreenLight should require a certain mail-domain
    config.require_email_domain = ENV["GREENLIGHT_ACCOUNT_HD"].to_s.split(",")

    # Determine if GreenLight should allow non-omniauth signup/login.
    config.allow_user_signup = parse_bool(ENV['ALLOW_GREENLIGHT_ACCOUNTS'])

    # Configure custom banner message.
    config.banner_message = ENV['BANNER_MESSAGE']

    # Enable/disable recording thumbnails.
    config.recording_thumbnails = parse_bool(ENV['RECORDING_THUMBNAILS'], true)

    # Configure which settings are available to user on room creation/edit after creation
    config.room_features = ENV['ROOM_FEATURES'] || ""

    # The maximum number of rooms included in one bbbapi call
    config.pagination_number = ENV['PAGINATION_NUMBER'].to_i.zero? ? 25 : ENV['PAGINATION_NUMBER'].to_i

    # Number of rows to display per page
    config.pagination_rows = ENV['NUMBER_OF_ROWS'].to_i.zero? ? 25 : ENV['NUMBER_OF_ROWS'].to_i

    # Whether the user has defined the variables required for recaptcha
    config.recaptcha_enabled = ENV['RECAPTCHA_SITE_KEY'].present? && ENV['RECAPTCHA_SECRET_KEY'].present?

    # Show/hide "Add to Google Calendar" button in the room page
    config.enable_google_calendar_button = parse_bool(ENV['ENABLE_GOOGLE_CALENDAR_BUTTON'])

    # Enum containing the different possible registration methods
    config.registration_methods = { open: "0", invite: "1", approval: "2" }

    config.google_analytics = ENV["GOOGLE_ANALYTICS_TRACKING_ID"].present?

    # Will always be true unless explicitly set to false
    config.enable_cache = parse_bool(ENV["ENABLE_CACHED_PROVIDER"], true)

    # MAINTENANCE
    config.maintenance_window = ENV["MAINTENANCE_WINDOW"]
    config.maintenance_mode = parse_bool(ENV["MAINTENANCE_MODE"])

    config.report_issue_url = ENV["REPORT_ISSUE_URL"]
    config.help_url = ENV["HELP_URL"].nil? ? "https://docs.bigbluebutton.org/greenlight/gl-overview.html" : ENV["HELP_URL"]

    # File types allowed in preupload presentation
    config.allowed_file_types = ".doc,.docx,.ppt,.pptx,.pdf,.xls,.xlsx,.txt,.rtf,.odt,.ods,.odp,.odg,.odc,.odi,.jpg,.jpeg,.png"

    # Default locale
    config.default_locale = ENV["DEFAULT_LOCALE"]

    # DEFAULTS

    # Default branding image if the user does not specify one
    config.branding_image_default = "https://raw.githubusercontent.com/bigbluebutton/greenlight/master/app/assets/images/logo_with_text.png"

    # Default primary color if the user does not specify one
    config.primary_color_default = "#467fcf"

    # Default primary color lighten if the user does not specify one
    config.primary_color_lighten_default = "#e8eff9"

    # Default primary color darken if the user does not specify one
    config.primary_color_darken_default = "#316cbe"

    # Default registration method if the user does not specify one
    config.registration_method_default = case ENV["DEFAULT_REGISTRATION"]
                                         when "invite"
      config.registration_methods[:invite]
    when "approval"
      config.registration_methods[:approval]
    else
      config.registration_methods[:open]
    end

    # Default limit on number of rooms users can create
    config.number_of_rooms_default = 15

    # Allow users to share rooms by default
    config.shared_access_default = "true"

    # Don't require recording consent by default
    config.require_consent_default = "false"

    # Don't allow users to preupload presentations by default
    config.preupload_presentation_default = "false"

    # Phone number
    config.voice_bridge_phone_number = ENV['VOICE_BRIDGE_PHONE_NUMBER']
    # Don't show option to generate moderator access codes
    config.moderator_codes_default = "disabled"

    # Default admin password
    config.admin_password_default = ENV['ADMIN_PASSWORD'] || 'administrator'
  end
end
