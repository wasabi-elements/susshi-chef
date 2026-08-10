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

class TargetNetworksController < ApplicationController

  require 'resolv'

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@target_network.network}'"
  end

  def show_host
    authorize :target_network, :show?
    @target_host = Target.find(params[:id])
  end

  def new
    authorize :target_network, :new?
    @partition = Partition.find(current_user.partition.id)
    @target_network = TargetNetwork.new(partition: @partition)
    prepare_form(@target_network)
  end

  def edit
    @title = "Edit '#{@target_network.network}'"
    prepare_form(@target_network)
  end

  def create
    authorize :target_network, :create?

    @target_network = TargetNetwork.new(target_params)

    if @target_network.save
      redirect_to targets_path, flash: { success: 'Network Target was successfully created.' }
    else
      prepare_form(@target_network)
      render :new
    end
  end

  def update
    if @target_network.update(target_params)
      respond_to do |format|
        format.html { redirect_to targets_path, flash: { success: 'Network Target was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@target_network)
      render :edit
    end
  end

  def destroy
    @target_network.destroy
    redirect_to targets_url, flash: { destroy: 'Network Target was successfully destroyed.' }
  end

  private

  def find_and_authorize(id = params[:id])
    @target_network = TargetNetwork.readonly(false).find(id)
    authorize @target_network
  end

  def target_params
    params.require(:target_network).permit(:partition_id, :proxy_id, :network, :description, :active, { target_group_ids: [] })
  end

  def remove_empty_params(relation, field)
    params[:target_network][relation.to_s].each do |key, data|
      if data[field.to_s].blank? then
        params[:target_network][relation.to_s][key]['_destroy'] = true
      end
    end unless params[:target_network][relation.to_s].nil?
  end

  def prepare_form(object = nil)
  end


end


