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

class TargetGroup < Target

  include SwiftChangeTracker

  #-- Datatypes

  alias_attribute :groupname, :name

  #-- Associations
  has_many :target_memberships, dependent: :destroy

  has_many :targets, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_hosts, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_domains, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_dynamics, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :target_networks, -> { distinct }, through: :target_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  #-- Scopes

  scope :has_any_members, -> {
    joins("JOIN target_memberships ON targets.id = target_memberships.target_group_id")
        .where("target_memberships.target_group_id IS NOT NULL").distinct
  }

  scope :has_not_any_members, -> {
    joins("LEFT JOIN target_memberships ON targets.id = target_memberships.target_group_id")
        .where("target_memberships.target_group_id IS NULL").distinct
  }

  #-- Validations

  validates :groupname, presence: true
  validates :groupname, :uniqueness => { case_sensitive: false, scope: :partition_id, message: 'target group with same name already exists within partition' }
  validates :groupname, format: { with: /\A[a-zA-Z0-9 ._:\/\-]+\z/, message: 'contains invalid characters'  }

  #-- Class Methods

  class << self

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetGroup.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      TargetGroup.where(partition_id: partition_id).order("LOWER(name) ASC").pluck(:name, :id)
    end

    def api_query_base
      self.order('targets.name ASC')
    end

  end

  #-- Instance Methods

  def icon
    'fa-layer-group'
  end

  def display_type
    'Group'
  end

  def display_name_a
    [self.name_with_proxy, "(#{display_type})"]
  end

  #-- Methods used by config API
  def members
    self.targets.includes(:proxy).map { |target| target.name_with_proxy }
  end

  def members=(values)
    self.targets = Target.query_target_by_ids_or_names('members', self.partition_id, values).where.not(type: 'TargetGroup')
  end

  def members_add(values)
    self.targets << Target.query_target_by_ids_or_names('members', self.partition_id, values, self.targets).where.not(type: 'TargetGroup')
  end

  def members_remove(values)
    self.targets.delete Target.query_target_by_ids_or_names('members', self.partition_id, values).where.not(type: 'TargetGroup')
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