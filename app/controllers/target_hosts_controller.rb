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

class TargetHostsController < ApplicationController

  require 'resolv'

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def show
    @title = "Details of '#{@target_host.hostname}'"
  end

  def new
    authorize :target_host, :new?
    @partition = Partition.find(current_user.partition.id)
    @target_host = TargetHost.new(partition: @partition)
    prepare_form(@target_host)
    @title = 'New Static Target'
  end

  def edit
    @title = "Edit '#{@target_host.hostname}'"
    prepare_form(@target_host)
  end

  def create
    authorize :target_host, :create?

    remove_empty_params(:target_sockets_attributes, :ip_address)
    remove_empty_params(:target_host_keys_attributes, :public_blob)
    @target_host = TargetHost.new(target_params)

    if @target_host.save
      redirect_to targets_path, flash: { success: 'Target Host was successfully created.' }
    else
      prepare_form(@target_host)
      @title = 'New Static Target'
      render :new
    end
  end

  def update
    remove_empty_params(:target_sockets_attributes, :ip_address)
    remove_empty_params(:target_host_keys_attributes, :public_blob)
    if @target_host.update(target_params)
      respond_to do |format|
        format.html { redirect_to targets_path, flash: { success: 'Target Host was successfully updated.' } }
        format.js   { render js: 'location.reload();' }
      end
    else
      prepare_form(@target_host)
      @title = "Edit '#{@target_host.hostname}'"
      render :edit
    end
  end

  def destroy
    @target_host.destroy
    redirect_to targets_url, flash: { destroy: 'Target Host was successfully destroyed.' }
  end

  def scan
    @title = "Scan Network"
    authorize :target_host, :scan?
    @partition = Partition.find(current_user.partition.id)
    gateways!
  end

  def scan_execute
    authorize :target_host, :scan?

    @ip_input = params[:scan][:network]
    @proxy_input = params[:scan][:proxy_id]
    @ip = IPAddress(params[:scan][:network]) rescue nil

    if @ip and @ip.size <= 256*16
      if @ip.ipv6?
        ips = (1..@ip.size).collect do |i|
          (IPAddress::IPv6::parse_u128 (@ip.to_i + i - 1)).to_s
        end
      else
        ips = if @ip.hosts.count > 1
                if @ip.network?
                  @ip.hosts.collect { |ip| ip.to_s }
                end
              else
                [@ip.to_s]
              end
      end
    end

    @results = []

    unless ips.blank?
      scans = Susshid::RemoteControl.scan_hostkeys(params[:scan][:gateway_id], ips, params[:scan][:proxy_id])
      if scans.blank?
        @error_message = 'suSSHi-Chef is suffering from an internal error. Please try with another gateway or come back later.'
        gateways!
        render :scan
      else if scans['return'] == 'failed'
             @error_message = 'The scan has returned with no result. It appears that the target host(s) are down or the gateway cannot reach the target(s).'
             gateways!
             render :scan
           else
             hosts_with_keys = scans['hostkeys'].reject{|ip, keys| keys.blank?}
             if hosts_with_keys.any?
               unless params[:scan][:proxy_id].blank? or params[:scan][:proxy_id].to_i < 1
                 @proxy = Proxy.find(params[:scan][:proxy_id].to_i)
               end
               @results = ips.collect { |host_ip| lookup_host(host_ip, scans, @proxy, params[:scan][:use_shortnames].to_i) }.compact
               if params[:scan][:include_known].to_i == 0
                 # Remove unchanged hosts from list if requested by user
                 @results.reject!{|r| r[:changed] == false}
                 if @results.size < 1
                   @error_message = 'The scan returned without any changed targets found. Please specify another network range or gateway and try again.'
                   gateways!
                   render :scan
                 end
               end
             else
               @error_message = 'The scan returned without any targets found. Please specify another network range or gateway and try again.'
               gateways!
               render :scan
             end
           end
      end
    else
      @error_message = 'Please specify a valid network address (CIDR form) with a maximum size of 4094 hosts.'
      gateways!
      render :scan
    end
  end

  def scan_process
    authorize :target_host, :scan?
    count = 0

    # Create or update a group?
    group_ids = params['target_hosts']['group']['ids'] rescue []
    new_group = params['target_hosts']['group']['name'] rescue nil
    unless new_group.blank?
      target_group = TargetGroup.find_or_create_by(partition: current_user.partition, name: new_group)
      target_group.save
      group_ids << target_group.id
    end

    groups = TargetGroup.where(id: group_ids)

    params['target_hosts'].select { |id, p| p['create'] == '1' }.each do |id, p|
      unless p['host_id'].blank?
        # Update existing host
        host = TargetHost.find(p['host_id'].to_i)
        host.update(name: p['hostname'])
        host.target_host_keys.destroy_all
      else
        # New host
        socket = TargetSocket.create(ip_address: p['ip'])
        host   = TargetHost.create(partition: current_user.partition, name: p['hostname'], active: true, target_sockets: [socket],
                                   proxy_id: p['proxy_id'])
        next unless host.save
      end

      # Add hosts to group(s)
      if groups.any?
        groups.each do |group|
          group.target_hosts << host unless group.target_hosts.include?(host)
        end
      end

      p['keys'].each do |key, value|
        TargetHostKey.create(target_host: host, public_blob: "#{key} #{value}", source: 'Chef Scanner')
      end
      count+=1
    end

    redirect_to targets_path, flash: { success: "#{count} Target Hosts were created / updated successfully." }
  end

  def scan_host
    gateway = SwiftGateway.where(partition_id: current_user.partition.id).first

    @result = {}

    unless gateway.blank?
      unless params[:id].blank?
        find_and_authorize
      else
        @partition   = Partition.find(current_user.partition.id)
        @target_host = TargetHost.new(partition: @partition)
      end
      prepare_form(@target_host)

      unless params[:ip_address].blank?
        ip = IPAddress(params[:ip_address]) rescue nil
        unless ip.blank? or ( ip.prefix != 32 and ip.prefix != 128)
          @result = Susshid::RemoteControl.scan_hostkeys(gateway.id, [ip])
          if @result['return'] == 'failed'
            @result = { 'return' => "Failed to gather hostkey for #{ip}." }
          else
            @result['hostname'] = params[:hostname]
          end
        else
          @result = { 'return' => "'#{params[:ip_address]}' is not a valid host IP address." }
        end
      else
        @result = { 'return' => "IP address is empty. Please provide an IP address in the first 'IP Address' field." }
      end
    else
      @result = { 'return' => "Could not find any configured gateway. Please add a gateway to this partition." }
    end

    render json: @result
  end

  private

  def find_and_authorize(id = params[:id])
    @target_host = TargetHost.readonly(false).find(id)
    authorize @target_host
  end

  def target_params
    params.require(:target_host).permit(:partition_id, :proxy_id, :hostname, :description, :active, { target_group_ids: [],
                                         target_sockets_attributes: [:id, :ip_address, :port_range, :_destroy],
                                         target_host_keys_attributes: [:id, :public_blob, :_destroy] })
  end

  def remove_empty_params(relation, field)
    params[:target_host][relation.to_s].each do |key, data|
      if data[field.to_s].blank? then
        params[:target_host][relation.to_s][key]['_destroy'] = true
      end
    end unless params[:target_host][relation.to_s].nil?
  end

  def prepare_form(object = nil)
    if object
      object.target_sockets.build({}) unless object.target_sockets.any?
      object.target_host_keys.build({}) unless object.target_host_keys.any?
    end
  end

  def lookup_host(ip, keyscan, proxy, shortname = 0)
    host = TargetHost.joins(:target_sockets).where(proxy_id: proxy.try(:id), partition_id: current_user.partition.id, target_sockets: { ip_address: IPAddress.parse(ip).to_string }).first
    keys = keyscan['hostkeys'][ip]
    return nil unless keys
    changed = if host
                new_fps = keys.collect { |key, values| values['fingerprint'] }
                old_fps = host.target_host_keys.collect { |k| k.fingerprint } rescue []
                new_fps.sort != old_fps.sort
              else
                true
              end
    hostname = if shortname == 1
                 (Resolv.getname(ip).split('.').first rescue "Host-#{ip}")
               else
                 (Resolv.getname(ip) rescue "Host-#{ip}")
               end
    changed = true if host and host.name != hostname

    { ip: ip,
      hostname: hostname,
      keys: keys,
      host_id: host.try(:id),
      changed: changed,
      proxy: proxy
    }
  end

  def gateways!
    @gateways = SwiftGateway.where(partition_id: current_user.partition.id).order(:name).pluck(:name, :id)
    @proxies = Proxy.where(partition_id: current_user.partition.id, id: SwiftProxy.where(partition_id: current_user.partition.id).pluck(:id)).collect {|proxy| [proxy.human_name, proxy.id]}.sort {|x,y| x.first <=> y.first }
  end

end


