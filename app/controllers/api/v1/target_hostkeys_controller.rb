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

module Api::V1
  class TargetHostkeysController < ApiApplicationController

    respond_to :json

    before_action :validate_target_host_key_params, only: [:create, :update]

    #--- Called on user login

    def create
      store
    end

    def update
      store
    end

    def store

      while true # Just to break out in case of error

        part_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
        break unless part_id

        #-- Susshi Users
        susshi_user = SwiftSusshiUser.where(partition_id: part_id, name: @params.susshi_user).first
        break unless susshi_user

        #-- Target
        swift_target = SwiftTarget.where(partition_id: part_id, target_id: @params.target_id).first
        break unless swift_target

        case swift_target.kind
          when 'Static', 'Dynamic'
            update_persistent_target(swift_target,
                                     susshi_user.name,
                                     @params.target_hostkey_type,
                                     @params.target_hostkey)
          when 'Network'
            create_or_update_target_network_host(part_id, @params.target_ip_address,
                                                 susshi_user.name,
                                                 @params.target_hostkey_type,
                                                 @params.target_hostkey)
          when 'Domain'
            create_or_update_target_domain_host(part_id, @params.target_host_name,
                                                susshi_user.name,
                                                @params.target_hostkey_type,
                                                @params.target_hostkey)
        end

        break # from while true

      end

      head :ok, status: 200
    end



    private

    def validate_target_host_key_params
      @params = Api::V1::Validate::TargetHostkeys.new(params)
      validate_params(@params)
    end

    def create_or_update_target_domain_host(part_id, hostname, username, hostkey_type, hostkey)

      s_user = SwiftSusshiUser.find_by_name(username)
      return if s_user.blank?

      Chef::SwiftTracker.skip = true

      # Target Domain Host
      t_host = TargetDomainHost.find_or_create_by(partition_id: part_id, name: hostname, proxy_id: @params.proxy_id)

      # Referenced Target Hostkey
      t_host_key = TargetHostKey.find_or_initialize_by(target_id: t_host.id, susshi_user_login_id: s_user.id) do |t_key|
        t_key.source = 'Gateway (User accepted)'
      end
      t_host_key.public_blob = "#{hostkey_type} #{hostkey}"
      t_host_key.save

      # Swift Domain Host
      s_host = SwiftDomainHost.find_or_initialize_by(partition_id: part_id,
                                                     name:         hostname,
                                                     target_id:    t_host.id,
                                                     proxy_realm:  @params.target_proxy_realm)

      s_host.user_keys.merge!({ username => { hostkey_type => [ hostkey ] } })
      s_host.save

      Chef::SwiftTracker.skip = false
    end

    def create_or_update_target_network_host(part_id, ip_address, username, hostkey_type, hostkey)

      s_user = SwiftSusshiUser.find_by_name(username)
      return if s_user.blank?

      Chef::SwiftTracker.skip = true

      # Target Network Host
      t_host = TargetNetworkHost.find_or_create_by(partition_id: part_id, address: ip_address, proxy_id: @params.proxy_id)

      # Referenced Target Hostkey
      t_host_key = TargetHostKey.find_or_initialize_by(target_id: t_host.id, susshi_user_login_id: s_user.id) do |t_key|
        t_key.source = 'Gateway (User accepted)'
      end
      t_host_key.public_blob = "#{hostkey_type} #{hostkey}"
      t_host_key.save

      # Swift Network Host incl. Hostkey per User
      s_host = SwiftNetworkHost.find_or_initialize_by(partition_id: t_host.partition_id,
                                                      target_id: t_host.id,
                                                      proxy_realm: @params.target_proxy_realm,
                                                      address: ip_address)

      s_host.user_keys.merge!({ username => { hostkey_type => [ hostkey ] } })
      s_host.save

      Chef::SwiftTracker.skip = false
    end

    def update_persistent_target(swift_target, username, hostkey_type, hostkey)
      keys = merge_user_keys(username, swift_target.user_keys, hostkey_type, hostkey)
      swift_target.update_columns(user_keys: keys)

      user = SusshiUser.find_by_name(username)
      if user && Target.exists?(swift_target.target_id)
        key = TargetHostKey.where(target: swift_target, susshi_user_login: user).first
        if key
          key.update(public_blob: "#{hostkey_type} #{hostkey}")
        else
          Chef::SwiftTracker.skip = true
          thk = TargetHostKey.where(target_id: swift_target.target_id, susshi_user_login: user).first
          if thk
            thk.update(source: 'Gateway (User accepted)',
                                  public_blob: "#{hostkey_type} #{hostkey}")
          else
            TargetHostKey.create(target_id: swift_target.target_id,
                                 susshi_user_login: user,
                                 source: 'Gateway (User accepted)',
                                 public_blob: "#{hostkey_type} #{hostkey}")
          end
          Chef::SwiftTracker.skip = false
        end
      end
    end

    def merge_user_keys(username, user_keys, hostkey_type, hostkey)
      keys = user_keys || {}
      keys[username] ||= {}
      keys[username][hostkey_type] ||= []
      keys[username][hostkey_type] << hostkey
      keys[username][hostkey_type].uniq!
      keys
    end

  end
end
