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

class TargetMembership < ApplicationRecord

  #-- Datatypes

  #-- Associations
  belongs_to :target, optional: true
  belongs_to :target_host, foreign_key: 'target_id', class_name: 'TargetHost', optional: true
  belongs_to :target_dynamic, foreign_key: 'target_id', class_name: 'TargetDynamic', optional: true
  belongs_to :target_domain, foreign_key: 'target_id', class_name: 'TargetDomain', optional: true
  belongs_to :target_network, foreign_key: 'target_id', class_name: 'TargetNetwork', optional: true
  belongs_to :target_group

  #-- Scopes

  #-- Validations

  #-- Class Methods

  #-- Instance Methods

end
