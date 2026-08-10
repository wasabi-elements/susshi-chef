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

class SusshiUserGroupsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@susshi_user_group.groupname}'"
  end

  def new
    @title = 'New Gateway User Group'
    authorize :susshi_user, :new?
    @partition = Partition.find(current_user.partition.id)
    @susshi_user_group = SusshiUserGroup.new(partition: @partition)
  end

  def edit
    @title = "Edit '#{@susshi_user_group.name}'"
  end

  def create
    authorize :susshi_user, :create?
    @susshi_user_group = SusshiUserGroup.new(susshi_user_group_params)
    if @susshi_user_group.save
      redirect_to susshi_users_path, flash: { :success => 'Gateway Group was successfully created.' }
    else
      render :new
    end
  end

  def update
    if @susshi_user_group.update(susshi_user_group_params)
      respond_to do |format|
        format.html { redirect_to susshi_users_path, flash: { :success => 'Gateway Group was successfully updated.' }}
        format.js   { render js: 'location.reload();' }
      end
    else
      render :edit
    end
  end

  def destroy
    @susshi_user_group.destroy
    redirect_to susshi_users_path, :flash => { :destroy => 'Gateway Group was successfully deleted.' }
  end


  private

  def find_and_authorize(id = params[:id])
    @susshi_user_group = SusshiUserGroup.readonly(false).where(partition_id: current_user.partition.id).find(id)
    authorize @susshi_user_group
  end

  def susshi_user_group_params
    params.require(:susshi_user_group).permit(:partition_id, :groupname, :description, :active, susshi_user_login_ids: [])
  end

end
