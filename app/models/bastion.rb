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

class Bastion < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition
  belongs_to :bastion_profile

  has_many :bastions_source_ips, dependent: :destroy
  has_many :source_ips, -> { distinct }, through: :bastions_source_ips,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :bastions_susshi_users, dependent: :destroy
  has_many :susshi_users, -> { distinct }, through: :bastions_susshi_users,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  has_many :bastions_proxies, dependent: :destroy
  has_many :proxies, -> { distinct }, through: :bastions_proxies,
           after_add: :after_add_relation,
           after_remove: :after_remove_relation

  #-- Acts as list
  acts_as_list scope: :partition

  #-- Instance methods

  #-- Methods used by config API
  def source_ip_members
    self.source_ips.pluck(:name)
  end

  def susshi_user_members
    self.susshi_users.pluck(:name)
  end

  def proxy_members
    self.proxies.pluck(:name)
  end

  def profile
    self.bastion_profile.try(:name) || 'DENY'
  end
end
