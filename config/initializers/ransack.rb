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

Ransack.configure do |config|
  config.custom_arrows = {
      up_arrow: '<i class="fa fa-sort-desc"></i>',
      down_arrow: '<i class="fa fa-sort-asc"></i>'
  }

  config.add_predicate 'in_list',
                       arel_predicate: 'in',
                       formatter: proc { |v| v.split(",") },
                       type: :string
  config.add_predicate 'wildcard',
                       arel_predicate: 'matches'.freeze,
                       formatter: proc { |v| "%#{Ransack::Constants::escape_wildcards(v).gsub(/(\\%|\*)/,'%')}%" },
                       compount: false
  config.add_predicate 'wildcard_any',
                       arel_predicate: 'matches_any'.freeze,
                       formatter: proc { |v_or| v_or.split('|').collect{|v| "%#{Ransack::Constants::escape_wildcards(v).gsub(/(\\%|\*)/,'%').strip}%" } },
                       compount: false
  config.add_predicate 'wildcard_all',
                       arel_predicate: 'matches_all'.freeze,
                       formatter: proc { |v_or| v_or.split('&').collect{|v| "%#{Ransack::Constants::escape_wildcards(v).gsub(/(\\%|\*)/,'%').strip}%" } },
                       compount: false
end