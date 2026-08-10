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

class TargetUsersController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :target_user, :index?

    @q = TargetUser.includes(:accesses, :target_fusions).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @target_users = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@target_user.name}'"
  end

  def prepare_new
    authorize :target_user, :new?
    @partition = Partition.find(current_user.partition.id)
  end

  def new_group
    prepare_new
    @target_user = TargetUserGroup.new(partition: @partition)
    @title = 'New Target Users Group'
    render :new
  end

  def new_login
    prepare_new
    @target_user = TargetUserLogin.new(partition: @partition)
    @title = 'New Target Login User'
    render :new
  end

  def new_mapping
    prepare_new
    @target_user = TargetUserMapping.new(partition: @partition)
    @title = 'New Target Mapping User'
    @target_user.regex = '(.*)'
    @target_user.translate = '$1'
    @target_user.regex_target_user = '%translated%'
    render :new
  end

  def new_regex
    prepare_new
    @target_user = TargetUserRegex.new(partition: @partition)
    @title = 'New Target Regex User'
    @target_user.regex = '.*'
    render :new
  end


  def edit
    @title = "Edit '#{@target_user.name}'"
  end

  def create
    authorize :target_user, :create?
    @target_user = TargetUser.new(target_user_params)
    if @target_user.save
      redirect_to target_users_path, flash: { success: 'Target user was successfully created.' }
    else
      render :new
    end
  rescue ActionController::BadRequest
    head :bad_request
  end

  def update
    if @target_user.update(target_user_params)
      respond_to do |format|
        format.html { redirect_to target_users_path, flash: { success: 'Target user was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end

    else
      render :edit
    end
  end

  def destroy
    @target_user.destroy
    redirect_to target_users_url, flash: { destroy: 'Target user was successfully destroyed.' }
  end

  private

    def find_and_authorize(id = params[:id])
      @target_user = TargetUser.readonly(false).find(id)
      authorize @target_user
    end

    def target_user_params
      type = params.require(:type)
      raise ActionController::BadRequest unless %w[TargetUserGroup TargetUserLogin TargetUserMapping TargetUserRegex].include?(type)
      params.require(type.underscore.to_sym)
            .permit(:type, :partition_id, :description, :name, :regex, :translate, :regex_target_user,
                    target_user_ids: [], target_user_group_ids: [])
            .merge(type: type)
    end

end
