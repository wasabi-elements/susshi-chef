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

class PartitionsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]
  around_action :swift_change_handler, only: [:update]

  def index
    authorize :partition, :index?

    @q = Partition.ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @partitions = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@partition.name}'"
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @partition }
    end
  end

  def new
    authorize :partition, :new?

    if Preference.first.installation_identifier != '-'
      @partition = Partition.new

      respond_to do |format|
        format.html # new.html.erb
        format.json { render :json => @partition }
      end
    else
      redirect_to edit_preferences_path, flash: { :error => 'Before creating any Partition, you first have to set the Installation ID correctly.' }
    end
  end

  def edit
  end

  def create
    authorize :partition, :create?
    @partition = Partition.new(partition_params)

    respond_to do |format|
      if @partition.save
        format.html { redirect_to partitions_path, flash: { :success => 'Partition was successfully created.' }}
      else
        format.html { render action: :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @partition.update(partition_params)
        format.html { redirect_to partitions_path, flash: { :success => 'Partition was successfully updated.' }}
      else
        format.html { render action: :edit }
      end
    end
  end

  def destroy
    Chef::SwiftTracker.skip = true
    @partition.destroy
    Chef::SwiftTracker.skip = false

    respond_to do |format|
      format.html { redirect_to partitions_url, :flash => { :destroy => 'Partition was successfully deleted.' }}
      format.json { head :no_content }
    end
  end


  private

  def find_and_authorize(id = params[:id])
    @partition = Partition.readonly(false).find(id)
    authorize @partition
  end

  def partition_params
    params.require(:partition).permit(:comment, :description, :name, user_ids: [], settings: Chef::SusshidSettings.params_permit )
  end

  def swift_change_handler
    users_before = @partition.users_with_log_encryption_key.to_a

    yield

    if @partition.errors.none?
      users_after = @partition.users_with_log_encryption_key.to_a

      actions = {
        added: users_after - users_before,
        removed: users_before - users_after
      }

      change_trail = actions.flat_map do |action, users|
        users.map { |user| "#{action.to_s.titleize} Encryption Key for User '#{user.name}'" }
      end

      if change_trail.present?
        SwiftChange.create_for(@partition, change_trail:)
      end
    end
  end
end
