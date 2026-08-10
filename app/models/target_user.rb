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

class TargetUser < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations

  belongs_to :partition

  has_many :target_user_memberships, dependent: :destroy
  has_many :target_user_groups, -> { distinct }, through: :target_user_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :accesses_target_users, dependent: :restrict_with_error
  has_many :accesses, -> { distinct }, through: :accesses_target_users

  has_many :group_accesses, -> { distinct }, through: :target_user_groups, source: :accesses

  has_many :target_fusions

  #-- Scopes

  #-- Validations

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: true, scope: :partition_id, message: 'same name already exists within partition' }

  #-- Callbacks

  after_save :touch_target_fusions

  #-- Class Methods

  class << self

    def icon
      'fa-user-circle'
    end

    def types_collection
      [ ['Target Login', 'TargetUserLogin'], ['Target Regex', 'TargetUserRegex'],
        ['Target Mapping', 'TargetUserMapping'], ['Target Group', 'TargetUserGroup'] ]
    end

    def sysint_collection
      [ ['System provided', true], ['User configured', false] ]
    end

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      TargetUser.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id, include_group = true)
      TargetUser.where(partition_id: partition_id).order("type ASC, LOWER(name) ASC").all.pluck(:type, :name, :id).collect{|u| u.first == 'TargetUserLogin' ? [u.second, u.last] : ["#{u.second} (#{u.first.gsub('TargetUser','')})", u.last] }
    end

    def api_query_base
      self.includes([:target_user_groups]).order('target_users.name ASC')
    end

  end

  #-- Instance Methods

  def type_humanized
    TargetUser.types_collection.select{|x| x.last == self.type }.first.first
  end

  def icon
    'fa fa-exclamation'
  end

  def title
    self.class.name.demodulize.titleize rescue "Target User Base"
  end

  def is_destroyable?
    return {false: 'Is provided by System'} if system_int
    return {false: 'Is assigned to an Access Rule'}  if accesses.any?
    return {false: 'Is assigned to an Target Fusion'}  if target_fusions.any?
    {true: "Delete Target User '#{self.name}'"}
  end

  #-- Methods used by config API
  def memberships
    self.target_user_groups.pluck(:name)
  end

  def memberships=(values)
    self.target_user_groups = TargetUserGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def memberships_add(values)
    self.target_user_groups << TargetUserGroup.query_by_ids_or_names('memberships', self.partition_id, values, self.target_user_groups)
  end

  def memberships_remove(values)
    self.target_user_groups.delete TargetUserGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  private

  def touch_target_fusions
    target_fusions.each do |target_fusion|
      target_fusion.save
    end
  end

end
