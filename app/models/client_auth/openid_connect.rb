# Copyright (C) 2026 Wasabi Elements GmbH
#
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

class ClientAuth::OpenidConnect < ClientAuth

  PROPERTIES = {
    kbd_int_auth_title:       {
      as:          :text,
      label:       "Title",
      icon:        "fa-info",
      placeholder: "suSSHi2 Gateway OpenID Connect authentication"
    },
    kbd_int_auth_instruction: {
      as:          :text,
      label:       "Instruction",
      icon:        "fa-info",
      placeholder: "Please login on https://susshi.company/o/%secret%\n\nYour session will continue once you have authenticated successfully.",
      hint:        "The text must include the variable %secret% that will get filled with the actual secret during authentication.",
      input_html:  { rows: 3 }
    },
    session_end_on_logout: {
      as:          :boolean,
      title:       "Active session termination",
      label:       "End active user SSH sessions on OpenID connect logout?",
      icon:        "fa-stop-circle"
    }
  }

  #-- Validators

  validates :kbd_int_auth_instruction, format: { with: /\A.*%secret%.*\z/m, message: 'must at least include the variable %secret%' }, allow_blank: true
  validates :session_end_on_logout, inclusion: { in: %w[0 1] }

  #-- Class methods

  class << self
    def icon
      "fa-brands fa-openid"
    end

    def category
      "interactive"
    end

    def type_for_collection
      ["OpenID Connect", name]
    end

    def valid_user_input?(swift_susshi_user:, user_input:, properties: {})
      false
    end
  end

  #-- Instance methods

  def required_auth
    "openid-connect"
  end

  def preferred_authentications
    %w[openid-connect]
  end

end
