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

class UserPolicy < ApplicationPolicy

  def initialize(context, record)
    super(context, record)
    @controller = 'User'
  end

  def index?
    user.has_role_admin?
  end

  def show?
    user.has_role_admin?
  end

  def create?
    user.has_role_super?
  end

  def new?
    user.has_role_super?
  end

  def update?
    user.has_role_super?
  end

  def update_profile?
    user.has_role_readonly?
  end

  def edit_profile?
    user.has_role_readonly?
  end

  def edit?
    user.has_role_super?
  end

  def destroy?
    user.has_role_super?
  end

  def reset_otp?
    user.has_role_super?
  end

  alias_method :send_activation_token?, :edit?
  alias_method :send_qr_code?, :edit?

end
