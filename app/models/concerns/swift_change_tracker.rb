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

module SwiftChangeTracker

  extend ActiveSupport::Concern

  included do
    after_update_commit :after_update_log_swift_changes
    after_create_commit :after_create_log_swift_changes
    after_destroy_commit :after_destroy_log_swift_changes
  end

  class << self
    def skip_attributes_in_swift_log
      %w[comment description id updated_at]
    end
  end

  def after_update_log_swift_changes
    return if Chef::SwiftTracker.skip?

    all_changes = []
    skip_fields = (self.class.skip_attributes_in_swift_log rescue []) + SwiftChangeTracker.skip_attributes_in_swift_log

    self.saved_changes.reject { |field, values| skip_fields.include?(field) }.each do |field, values|
      if field =~ /.*_id$/
        # References
        ref_field = field.gsub(/_id$/,'')
        reference1 = values.first.blank? ? nil : (self.send(ref_field).class.base_class.find(values.first) rescue nil)
        reference2 = values.second.blank? ? nil : (self.send(ref_field).class.base_class.find(values.second) rescue nil)

        name = ref_field.titleize
        if reference1.blank?
          if self.class.to_s == 'Access' and ref_field == 'profile' and reference2.blank?
            change = "Set Profile to 'DENY'"
          else
            change = "Set #{name} to '#{object_identifier(reference2)}'"
          end
        else
          if reference2.blank?
            change = "Removed #{name} '#{object_identifier(reference1)}'"
          else
            change = "Changed #{name} from '#{object_identifier(reference1)}' to '#{object_identifier(reference2)}'"
          end
        end
      else
        # Attributes
        if self.class == PartitionSetting
          name = "#{object_class_title} / #{field.titleize}"
        else
          name = "#{object_class_title} / #{field.titleize} of '#{object_identifier}'"
        end
        if %w[password TargetPassword].include?(field)
          fname = field.titleize
          change = if values.last.blank?
                     "Removed #{fname} from #{object_class_title} '#{object_identifier}'"
                   elsif values.first.blank?
                     "Added #{fname} to #{object_class_title} '#{object_identifier}'"
                   else
                     "Changed #{fname} of #{object_class_title} '#{object_identifier}'"
                   end
        else
          change = case self.send(field).class.to_s
                   when 'Array'
                     c   = []
                     add = (values.last - values.first)
                     c << "Added #{add.collect { |v| "'#{v}'" }.join(', ')} to list #{name}." if add.count > 0
                     rem = (values.first.reject { |x| x.blank? } - values.last.reject { |x| x.blank? })
                     c << "Removed #{rem.collect { |v| "'#{v}'" }.join(', ')} from list #{name}." if rem.count > 0
                     if c.blank? and values.first != values.last
                       c << "Changed order in list #{name}"
                     end
                     c.join(', ')
                   when 'String'
                     "Changed #{name} from '#{values.first}' into '#{values.last}'." if (values.first != values.last)
                   when 'Integer'
                     "Changed #{name} from #{values.first} into #{values.last}." if values.first != values.last
                   when 'FalseClass', 'TrueClass'
                     "Switched #{name} from #{%w(OFF ON)[values.first && 1 || 0]} to #{%w(OFF ON)[values.last && 1 || 0]}." if values.first != values.last
                   else
                     "Updated #{name}."
                   end
        end
      end

      all_changes << change unless change.blank?
    end

    update_swift_change_trail(all_changes) if all_changes.any?
  end

  def after_create_log_swift_changes
    return if Chef::SwiftTracker.skip?

    change_trail = ["Created #{object_class_title} '#{object_identifier}'"]
    update_swift_change_trail(change_trail)
  end

  def after_destroy_log_swift_changes
    return if Chef::SwiftTracker.skip?

    change_trail = ["Deleted #{object_class_title} '#{object_identifier}'"]
    update_swift_change_trail(change_trail)
  end

  def after_add_relation(obj)
    return if Chef::SwiftTracker.skip?

    # Ensure that changes related to *obj* are tracked with this SwiftChange
    obj.instance_variable_set(:@swift_change, swift_change)

    change_trail = ["Added #{object_class_title(obj)} '#{object_identifier(obj)}' to #{object_class_title} '#{object_identifier}'"]
    # Defer saving the SwiftChange when *obj* not persisted yet
    update_swift_change_trail(change_trail, save: obj.persisted?)
  end

  def after_remove_relation(obj)
    return if Chef::SwiftTracker.skip?

    # Ensure that changes related to *obj* are tracked with this SwiftChange
    obj.instance_variable_set(:@swift_change, swift_change)

    change_trail = ["Removed #{object_class_title(obj)} '#{object_identifier(obj)}' from #{object_class_title} '#{object_identifier}'"]
    update_swift_change_trail(change_trail)
  end

  def current_swift_change
    @swift_change
  end

  private

  def swift_change
    return @swift_change if @swift_change.present?

    @swift_change = SwiftChange.new_for(self, change_trail: [], whodunit:)
  end

  def object_class_title(obj = self)
    obj.class.to_s.underscore.titleize
  end

  def object_identifier(obj = self)
    obj.try(:name) || obj.try(:title) || 'unknown'
  end

  def update_swift_change_trail(change_trail, save: true)
    return false if swift_change.partition.nil?
    return false if change_trail.blank?

    swift_change.change_trail += change_trail
    swift_change.save if swift_change.change_trail.present? && save

    swift_change.persisted?
  end

  def whodunit
    User.current_user&.name || RequestStore.store[:swift_track_whodunit] || 'System'
  end
end
