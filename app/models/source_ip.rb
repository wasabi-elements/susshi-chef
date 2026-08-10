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

class SourceIp < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition

  has_many :accesses_source_ips, dependent: :restrict_with_error
  has_many :accesses, -> { distinct }, through: :accesses_source_ips

  has_many :bastions_source_ips, dependent: :restrict_with_error
  has_many :bastions, -> { distinct }, through: :bastions_source_ips

  #-- Scopes

  #-- Validations

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false, scope: :partition_id, message: 'same name already exists within partition' }

  #-- Class Methods

  class << self

    def icon
      'fa-globe'
    end

    def types_collection
      [ ['Source IP', 'SourceIpNet'], ['Source Group', 'SourceIpGroup'] ]
    end

    def versions_collection
      [ ['IPv4', 4], ['IPv6', 6] ]
    end

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      SourceIp.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      SourceIp.where(partition_id: partition_id).order("type ASC, LOWER(name) ASC").all.pluck(:name, :ip_address, :id)
          .collect{|t| ["#{t.first} (#{t.second.blank? ? 'Group' : t.second})", t.last]}
    end

  end

  #-- Instance Methods

  def icon
    'fa-exclamation'
  end

  def title
    'Base'
  end

  def identifier
    name
  end

  def is_destroyable?
    return {false: 'Is assigned to an Access Rule'}  if accesses.any?
    {true: "Delete Source IP '#{self.name}'"}
  end

  def IPAddress
    nil
  end

end
