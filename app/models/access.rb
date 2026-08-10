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

class Access < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition
  belongs_to :profile, optional: true

  has_many :accesses_source_ips, dependent: :destroy
  has_many :source_ips, -> { distinct }, through: :accesses_source_ips,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :accesses_susshi_users, dependent: :destroy
  has_many :susshi_users, -> { distinct }, through: :accesses_susshi_users,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :accesses_target_users, dependent: :destroy
  has_many :target_users, -> { distinct }, through: :accesses_target_users,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :accesses_targets, dependent: :destroy
  has_many :targets, -> { distinct }, through: :accesses_targets,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :accesses_target_fusions, dependent: :destroy
  has_many :target_fusions, -> { distinct }, through: :accesses_target_fusions,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  #-- Acts as list
  acts_as_list scope: :partition

  #-- Callbacks

  #-- Validations

  validates :name, uniqueness: { case_sensitive: false, scope: :partition_id, message: 'same name already exists within partition', allow_blank: true }

  validates :source_ip_ids, presence: { message: 'at least one source ip address has to be selected'}
  validates :debug_level, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3, allow_blank: false}

  with_options if: -> { self.target_fusions.any? } do |fusion|
    fusion.validates :target_user_ids, absence: { message: 'target users cannot be selected together with target fusions'}
    fusion.validates :target_ids, absence: { message: 'targets cannot be selected together with target fusions'}
  end

  with_options if: -> { self.target_fusions.empty? } do |fusion|
    fusion.validates :target_user_ids, presence: { message: 'at least one target user has to be selected'}
    fusion.validates :target_ids, presence: { message: 'at least one target has to be selected'}
  end

  #-- Class Methods

  class << self

    def icon
      'fa-gem'
    end

    def active_collection
      [ ['Active', true], ['Inactive', false] ]
    end

    def count_for_partition(active)
      return 0 if User.current_user.partition.blank?
      Access.where(partition: User.current_user.partition, active: active).count
    end

    def count_by_time(cont, sum_only = false)
      cont = sanitize_sql(cont)

      if sum_only
        SessionReport.where("(#{cont}) AND (session_start > ?)", Time.now - 1.day - 1.minute).count
      else
        a = Hash[*(0..24).collect{|x| [x, 0] }.flatten].merge(
            Hash[*SessionReport.connection.select_all("SELECT EXTRACT(hour from session_start) AS hour, COUNT(id) from session_reports WHERE (#{cont}) AND (session_start > '#{Time.now - 1.day - 2.hour}') GROUP BY hour").collect{|s| [ s['hour'].to_i, s['count'] ]}.flatten]
        ).to_a
        a[24] = [24, a.first.second]
        return a
      end
    end

    def count_by_time_7days(cont, sum_only = false)
      cont = sanitize_sql(cont)

      if sum_only
        SessionReport.where("(#{cont}) AND (session_start > ?)", Time.now - 7.day).count
      else
        a= Hash[*(0..24).collect{|x| [x, 0] }.flatten].merge(
            Hash[*SessionReport.connection.select_all("SELECT EXTRACT(hour from session_start) AS hour, COUNT(id) from session_reports WHERE (#{cont}) AND (session_start > '#{Time.now - 7.day}') GROUP BY hour").collect{|s| [ s['hour'].to_i, s['count'] ]}.flatten]
        ).to_a
        a[24] = [24, a.first.second]
        return a
      end
    end

    def count_total(cont, sum_only = false)
      cont = sanitize_sql(cont)

      if sum_only
        SessionReport.where("#{cont}").count
      else
        Hash[*(0..24).collect{|x| [x, 0] }.flatten].merge(
            Hash[*SessionReport.connection.select_all("SELECT EXTRACT(hour from session_start) AS hour, COUNT(id) from session_reports WHERE (#{cont}) GROUP BY hour").collect{|s| [ s['hour'].to_i, s['count'] ]}.flatten]
        ).to_a
      end
    end

    def debug_level_collection
      [ ['No Debug', 0], ['Level 1', 1], ['Level 2', 2], ['Level 3', 3] ]
    end

    def last_use_at_collection
      [ ['Last 24 hours', Time.now - 24.hours], ['Last 7 days', Date.today - 7.days ], ['Last 30 days', Date.today - 30.days ],
        ['Last 3 months', Date.today - 3.months ], ['Last 6 months', Date.today - 6.months ], ['Never', 'never' ] ]
    end

    def reorder(ids, dragged)
      objects = Access.where(id: ids).order(position: :asc)
      positions = objects.pluck(:position)
      ids.each_with_index do |id, index|
        if id == dragged
          Access.find_by_id(id).update(position: positions[index])
        else
          Access.find_by_id(id).update_columns(position: positions[index])
        end
      end
    end

    def activate(partition, whodunit, change_trail = ["Activated by unknown."])
      if Swift::Updater.swift_update_all(partition.id)
        SwiftChange.activate(partition.pending_swift_changes, whodunit:, change_trail:)
        true
      else
        false
      end
    end

    def skip_attributes_in_swift_log
      %w[name]
    end

    def api_query_base
      self.includes([:source_ips, :susshi_users, :target_users, :target_fusions, :profile]).order('accesses.position ASC')
    end

    def clear_statistics
      Access.all.update_all(use_count: 0, first_use_at: nil, last_use_at: nil)
    end

  end


  #-- Instance Methods

  #-- Methods used by config API
  #
  # Source IP members
  def source_ip_members
    self.source_ips.pluck(:name)
  end

  def source_ip_members=(values)
    self.source_ips = SourceIp.query_by_ids_or_names('source_ip_members', self.partition_id, values)
  end

  def source_ip_members_add(values)
    self.source_ips << SourceIp.query_by_ids_or_names('source_ip_members', self.partition_id, values, self.source_ips)
  end

  def source_ip_members_remove(values)
    self.source_ips.delete SourceIp.query_by_ids_or_names('source_ip_members', self.partition_id, values)
  end

  # Susshi User Members
  def susshi_user_members
    self.susshi_users.pluck(:name)
  end

  def susshi_user_members=(values)
    self.susshi_users = SusshiUser.query_by_ids_or_names('susshi_user_members', self.partition_id, values)
  end

  def susshi_user_members_add(values)
    self.susshi_users << SusshiUser.query_by_ids_or_names('susshi_user_members', self.partition_id, values, self.susshi_users)
  end

  def susshi_user_members_remove(values)
    self.susshi_users.delete SusshiUser.query_by_ids_or_names('susshi_user_members', self.partition_id, values)
  end

  # Target User Members
  def target_user_members
    self.target_users.pluck(:name)
  end

  def target_user_members=(values)
    self.target_users = TargetUser.query_by_ids_or_names('target_user_members', self.partition_id, values)
  end

  def target_user_members_add(values)
    self.target_users << TargetUser.query_by_ids_or_names('target_user_members', self.partition_id, values, self.target_users)
  end

  def target_user_members_remove(values)
    self.target_users.delete TargetUser.query_by_ids_or_names('target_user_members', self.partition_id, values)
  end

  # Target Members
  def target_members
    self.targets.includes(:proxy).map{ |x| [ x.name, x.proxy.try(:realm) ].compact.join('@') }
  end

  def target_members=(values)
    self.targets = Target.query_target_by_ids_or_names('target_members', self.partition_id, values)
  end

  def target_members_add(values)
    self.targets << Target.query_target_by_ids_or_names('target_members', self.partition_id, values, self.targets)
  end

  def target_members_remove(values)
    self.targets.delete Target.query_target_by_ids_or_names('target_members', self.partition_id, values)
  end


  # Target Fusion Members
  def target_fusion_members
    self.target_fusions.pluck(:name)
  end

  def target_fusion_members=(values)
    self.target_fusions = TargetFusion.query_by_ids_or_names('target_fusion_members', self.partition_id, values)
  end

  def target_fusion_members_add(values)
    self.target_fusions << TargetFusion.query_by_ids_or_names('target_fusion_members', self.partition_id, values, self.target_fusions)
  end

  def target_fusion_members_remove(values)
    self.target_fusions.delete TargetFusion.query_by_ids_or_names('target_fusion_members', self.partition_id, values)
  end

  def access_profile
    self.profile.try(:name) || 'DENY'
  end

  def access_profile=(value)
    if value.to_s == 'DENY' or value.blank?
      self.profile = nil
    else
      self.profile = Profile.query_by_ids_or_names('access_profile', self.partition_id, [value]).first
    end
  end

  def position_after=(value)
    after = case value.class.to_s
              when 'Integer'
                Access.find_by(partition_id: partition_id, position: value)
              when 'String'
                Access.find_by(partition_id: partition_id, name: value)
            end
    raise "Position not found" if after.blank?
    self.position = after.lower_item.try(:position)
  end

  def position_before=(value)
    before = case value.class.to_s
              when 'Integer'
                Access.find_by(partition_id: partition_id, position: value)
              when 'String'
                Access.find_by(partition_id: partition_id, name: value)
            end
    raise "Position not found" if before.blank?
    self.position = before.position
  end

  def is_destroyable?
    return { true: "Delete Access rule '#{self.name}' [ID #{self.id}]" } unless self.name.blank?
    { true: "Delete Access rule with ID #{self.id}" }
  end

  #-- Helper

  def id_formatted
    '%05d' % self.id
  end

  def name_not_blank
    self.name.blank? ? self.id_formatted : self.name
  end

  def position_formatted
    '%04d' % self.position
  end

end
