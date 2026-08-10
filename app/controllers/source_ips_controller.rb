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

class SourceIpsController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :source_ip, :index?

    @q = SourceIp.includes(:accesses).where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @source_ips = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@source_ip.name}'"
  end

  def prepare_new
    authorize :source_ip, :new?
    @partition = Partition.find(current_user.partition.id)
  end

  def new_group
    prepare_new
    @source_ip = SourceIpGroup.new(partition: @partition)
    @title = 'New Source IP Group'
    render :new
  end

  def new_net
    prepare_new
    @source_ip = SourceIpNet.new(partition: @partition)
    @title = 'New Source IP Network'
    render :new
  end

  def edit
    @title = "Edit '#{@source_ip.name}'"
  end

  def create
    authorize :source_ip, :create?
    @source_ip = SourceIp.new(source_ip_params)
    if @source_ip.save
      redirect_to source_ips_path, flash: { success: 'Source ip was successfully created.' }
    else
      render :new
    end
  rescue ActionController::BadRequest
    head :bad_request
  end

  def update
    if @source_ip.update(source_ip_params)
      respond_to do |format|
        format.html { redirect_to source_ips_path, flash: { success: 'Source ip was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      render :edit
    end
  end

  def destroy
    @source_ip.destroy
    redirect_to source_ips_url, flash: { destroy: 'Source ip was successfully destroyed.' }
  end

  private

    def find_and_authorize(id = params[:id])
      @source_ip = SourceIp.readonly(false).find(id)
      authorize @source_ip
    end

    def source_ip_params
      type = params.require(:type)
      raise ActionController::BadRequest unless %w[SourceIpGroup SourceIpNet].include?(type)
      params.require(type.underscore.to_sym)
            .permit(:partition_id, :type, :name, :description, :ip_address, source_ip_group_ids: [], source_ip_net_ids: [])
            .merge(type: type)
    end

end


