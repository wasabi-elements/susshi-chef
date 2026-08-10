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

class SwiftChange < ApplicationRecord

  belongs_to :partition

  class << self
    def activate(swift_changes, whodunit: nil, change_trail: nil)
      swift_changes = Array.wrap(swift_changes)

      return false if swift_changes.none?
      return false unless swift_changes.all?(SwiftChange)
      return false if swift_changes.any?(&:new_record?)
      return false if swift_changes.map(&:swift_version).uniq.many?
      return false if swift_changes.map(&:partition_id).uniq.many?
      return false if swift_changes.any? { |sc| sc.klass == "Activation" }

      activated = false
      partition = swift_changes.first.partition

      SwiftChange.transaction do
        partition.lock!

        if SwiftChange.exists?(klass: "Activation", partition:, swift_version: partition.current_swift_version)
          raise ActiveRecord::Rollback
        end

        # Find remaining SwiftChanges in case of a partial activation
        remaining_swift_changes = partition.pending_swift_changes.where.not(id: swift_changes.map(&:id))

        whodunit ||= User.current_user&.name || "System"
        change_trail = ["Activated by #{whodunit}."] if change_trail.blank?

        SwiftChange.create_for(partition, klass: "Activation", change_trail: change_trail, whodunit:)

        partition.increment!(:current_swift_version)

        # Update the version for remaining SwiftChanges, if any
        remaining_swift_changes.update_all(swift_version: partition.current_swift_version)

        if Gateway.restart_required?(partition, partition.previous_swift_version)
          Susshid::RemoteControl.restart_all(partition.id)
        end

        if Rsyslog::Daemon.restart_required?(partition, partition.previous_swift_version)
          Rsyslog::Daemon.restart
        end

        activated = true
      end

      activated
    end

    def activations_collection
      SwiftChange
        .where(partition_id: User.current_user.partition.id, klass: 'Activation')
        .where("swift_version >= ?", 0)
        .order(created_at: :desc)
        .pluck(:swift_version, :created_at, :change_trail)
        .collect {|c| ["#{'%04d' % c[0] } - #{c[1]} - #{c[2].join(', ')}", c[0]]}
    end

    def create_for(object, **attributes)
      new(attributes_for(object, **attributes)).save
    end

    def new_for(object, **attributes)
      new(attributes_for(object, **attributes))
    end

    private

    def attributes_for(object, **attributes)
      partition = attributes.delete(:partition)
      partition ||= object.is_a?(Partition) ? object : object.partition

      return {} if partition.blank?

      swift_version = attributes.delete(:swift_version) || partition.current_swift_version
      klass = attributes.delete(:klass) || object.class.to_s
      change_trail = attributes.delete(:change_trail)
      change_trail = Array.wrap(change_trail) if change_trail.present?
      whodunit = attributes.delete(:whodunit) || User.current_user&.name || "unknown"

      {change_trail:, klass:, partition:, swift_version:, whodunit:}
    end
  end

  def activate(whodunit: nil, change_trail: nil)
    self.class.activate(self, whodunit:, change_trail:)
  end
end
