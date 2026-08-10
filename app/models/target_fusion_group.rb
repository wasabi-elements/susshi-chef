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

class TargetFusionGroup < TargetFusion

  #-- Datatypes

  alias_attribute :groupname, :name

  #-- Associations

  has_many :target_fusion_memberships, dependent: :destroy

  has_many :target_fusion_links, -> { distinct }, through: :target_fusion_memberships,
           after_add: :after_add_relation, after_remove: :after_remove_relation

  #-- Class Methods

  class << self

    def api_query_base
      self.includes([:target_fusion_links]).order('target_fusions.name ASC')
    end

  end


  #-- Instance Methods

  def display_name
    "#{super} (Group)"
  end

  #-- Methods used by config API
  def members
    self.target_fusion_links.map(&:name)
  end

end
