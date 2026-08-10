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

class Proxy < ApplicationRecord

  include SwiftChangeTracker

  #--- Relations

  belongs_to :partition

  has_many :targets, dependent: :destroy

  has_many :proxy_auth_keys, dependent: :destroy,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  has_many :bastions_proxies, dependent: :restrict_with_error
  has_many :bastions, -> { distinct }, through: :bastions_proxies

  #-- Class methods

  class << self

    def all_collection
      Proxy.order("LOWER(name)").where(partition_id: User.current_user.partition.id).collect {|p| [p.human_name, p.id]}.sort {|x,y| x.first <=> y.first }
    end

    def api_query_base
      self.includes(:proxy_auth_keys).order('name ASC')
    end

  end

  #-- Instance methods

  def human_name
    "@#{self.realm} (#{self.name})"
  end

end

