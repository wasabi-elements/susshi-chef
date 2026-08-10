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

class TargetUserGroup < TargetUser

  #-- Datatypes

  alias_attribute :groupname, :name

  #-- Associations
  has_many :target_user_memberships, dependent: :destroy
  has_many :target_users, -> { distinct }, through: :target_user_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  #-- Scopes

  scope :has_any_members, -> {
    joins("JOIN target_user_memberships ON target_users.id = target_user_memberships.target_user_group_id")
        .where("target_user_memberships.target_user_group_id IS NOT NULL").distinct
  }

  scope :has_not_any_members, -> {
    joins("LEFT JOIN target_user_memberships ON target_users.id = target_user_memberships.target_user_group_id")
        .where("target_user_memberships.target_user_group_id IS NULL").distinct
  }

  #-- Validations
  validates :name, format: { with: /\A[a-zA-Z0-9._:@ \-]+\z/, message: 'contains invalid characters'  }

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetUserGroup.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      TargetUserGroup.where(partition_id: partition_id).order("LOWER(name) ASC").all.pluck(:name, :id).collect{|u| ["#{u.first} (Group)", u.last] }
    end

    def api_query_base
      self.includes([:target_users]).order('target_users.name ASC')
    end
  end

  #-- Instance Methods

  def icon
    'fa fa-users'
  end

  #-- Methods used by config API
  def members
    self.target_users.pluck(:name)
  end

  def members=(values)
    self.target_users = TargetUser.query_by_ids_or_names('members', self.partition_id, values).where.not(type: 'TargetUserGroup')
  end

  def members_add(values)
    self.target_users << TargetUser.query_by_ids_or_names('members', self.partition_id, values, self.target_users).where.not(type: 'TargetUserGroup')
  end

  def members_remove(values)
    self.target_users.delete TargetUser.query_by_ids_or_names('members', self.partition_id, values).where.not(type: 'TargetUserGroup')
  end

  def memberships
    raise 'illegal method for group'
  end

  def memberships=(values)
    raise 'illegal method for group'
  end

  def memberships_add(values)
    raise 'illegal method for group'
  end

  def memberships_remove(values)
    raise 'illegal method for group'
  end

end