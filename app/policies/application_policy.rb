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

class ApplicationPolicy
  attr_reader :controller, :user, :record

  def initialize(context, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless context.user
    @user = context.user
    @controller = context.controller.singularize.capitalize
    @record = record
  end

  def index?
    user.has_role_readonly?
  end

  def show?
    user.has_role_readonly?
  end

  def create?
    user.has_role_admin?
  end

  def new?
    user.has_role_admin?
  end

  def update?
    user.has_role_admin?
  end

  def edit?
    user.has_role_admin?
  end

  def destroy?
    user.has_role_admin?
  end

  private
end

