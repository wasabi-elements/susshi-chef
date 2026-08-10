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

class SourceIpGroup < SourceIp

  #-- Datatypes

  #-- Associations
  has_many :source_ip_memberships, dependent: :destroy
  has_many :source_ip_nets, -> { distinct }, through: :source_ip_memberships,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  #-- Scopes

  scope :has_any_members, -> {
    joins("JOIN source_ip_memberships ON source_ips.id = source_ip_memberships.source_ip_group_id")
        .where("source_ip_memberships.source_ip_group_id IS NOT NULL").distinct
  }

  scope :has_not_any_members, -> {
    joins("LEFT JOIN source_ip_memberships ON source_ips.id = source_ip_memberships.source_ip_group_id")
        .where("source_ip_memberships.source_ip_group_id IS NULL").distinct
  }

  #-- Validations

  #-- Class Methods

  class << self
    def api_query_base
      self.includes([:source_ip_nets]).order('source_ips.name ASC')
    end
  end

  #-- Instance Methods

  def icon
    'fa-globe'
  end

  def title
    'Source Ip Group'
  end

  #-- Methods used by config API
  def members
    self.source_ip_nets.pluck(:name)
  end

  def members=(values)
    self.source_ip_nets = SourceIpNet.query_by_ids_or_names('members', self.partition_id, values)
  end

  def members_add(values)
    self.source_ip_nets << SourceIpNet.query_by_ids_or_names('members', self.partition_id, values, self.source_ip_nets)
  end

  def members_remove(values)
    self.source_ip_nets.delete SourceIpNet.query_by_ids_or_names('members', self.partition_id, values)
  end

end