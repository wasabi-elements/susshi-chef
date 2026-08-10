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

class TargetHostKeysController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :target_host_key, :index?
    _params_query = params_query
    if %w([system-wide] system-wide system).include?((_params_query['susshi_user_login_name_cont'] rescue nil))
      _params_query.delete('susshi_user_login_name_cont')
      global_keys = true
    end
    @q = TargetHostKey.joins(:target).where(targets: { partition_id: current_user.partition.id}).ransack(_params_query)
    ransack_default_sort(@q, :key_type, :asc)
    if global_keys
      @target_host_keys = @q.result.where(susshi_user_login_id: nil).page(params_page).per(params_per_page)
    else
      @target_host_keys = @q.result.page(params_page).per(params_per_page)
    end
  end

  def show
    @title = "Details of #{@target_host_key.target.name}'s #{@target_host_key.key_type} key"
  end

  def new
    authorize :target_host_key, :new?
    @target_host_key = TargetHostKey.new
  end

  def edit
    @title = "Edit #{@target_host_key.target.name}'s #{@target_host_key.key_type} key"
  end

  def create
    authorize :target_host_key, :create?
    @target_host_key = TargetHostKey(target_host_key_params)

    if @target_host_key.save
      redirect_to @target_host_key, flash: { success: 'Target host key was successfully created.' }
    else
      render :new
    end
  end

  def update
    if @target_host_key.update(target_host_key_params)
      redirect_to @target_host_key, flash: { success: 'Target host key was successfully updated.' }
    else
      render :edit
    end
  end

  def destroy
    @target_host_key.destroy
    redirect_to target_host_keys_url, flash: { destroy: 'Target host key was successfully destroyed.' }
  end

  private

    def find_and_authorize(id = params[:id])
      @target_host_key = TargetHostKey.readonly(false).find(id)
      authorize @target_host_key
    end

    def target_host_key_params
      params.require(:target_host_key).permit(:public_blob, :source)
    end

end
