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

class PartitionKeysController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :partition_key, :index?
    @partition_auth_keys = PartitionAuthKey.order(:order).where(partition_id: current_user.partition.id)
    @proxy_auth_keys = ProxyAuthKey.includes(:proxy).order("proxies.name").order(:order).where(partition_id: current_user.partition.id)
    @partition_setting = PartitionSetting.where(partition_id: current_user.partition.id).first

    partition_host_keys = PartitionHostKey.order(:key_type, :order).where(partition_id: current_user.partition.id).group_by { |x| x.key_type }
    @hostkey_algorithms = @partition_setting.ClientHostkeyAlgorithms.map {|a| a.gsub(/(rsa-sha2-512|rsa-sha2-256)/,'ssh-rsa')}.uniq
    @partition_host_keys_used = partition_host_keys.select{|k,v| @hostkey_algorithms.include?(k)}
    @partition_host_keys_ignored = partition_host_keys.reject{|k,v| @hostkey_algorithms.include?(k)}
  end

  def show
    @title = "Details of '#{@partition_key.title}'"
    respond_to do |format|
      format.html { render :show }
      format.pub do
        case @partition_key.type
        when 'PartitionHostKey', 'PartitionAuthKey'
          filename = "susshi-#{@partition_key.type.gsub('Partition','Gateway').underscore}-#{@partition_key.key_type}-#{@partition_key.bits}.pub"
        when 'ProxyAuthKey'
          filename = "susshi-#{@partition_key.proxy.name.gsub(" ",'-')}_auth_key-#{@partition_key.key_type}-#{@partition_key.bits}.pub"
        end
        send_data @partition_key.public_blob, filename: filename
      end
    end
  end

  def prepare_new
    authorize :partition_key, :new?
    @partition = Partition.find(current_user.partition.id)
  end

  def new_host_key
    prepare_new
    @partition_key = PartitionHostKey.new(partition: @partition)
    @title = 'New Host Key'
    render :new
  end

  def new_auth_key
    prepare_new
    @partition_key = PartitionAuthKey.new(partition: @partition)
    @title = 'New Authentication Key'
    render :new
  end

  def edit
    @title = "Edit '#{@partition_key.title}'"
  end

  def create
    authorize :partition_key, :create?
    @partition_key = PartitionKey.new(partition_key_params.merge(source: 'UI'))
    if @partition_key.save
      redirect_to partition_keys_path, flash: { success: 'Key was successfully created.' }
    else
      render :new
    end
  rescue ActionController::BadRequest
    head :bad_request
  end

  def update
    if @partition_key.update(partition_key_params)
      redirect_to partition_keys_path, flash: { success: 'Key was successfully updated.' }
    else
      render :edit
    end
  end

  def destroy
    @partition_key.destroy
    redirect_to partition_keys_url, flash: { destroy: 'Key was successfully destroyed.' }
  end

  def move
    authorize :partition_key, :move?
    case params[:klass]
    when 'PartitionAuthKey'
      PartitionAuthKey.reorder(params[:reorder].collect { |p| p.to_i })
    when 'PartitionHostKey'
      PartitionHostKey.reorder(params[:reorder].collect { |p| p.to_i })
    end
    head  :no_content
  end


  private

    def find_and_authorize(id = params[:id])
      @partition_key = PartitionKey.readonly(false).find(id)
      authorize @partition_key
    end

    def partition_key_params
      type = params.require(:type)
      raise ActionController::BadRequest unless %w[PartitionHostKey PartitionAuthKey].include?(type)
      params.require(type.underscore.to_sym)
            .permit(:partition_id, :title, :key_type, :bits, :active)
            .merge(type: type)
    end

end


