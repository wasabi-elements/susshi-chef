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

class TargetFusion < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition

  belongs_to :target, optional: true
  belongs_to :target_user, optional: true

  has_many :accesses_target_fusions, dependent: :destroy
  has_many :accesses, -> { distinct }, through: :accesses_target_fusions

  #-- Instance Methods

  def display_name
    name
  end

  def target_name
    self.target.try(:name)
  end

  def target_user_name
    self.target_user.try(:name)
  end

end
