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

module ThemingHelper
  # Returns the logo based on user's provider
  def logo_image
    @settings.get_value("Branding Image") || Rails.configuration.branding_image_default
  end

  # Returns the legal URL based on user's provider
  def legal_url
    @settings.get_value("Legal URL") || ""
  end

  # Returns the privacy policy URL based on user's provider
  def privpolicy_url
    @settings.get_value("Privacy Policy URL") || ""
  end

  # Returns the default presentation URL based on user's provider
  def presentation_url
    @settings.get_value("Default Presentation URL") || ""
  end

  # Returns the primary color based on user's provider
  def user_color
    @settings.get_value("Primary Color") || Rails.configuration.primary_color_default
  end

  def maintenance_banner
    @settings.get_value("Maintenance Banner")
  end
end
