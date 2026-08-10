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
  class ConfigController < ApiController

    def api_allowed?
      true
    end

    def index
      respond_to_get do
        hash = {}
        subscription = Subscription.instance

        if @api_token.has_permission?(:accesses)
          hash[:accesses] = ActiveModelSerializers::SerializableResource.new(find_objects(Access))
        end
        if @api_token.has_permission?(:profiles)
          hash[:profiles] = ActiveModelSerializers::SerializableResource.new(find_objects(Profile))
        end
        if @api_token.has_permission?(:source_ips)
          hash[:source_ips_api] = {
              nets:   ActiveModelSerializers::SerializableResource.new(find_objects(SourceIpNet)),
              groups: ActiveModelSerializers::SerializableResource.new(find_objects(SourceIpGroup))
          }
        end
        if @api_token.has_permission?(:susshi_users)
          hash[:susshi_users] = {
              logins: ActiveModelSerializers::SerializableResource.new(find_objects(SusshiUserLogin), api_token: @api_token),
              groups: ActiveModelSerializers::SerializableResource.new(find_objects(SusshiUserGroup))
          }
        end
        if @api_token.has_permission?(:target_users)
          hash[:target_users] = {
              logins:   ActiveModelSerializers::SerializableResource.new(find_objects(TargetUserLogin)),
              mappings: ActiveModelSerializers::SerializableResource.new(find_objects(TargetUserMapping)),
              regexes:  ActiveModelSerializers::SerializableResource.new(find_objects(TargetUserRegex)),
              groups:   ActiveModelSerializers::SerializableResource.new(find_objects(SusshiUserGroup))
          }
        end
        if @api_token.has_permission?(:targets)
          hash[:targets] = {
              hosts:    ActiveModelSerializers::SerializableResource.new(find_objects(TargetHost)),
              domains:  ActiveModelSerializers::SerializableResource.new(find_objects(TargetDomain)),
              dynamics: ActiveModelSerializers::SerializableResource.new(find_objects(TargetDynamic)),
              networks: ActiveModelSerializers::SerializableResource.new(find_objects(TargetNetwork)),
              groups:   ActiveModelSerializers::SerializableResource.new(find_objects(TargetGroup))
          }
          if subscription.feature_target_fusions?
            hash[:target_fusions] = {
                links:    ActiveModelSerializers::SerializableResource.new(find_objects(TargetFusionLink)),
                groups:   ActiveModelSerializers::SerializableResource.new(find_objects(TargetFusionGroup))
            }
          end
        end
        if @api_token.has_permission?(:proxies) and subscription.feature_proxies?
          hash[:proxies] = ActiveModelSerializers::SerializableResource.new(find_objects(Proxy))
          hash[:bastions] = ActiveModelSerializers::SerializableResource.new(find_objects(Bastion))
          hash[:bastion_profiles] = ActiveModelSerializers::SerializableResource.new(find_objects(BastionProfile))
        end
        hash
      end
    end

  end
end