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

class ClientAuth::Totp < ClientAuth

  PROPERTIES = {
    kbd_int_auth_title:       {
      as:          :text,
      label:       "KBD-Interactive Title",
      icon:        "fa-info",
      placeholder: "suSSHi2 Gateway authentication"
    },
    kbd_int_auth_instruction: {
      as:          :text,
      label:       "KBD-Interactive Instruction",
      icon:        "fa-info",
      placeholder: "\nPlease login with your TOTP token.\n"
    },
    kbd_int_auth_prompt:      {
      label:       "KBD-Interactive Prompt",
      icon:        "fa-info",
      placeholder: "Gateway password:_"
    },
  }

  #-- Class methods

  class << self
    def icon
      "fa-sim-card"
    end

    def category
      "interactive"
    end

    def type_available?
      Preference.totp_secret_key_set?
    end

    def type_for_collection
      ["Time-based OTP", name]
    end

    def valid_user_input?(swift_susshi_user:, user_input:, properties: {})
      begin
        swift_susshi_user.verify_totp!(user_input)
        true
      rescue
        false
      end
    end
  end

end
