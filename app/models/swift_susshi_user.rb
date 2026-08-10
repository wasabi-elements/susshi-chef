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

class SwiftSusshiUser < Swift
  encrypts :properties

  store_accessor :properties, [
    :totp_state,
    :totp_consumed_timestamp,
    :totp_secret,
    :totp_activation_token,
    :auth_fails,
    :last_auth_fail_at
  ]

  belongs_to :partition
  has_many :swift_ip_cachings, dependent: :destroy

  # Old method, used by /api/v1/users/password controller (called from suSSHi Gateways < 21.10)
  def valid_password?(user_password)
    if (terms = self.password.split('$') rescue []).size == 4
      self.password == "$6$#{terms[2]}$#{Digest::SHA512.hexdigest("#{terms[2]}#{user_password}")}"
    else
      false
    end
  end

  # New method, used by /api/v2/users/password controller
  def valid_interactive_input?(user_input:, client_auth_set:)
    begin
      # The password auth properties contain all required information for authentication method
      properties = client_auth_set.interactive_auth_properties

      # Extract authenticator class and return result of its valid_user_input? class method
      klass = properties.delete('type')
      unless klass == 'none'
        return klass.constantize.valid_user_input?(swift_susshi_user: self, user_input: user_input, properties: properties)
      end
    rescue
    end

    false
  end

  def verify_totp!(totp_code)
    self.reload

    last_otp_at = self.totp.verify(
      totp_code, after: (self.totp_consumed_timestamp || 0).to_i, drift_behind: 15
    )

    raise Errors::Totp::Verification if last_otp_at.blank?

    self.with_lock { self.update(totp_consumed_timestamp: last_otp_at) }
    update_susshi_user_login(skip_tracker: true) { |u| u.totp_consumed_timestamp = last_otp_at }

    true
  end

  def auth_failed!
    settings = SwiftPartition.find(partition_id)&.config || {}
    max_auth_fails = settings["MaxAuthFails"] || 5

    self.auth_fails = (self.auth_fails || 0) + 1
    self.auth_fails = max_auth_fails if self.auth_fails > max_auth_fails
    self.last_auth_fail_at = Time.now.to_i
    save

    update_susshi_user_login(skip_tracker: true) do |u|
      u.auth_fails = self.auth_fails
      u.last_auth_fail_at = self.last_auth_fail_at
    end
  end

  def auth_successful!
    properties.delete('auth_fails')
    properties.delete('last_auth_fail_at')
    save

    update_susshi_user_login(skip_tracker: true) do |u|
      u.properties.delete('auth_fails')
      u.properties.delete('last_auth_fail_at')
    end
  end

  def auth_passable?
    settings = SwiftPartition.find(partition_id)&.config || {}
    max_auth_fails = settings["MaxAuthFails"] || 5
    block_auth_seconds = settings["BlockAuthSeconds"] || 900

    fails = (self.auth_fails || 0).to_i
    unless self.last_auth_fail_at.blank?
      fails = fails - ((Time.now.to_i - self.last_auth_fail_at.to_i) / (block_auth_seconds))
      self.auth_fails = fails < 0 ? 0 : fails
      self.last_auth_fail_at = nil if self.auth_fails == 0
      save

      update_susshi_user_login(skip_tracker: true) do |u|
        u.auth_fails = self.auth_fails
        u.last_auth_fail_at = nil if self.auth_fails == 0
      end
    end

    fails < max_auth_fails
  end

  private

  def totp
    raise Errors::Totp::Any, 'TOTP not active for user' if self.totp_state != 'active'
    ROTP::TOTP.new(self.totp_secret)
  end

  def update_susshi_user_login(skip_tracker:)
    unless (user = SusshiUserLogin.find_by(id: self.id)).nil?
      Chef::SwiftTracker.skip = true if skip_tracker

      yield user
      user.save

      Chef::SwiftTracker.skip = false if skip_tracker
    end
  end

end
