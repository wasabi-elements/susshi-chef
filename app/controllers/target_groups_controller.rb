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

class TargetGroupsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@target_group.groupname}'"
  end

  def new
    authorize :target, :new?
    @partition = Partition.find(current_user.partition.id)
    @target_group = TargetGroup.new(partition: @partition)
  end

  def edit
    @title = "Edit '#{@target_group.groupname}'"
  end

  def create
    authorize :target, :create?
    @target_group = TargetGroup.new(target_params)

    if @target_group.save
      redirect_to targets_path, flash: { success: 'TargetGroup was successfully created.' }
    else
      render :new
    end
  end

  def update
    if @target_group.update(target_params)
      respond_to do |format|
        format.html { redirect_to targets_path, flash: { success: 'TargetGroup was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      render :edit
    end
  end

  def destroy
    @target_group.destroy
    redirect_to targets_url, flash: { destroy: 'TargetGroup was successfully destroyed.' }
  end

  private

  def find_and_authorize(id = params[:id])
    @target_group = TargetGroup.readonly(false).find(id)
    authorize @target_group
  end

  def target_params
    params.require(:target_group).permit(:partition_id, :groupname, :description, :active, target_ids: [])
  end

end


