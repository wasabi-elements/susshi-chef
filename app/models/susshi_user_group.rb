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

class SusshiUserGroup < SusshiUser

  #-- Datatypes

  alias_attribute :groupname, :name
  alias_attribute :description, :fullname

  #-- Associations

  has_many :susshi_user_memberships, dependent: :destroy
  has_many :susshi_user_logins, -> { distinct }, through: :susshi_user_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  #-- Scopes

  scope :has_any_members, -> {
    joins("JOIN susshi_user_memberships ON susshi_users.id = susshi_user_memberships.susshi_user_group_id")
        .where("susshi_user_memberships.susshi_user_group_id IS NOT NULL").distinct
  }

  scope :has_not_any_members, -> {
    joins("LEFT JOIN susshi_user_memberships ON susshi_users.id = susshi_user_memberships.susshi_user_group_id")
        .where("susshi_user_memberships.susshi_user_group_id IS NULL").distinct
  }

  #-- Validations
  validates :groupname, :presence => true
  validates :groupname, exclusion: { in: %w(ALL), message: 'ALL is a reserved keyword' }
  validates :groupname, format: { with: /\A[a-zA-Z0-9._:@\\\/\- ]+\z/, message: 'contains invalid characters'  }
  validates :groupname, :uniqueness => { case_sensitive: false, scope: :partition_id, message: 'gateway user with same name already exists within partition' }

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      SusshiUserGroup.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      SusshiUserGroup.where(partition_id: partition_id).order("LOWER(name) ASC").all.pluck(:name, :id)
          .collect{|t| ["#{t.first} (Group)", t.last]}
    end

    def skip_attributes_in_swift_log
      %w(fullname email)
    end

    def api_query_base
      self.includes([:susshi_user_logins]).order('susshi_users.name ASC')
    end
  end

  #-- Instance Methods

  def icon
    'fa-users'
  end

  #-- Methods used by config API
  def members
    self.susshi_user_logins.pluck(:name)
  end

  def members=(values)
    self.susshi_user_logins = SusshiUserLogin.query_by_ids_or_names('members', self.partition_id, values)
  end

  def members_add(values)
    self.susshi_user_logins << SusshiUserLogin.query_by_ids_or_names('members', self.partition_id, values, self.susshi_user_logins)
  end

  def members_remove(values)
    self.susshi_user_logins.delete SusshiUserLogin.query_by_ids_or_names('members', self.partition_id, values)
  end

end