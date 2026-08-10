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

class TargetDynamicsController < ApplicationController

  require 'resolv'

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@target_dynamic.hostname}'"
  end

  def new
    authorize :target_dynamic, :new?
    @partition = Partition.find(current_user.partition.id)
    @target_dynamic = TargetDynamic.new(partition: @partition)
    prepare_form(@target_dynamic)
    @title = 'New Dynamic Target'
  end

  def edit
    @title = "Edit '#{@target_dynamic.hostname}'"
    prepare_form(@target_dynamic)
  end

  def create
    authorize :target_dynamic, :create?

    remove_empty_params(:target_host_keys_attributes, :public_blob)
    @target_dynamic = TargetDynamic.new(target_params)

    if @target_dynamic.save
      redirect_to targets_path, flash: { success: 'Dynamic Target was successfully created.' }
    else
      prepare_form(@target_dynamic)
      @title = 'New Dynamic Target'
      render :new
    end
  end

  def update
    remove_empty_params(:target_host_keys_attributes, :public_blob)
    if @target_dynamic.update(target_params)
      respond_to do |format|
        format.html { redirect_to targets_path, flash: { success: 'Dynamic Target was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@target_dynamic)
      @title = "Edit '#{@target_dynamic.hostname}'"
      render :edit
    end
  end

  def destroy
    @target_dynamic.destroy
    redirect_to targets_url, flash: { destroy: 'Dynamic Target was successfully destroyed.' }
  end

  def scan_host
    gateway = SwiftGateway.where(partition_id: current_user.partition.id).first

    @result = {}

    unless gateway.blank?
      unless params[:id].blank?
        find_and_authorize
      else
        @partition      = Partition.find(current_user.partition.id)
        @target_dynamic = TargetDynamic.new(partition: @partition)
      end
      prepare_form(@target_dynamic)

      unless params[:hostname].blank?
        ip = resolv_hostname(params[:hostname])
        unless ip.blank?
          @result = Susshid::RemoteControl.scan_hostkeys(gateway.id, [ip])
          if @result['return'] == 'failed'
            @result = { 'return' => "Failed to gather hostkey for '#{params[:hostname]}' (#{ip})." }
          else
            @result['hostname'] = params[:hostname]
          end
        else
          @result = { 'return' => "Could not resolve '#{params[:hostname]}' into an IP address." }
        end
      else
        @result = { 'return' => "Hostname is empty. Please provide a hostname on first tab." }
      end
    else
      @result = { 'return' => "Could not find any configured gateway. Please add a gateway to this partition." }
    end

    render json: @result
  end



  private

  def find_and_authorize(id = params[:id])
    @target_dynamic = TargetDynamic.readonly(false).find(id)
    authorize @target_dynamic
  end

  def target_params
    params.require(:target_dynamic).permit(:id, :partition_id, :proxy_id, :hostname, :description, :active, { target_group_ids: [],
                                            target_host_keys_attributes: [:id, :public_blob, :_destroy] })
  end

  def resolv_hostname(fqdn)
    Resolv.getaddress fqdn rescue nil
  end

  def remove_empty_params(relation, field)
    params[:target_dynamic][relation.to_s].each do |key, data|
      if data[field.to_s].blank? then
        params[:target_dynamic][relation.to_s][key]['_destroy'] = true
      end
    end unless params[:target_dynamic][relation.to_s].nil?
  end

  def prepare_form(object = nil)
    if object
      object.target_host_keys.build({}) unless object.target_host_keys.any?
    end
  end


end


