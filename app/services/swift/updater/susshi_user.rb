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

class Swift::Updater::SusshiUser
  class << self
    def swift_update(partition_id)
      users = []

      SwiftSusshiUser.transaction do
        # Delete old entries for this partition
        SwiftSusshiUser.where(partition_id: partition_id).delete_all

        # Find all access rules with "All" (empty list) susshi_users
        all_users_access_ids = Access.where(partition_id: partition_id, active:true).pluck(:id) - AccessesSusshiUser.includes(:access).pluck(:access_id).uniq
        # Insert new entries for this partition
        SusshiUserLogin.includes(:susshi_user_keys).where(active: true, partition_id: partition_id).each do |user|
          user_keys = {}
          user.susshi_user_keys.each do |key|
            user_keys[key.key_type] ||= []
            user_keys[key.key_type] << key.public_blob.split(/\s+/).last
          end
          user_ids  = user.susshi_user_group_ids
          user_ids << user.id
          access_ids = AccessesSusshiUser.where(susshi_user_id: user_ids).pluck(:access_id).uniq + all_users_access_ids
          bastion_ids = BastionsSusshiUser.where(susshi_user_id: user_ids).pluck(:bastion_id)
          if access_ids.any? or bastion_ids.any?
            users << SwiftSusshiUser.new(id: user.id,
                                         partition_id: partition_id,
                                         name: user.name,
                                         access_ids: access_ids,
                                         bastion_ids: bastion_ids,
                                         keys: user_keys,
                                         password: user.password.blank? ? nil : user.password,
                                         totp_state: user.totp_state,
                                         totp_secret: user.totp_secret,
                                         totp_activation_token: user.totp_activation_token,
                                         totp_consumed_timestamp: user.totp_consumed_timestamp.try(:to_i),
                                         auth_fails: user.auth_fails.try(:to_i),
                                         last_auth_fail_at: user.last_auth_fail_at,
                                         shell_login: user.ShellLogin)
          end
        end
        SwiftSusshiUser.import users, :validate => false
      end
    end

    def swift_update_keys(susshi_user_login)
      return false unless susshi_user_login.is_a? SusshiUserLogin

      swift_susshi_user = SwiftSusshiUser.find_by(id: susshi_user_login.id, partition_id: susshi_user_login.partition_id)
      if swift_susshi_user
        keys_hash = susshi_user_login.susshi_user_keys.group_by(&:key_type).transform_values do |keys|
          keys.map { |key| key.public_blob.split(/\s+/).last }
        end

        swift_susshi_user.update_column(:keys, keys_hash) if swift_susshi_user
      end

      true
    end
  end
end
