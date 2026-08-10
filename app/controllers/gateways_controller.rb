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

class GatewaysController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy, :renew, :restart, :shutdown, :shutdown, :suspend, :unsuspend, :show_config]

  def index
    authorize :gateway, :index?

    @q = Gateway.where(partition_id: current_user.partition.id).ransack(params_query)
    ransack_default_sort(@q, :name, :asc)

    @gateways = @q.result.page(params_page).per(params_per_page)
    @status = {}

    if params.delete :status
      @status = Susshid::RemoteControl.status_all(@gateways.pluck(:id))
    end
  end

  def show
    @title = "Details of '#{@gateway.name}'"
    @status = Susshid::RemoteControl.status(@gateway.id) rescue {'status'=>'failed'}
    respond_to do |format|
      format.html # show.html.erb
    end
  end

  def new
    authorize :gateway, :new?
    @partition = Partition.find(current_user.partition.id)
    @gateway = Gateway.new(partition: @partition, sic_port: current_user.partition.partition_setting.ListenPorts.first)

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  def edit
    @title = "Edit '#{@gateway.name}'"
  end

  def create
    authorize :gateway, :create?
    @gateway = Gateway.new(gateway_params)

    Chef::SwiftTracker.with_skip { @gateway.save }

    respond_to do |format|
      if @gateway.persisted?
        Swift::Updater::Gateway.swift_update(@gateway.partition_id)
        Rsyslog::Daemon.restart

        format.html { redirect_to gateway_path(id: @gateway.id), flash: { :success => 'Gateway was successfully created.' }}
      else
        format.html { render action: :new }
      end
    end
  end

  def update
   respond_to do |format|
      if @gateway.update(gateway_params)
        format.html { redirect_to gateways_path, flash: { :success => 'Gateway was successfully updated.' }}
      else
        format.html { render action: :edit }
      end
    end
  end

  def destroy
    Chef::SwiftTracker.with_skip { @gateway.destroy }

    respond_to do |format|
      if @gateway.destroyed?
        Swift::Updater::Gateway.swift_update(@gateway.partition_id)
        Rsyslog::Daemon.restart

        format.html { redirect_to gateways_path, :flash => { :destroy => 'Gateway was successfully deleted.' }}
      else
        format.html { redirect_to gateways_path, :flash => { :error => 'Failed to delete gateway.' }}
      end
    end
  end

  def restart
    result = Susshid::RemoteControl.restart(@gateway.id)['return'] rescue 'failed'

    if result == 'success'
      sleep 5
      redirect_to gateways_path, :flash => { :success => 'Gateway was successfully restarted.' }
    else
      redirect_to gateways_path, :flash => { :destroy => 'Failed to restart gateway.' }
    end
  end

  def renew
    @gateway.transaction do
      @gateway.create_sic_certificate
      @gateway.create_syslog_certificate
      Swift::Updater::Gateway.swift_update(@gateway.partition_id)
    end

    result = Susshid::RemoteControl.restart(@gateway.id)['return'] rescue 'failed'

    if result == 'success'
      10.times do
        @gateway.reload
        break if @gateway.ssl_client_fingerprint == @gateway.sic_certificate_fingerprint
        sleep 1
      end

      redirect_to gateways_path, :flash => { :success => "SIC certificate was successfully renewed. Gateway was successfully restarted." }
    else
      redirect_to gateway_path(@gateway), :flash => { :destroy => "SIC certificate was successfully renewed. Failed to restart the gateway. Please restart manually." }
    end

  rescue StandardError
    redirect_to gateways_path, :flash => { :destroy => 'Failed to renew SIC certificate.' }
  end

  def shutdown
    result = Susshid::RemoteControl.shutdown(@gateway.id)['return'] rescue 'failed'

    if result == 'success'
      sleep 2
      redirect_to gateways_path, :flash => { :success => 'Gateway was successfully shut down.' }
    else
      redirect_to gateways_path, :flash => { :destroy => 'Failed to shutdown gateway.' }
    end
  end

  def suspend
    result = Susshid::RemoteControl.suspend(@gateway.id)['return'] rescue 'failed'

    if result == 'success'
      sleep 2
      redirect_to gateways_path, :flash => { :success => 'Gateway was successfully suspended.' }
    else
      redirect_to gateways_path, :flash => { :destroy => 'Failed to suspend gateway.' }
    end
  end

  def unsuspend
    result = Susshid::RemoteControl.unsuspend(@gateway.id)['return'] rescue 'failed'

    if result == 'success'
      sleep 2
      redirect_to gateways_path, :flash => { :success => 'Gateway was successfully unsuspended.' }
    else
      redirect_to gateways_path, :flash => { :destroy => 'Failed to suspend gateway.' }
    end
  end

  def show_config
    respond_to do |format|
      format.json do
        url = "#{request.protocol}#{request.get_header('SERVER_NAME') || request.get_header('SERVER_ADDR')}:8443"
        send_data JSON.pretty_generate(ControllersSerializers::Gateways::Config.new(@gateway, { url: url }).to_h), filename: "susshid.json"
      end
    end
  end

  private

  def find_and_authorize(id = params[:id])
    @gateway = Gateway.readonly(false).find(id)
    authorize @gateway
  end

  def gateway_params
    params.require(:gateway).permit(:name, :susshid_identifier, :partition_id, :sic_host, :sic_port, listen_addresses: [])
  end

end
