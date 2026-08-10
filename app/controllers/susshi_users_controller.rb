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

class SusshiUsersController < ApplicationController

  def index
    @title = 'Gateway Users'
    authorize :susshi_user, :index?

    @show_last_use = !params.dig(:q, :last_use_at_gteq).blank?
    if params.dig(:q, :last_use_at_gteq) == 'never'
      params[:q].delete(:last_use_at_gteq)
      params[:q][:last_use_at_null] = true
    end

    @show_totp_column = Preference.totp_secret_key_set?

    @q = SusshiUser.includes(:accesses, :bastions).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @susshi_users = @q.result.page(params_page).per(params_per_page)

    @susshi_users_auth_passable = SwiftSusshiUser.where(id: @susshi_users.pluck(:id)).each_with_object({}) { |user, hash| hash[user.id] = user.auth_passable? }
  end

end
