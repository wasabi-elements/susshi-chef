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

class TargetsController < ApplicationController

  def index
    authorize :target, :index?

    @q = Target.includes(:accesses, :proxy, :target_fusions).where(partition_id: current_user.partition.id).where.not(type: %w(TargetDomainHost TargetNetworkHost)).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @targets = @q.result.page(params_page).per(params_per_page)
    @any_proxy = Proxy.any?
  end

end
