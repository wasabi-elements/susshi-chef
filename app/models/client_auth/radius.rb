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

require "radius/auth"

class ClientAuth::Radius < ClientAuth

  DEFAULT_SERVER_PORT = 1812
  DEFAULT_SERVER_TIMEOUT = 3

  PROPERTIES = {
    kbd_int_auth_title: {
      as: :text,
      label: "KBD-Interactive Title",
      icon: "fa-info",
      placeholder: "suSSHi2 Gateway authentication"
    },
    kbd_int_auth_instruction: {
      as: :text,
      label: "KBD-Interactive Instruction",
      icon: "fa-info",
      placeholder: "\nPlease login with your Radius password.\n"
    },
    kbd_int_auth_prompt: {
      label: "KBD-Interactive Prompt",
      icon: "fa-info",
      placeholder: "Gateway password:_"
    },
    auth_server: {
      label: "Radius Server IP",
      icon: "fa-network-wired"
    },
    auth_secret: {
      label: "Radius Server Secret",
      icon: "fa-key"
    },
    auth_port: {
      label: "Radius Server Port",
      icon: "fa-futbol",
      placeholder: DEFAULT_SERVER_PORT.to_s
    },
    auth_timeout: {
      label: "Radius Server Timeout",
      icon: "fa-clock",
      hint: "In seconds, default timeout is 3 seconds.",
      placeholder: DEFAULT_SERVER_TIMEOUT.to_s
    }
  }

  #-- Validations

  validates :auth_server, presence: true
  validates :auth_secret, presence: true
  validates :auth_port, inclusion: { in: 1..65534, message: "port must be in range 1..65534", allow_blank: true }
  validates :auth_timeout, inclusion: { in: 1..10, message: "timeout must be in range 1..10", allow_blank: true }

  #-- Class methods

  class << self
    def icon
      "fa-circle-notch"
    end

    def category
      "interactive"
    end

    def type_for_collection
      ["Radius server backend", name]
    end

    def valid_user_input?(swift_susshi_user:, user_input:, properties: {})
      radius = Radius::Auth.new(
        properties["auth_server"],
        nil,
        properties["auth_timeout"],
        Rails.root.join("app", "lib", "radius", "dictionary.rfc2865").to_s
      )

      radius.check_passwd(swift_susshi_user.name, user_input, properties["auth_secret"])
    rescue Exception => e
      false
    end
  end

  #-- Instance methods

  def radius_auth_port=(value)
    super (value.blank? ? DEFAULT_SERVER_PORT : value).try(:to_i)
  end

  def radius_auth_timeout=(value)
    super (value.blank? ? DEFAULT_SERVER_TIMEOUT : value).try(:to_i)
  end

end
