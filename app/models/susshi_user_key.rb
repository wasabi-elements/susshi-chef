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

class SusshiUserKey < SshKey

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :susshi_user_login

  #-- Scopes

  # Delegations used for SwiftChangeTracker
  delegate :partition, to: :susshi_user_login
  alias_attribute :name, :title

  #-- Validations

  validates :title, presence: true
  validates :title, uniqueness: { case_sensitive: false, scope: :susshi_user_login, message: 'another public key with same title already exists for this user' }
  validates :public_blob, uniqueness: { case_sensitive: false, scope: :susshi_user_login, message: 'same public key already exists for this user' }
  validate :validate_key_type_is_allowed

  #-- Class Methods

  class << self
    def api_query_base
      self.includes([:susshi_user_login]).joins(:susshi_user_login).order('title ASC')
    end
  end

  #-- Instance Methods

  private

  def validate_key_type_is_allowed
    if self.key_type == 'ssh-rsa'
      i = [self.bits / 1024, 4].min
      bits = [0, 1024, 2048, 3072, 4096][i]
    else
      bits = self.bits
    end
    unless self.susshi_user_login.partition.partition_setting.AllowedUserKeyTypes.include?("#{self.key_type}:#{bits}")
      errors.add(:public_blob, "User keys of this type and/or bit length are not permitted by policy.")
    end
  end

end
