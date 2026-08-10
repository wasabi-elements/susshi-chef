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

class TargetUserRegex < TargetUser

  #-- Datatypes

  #-- Associations

  #-- Scopes

  scope :has_any_memberships, -> {
    joins("JOIN target_user_memberships ON target_users.id = target_user_memberships.target_user_id")
        .where("target_user_memberships.target_user_id IS NOT NULL").distinct
  }

  scope :has_not_any_memberships, -> {
    joins("LEFT JOIN target_user_memberships ON target_users.id = target_user_memberships.target_user_id")
        .where("target_user_memberships.target_user_id IS NULL").distinct
  }

  #-- Validations

  validates :name, format: { with: /\A[a-zA-Z0-9._ \-]+\z/, message: 'contains invalid characters'  }
  validates :regex, presence: true

  #-- Callbacks

  before_save :before_save_regex_effective

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetUserRegex.where(partition: User.current_user.partition).count
    end

  end
  #-- Instance Methods

  def icon
    self.name == 'Any' ? 'far fa-star' : 'far fa-comment-dots'
  end

  private

  def before_save_regex_effective
    self.regex_effective = "^#{self.regex}$"
  end

end