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

module UsersHelper

  def ransack_users_selection
    User.select([:fullname, :id]).sort{|x,y| x.fullname <=> y.fullname}.map{|u| [u.fullname, u.id]}
  end

  def ransack_user_roles_selection
    User.roles.collect{|key, value| [ value[:title], key]}
  end

  private

  def unindent(text)
    text.gsub(/^#{text.scan(/^[ \t]+(?=\S)/).min}/, '')
  end

end