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

module Api::V1::Config
  class TargetsController < ApiController

    wrap_parameters :target, include: [:hostname, :domainname, :groupname, :network, :proxy_realm, :description, :active, :sockets, :members, :memberships, :target_host_keys, :scan_target_host_keys]

    def create
      unless (scan_option = params['target'].delete('scan_target_host_keys')).blank?
        respond_to_post do

          if @sub_class != 'hosts'
            raise Errors::Api::HostKeyScanParameter
          end

          unless %w(intended mandatory).include?(scan_option)
            raise Errors::Api::HostKeyScanParameter
          end

          Target.transaction do
            object = new_object
            if object.save
              if (scan_and_add_host_keys(object) == false) and (scan_option == 'mandatory')
                raise Errors::Api::HostKeyScanFailed
              end
            else
              raise ActiveRecord::RecordInvalid, object
            end
            object
          end
        end
      else
        super
      end
    end

    def update
      Target.transaction do
        unless (scan_option = params['target'].delete('scan_target_host_keys')).blank?
          respond_to_put do

            if @sub_class != 'hosts'
              raise Errors::Api::HostKeyScanParameter
            end

            unless %w(intended mandatory).include?(scan_option)
              raise Errors::Api::HostKeyScanParameter
            end

            Target.transaction do
              unless params['target'].blank?
                @object.assign_attributes(strong_params)
              end

              if @object.save
                if (scan_and_add_host_keys(object) == false) and (scan_option == 'mandatory')
                  raise Errors::Api::HostKeyScanFailed
                end
              else
                raise ActiveRecord::RecordInvalid, @object
              end
              @object.reload
              @object
            end
          end
        else
          super
        end
      end
    end

    private

    def sub_classes
      %w(domains dynamics hosts networks groups)
    end

    def strong_params
      case @sub_class
        when 'groups'
          params.require(:target).permit(:groupname, :active, :description, members: [])
        when 'domains'
          params.require(:target).permit(:domainname, :active, :description, :proxy_realm, memberships: [])
        when 'dynamics'
          params.require(:target).permit(:hostname, :active, :description, :proxy_realm, memberships: [], target_host_keys: [:public_blob])
        when 'hosts'
          params.require(:target).permit(:hostname, :active, :description, :proxy_realm, :scan_target_host_keys, sockets: [:ip_address], memberships: [], target_host_keys: [:public_blob])
        when 'networks'
          params.require(:target).permit(:network, :active, :description, :proxy_realm, memberships: [])
      end
    end

    def strong_params_patch
      case @sub_class
        when 'groups'
          params.require(:target).permit(members: [])
        when 'hosts'
          params.require(:target).permit(memberships: [], target_host_keys: [:public_blob], sockets: [:ip_address])
        when 'dynamics'
          params.require(:target).permit(memberships: [], target_host_keys: [:public_blob])
        when 'domains', 'networks'
          params.require(:target).permit(memberships: [])
      end
    end

    def scan_and_add_host_keys(target)
      gateway = SwiftGateway.find_by_partition_id(target.partition_id)

      unless gateway.blank?
        ip = target.target_sockets.first.host_ip_address rescue nil
        unless ip.blank?
          begin
            keys = Susshid::RemoteControl.scan_hostkeys(gateway.id, [ip], target.proxy.try(:id))
            unless (keys['hostkeys'][ip]).blank?
              target.target_host_keys.delete_all
              keys['hostkeys'][ip].each do |key, value|
                TargetHostKey.create(target: target, public_blob: "#{key} #{value['base64']}")
              end
              target.reload
              return true
            end
          rescue
            false
          end
        end
      else
        raise Errors::Api::NoGatewayFound
      end
      false
    end

    def find_single_object
      begin
        @object = Target.query_target_by_ids_or_names('members', @partition.id, [@id.try(:to_i), @identity]).first
        respond_with_error_text(404) if @object.blank?
      rescue
        respond_with_error_text(404)
      end
    end

    def rack_reducers
      super + [
          ->(active:) { where(active: active) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(domainname:) { where(api_query_search_string(:name, domainname)) },
          ->(groupname:) { where(api_query_search_string(:name, groupname)) },
          ->(hostname:) { where(api_query_search_string(:name, hostname)) },
          ->(network:) { where(api_query_search_string(:name, network)) },
          ->(proxy_realm:) { joins(:proxy).where(api_query_search_string("proxies.realm", proxy_realm)) },
          ->(has_members:) { has_members.to_s == 'true' ? has_any_members : has_not_any_members },
          ->(has_memberships:) { has_memberships.to_s == 'true' ? has_any_memberships : has_not_any_memberships },
          ->(has_target_host_keys:) { has_target_host_keys.to_s == 'true' ? has_any_keys : has_not_any_keys },
          ->(has_target_fusions:) { has_target_fusions.to_s == 'true' ? has_any_fusions : has_not_any_fusions },
          ->(has_sockets:) { has_sockets.to_s == 'true' ? has_any_sockets : has_not_any_sockets }
      ]
    end

  end
end