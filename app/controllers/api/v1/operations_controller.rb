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
  class OperationsController < ApiApplicationController

    respond_to :json
    before_action :initialize_api_controller

    def activate
      swift_changes = @partition.pending_swift_changes.order(created_at: :desc)
      last_activation = @partition.last_swift_changes_activation

      if swift_changes.any?
        changes = swift_changes.collect do |change|
          change.change_trail.collect do |trail|
            {
                class: change.klass,
                date: change.created_at,
                message: trail,
                who: change.whodunit
            }
          end
        end.flatten

        activation = {
          activated_changes: changes.size,
          active_version: swift_changes.first&.swift_version,
          last_activation: last_activation&.created_at || 'never',
          changes: changes
        }

        if Access.activate(@partition, "API token #{@api_app}", ["Activated with API application token '#{@api_app}'"])
          render json: activation
        else
          render json: { error: 'Internal error. Changes were not activated.' }, status: :bad_request
        end
      else
        render json: {
          pending_changes: 0,
          last_activation: last_activation&.created_at || 'never',
          message: 'No pending changes',
          changes: []
        }
      end
    end


    def changes
      swift_changes = @partition.pending_swift_changes.order(created_at: :desc)
      last_activation = @partition.last_swift_changes_activation

      if swift_changes.any?
        changes = swift_changes.flat_map do |change|
          change.change_trail.map do |trail|
            {
              class: change.klass,
              date: change.created_at,
              message: trail,
              who: change.whodunit
            }
          end
        end

        render json: {
          pending_changes: changes.size,
          pending_version: swift_changes.first&.swift_version,
          last_activation: last_activation&.created_at || 'never',
          changes: changes
        }
      else
        render json: {
          pending_changes: 0,
          last_activation: last_activation&.created_at || 'never',
          message: 'No pending changes',
          changes: []
        }
      end
    end


    def subscription
      subscription = Subscription.instance
      if subscription.installed?
        sub_hash = { properties: subscription.claims.to_h, activated_at: subscription.activated_at }
        sub_hash.merge!({
          valid:             subscription.valid?,
          validation_errors: subscription.errors.messages.any? ? subscription.errors.messages : nil,
          expires_soon:      subscription.expires_soon? ? "Expires in about #{subscription.expires_in_days} days" : nil,
        }.compact)

        sub_hash.merge!({
          counters: {
            partitions: subscription.configured_partitions,
            gateways:   subscription.configured_gateways,
            users:      subscription.configured_users,
            targets:    subscription.configured_targets,
            proxies:    subscription.configured_proxies }
        })

        render json: sub_hash
      else
        respond_with_error_text( :not_found, 'No subscription installed.')
      end
    end


    def version
      render json: {
        software: "suSSHi Chef (#{CHEF_CONFIG['version_info']})",
        version: CHEF_CONFIG['version'],
        build: GIT_INFO,
        copyright: "Copyright (c) #{CHEF_CONFIG['copyright']}"
      }
    end


    def gateway_auth_keys
      keys =  PartitionAuthKey.order(:order).where(partition: @partition).map do |key|
        ControllersSerializers::Operations::GatewayAuthKeys.new(key).to_h
      end

      render json: keys
    end


    def gateway_host_keys
      partition_setting        = PartitionSetting.where(partition: @partition).first
      partition_host_keys      = PartitionHostKey.where(partition: @partition)
      hostkey_algorithms       = partition_setting.ClientHostkeyAlgorithms.map { |a| a.gsub(/(rsa-sha2-512|rsa-sha2-256)/, 'ssh-rsa') }.uniq
      partition_host_keys_used = partition_host_keys.select { |key| hostkey_algorithms.include?(key.key_type) }
                                     .sort_by { |key| hostkey_algorithms.index key.key_type }.map do |key|
        ControllersSerializers::Operations::GatewayHostKeys.new(key).to_h
      end
      render json: partition_host_keys_used
    end

    private

    def initialize_api_controller
      if valid_api_token?
        unless api_allowed?
          respond_with_error_text( :unauthorized, 'API token is not authorized to access operations.')
        end
        @id = params.delete(:id)                # Object ID
        @identity = params.delete(:identity)    # Search for name
      else
        response.headers['WWW-Authenticate'] = 'Basic realm="suSSHi Chef Configuration API"'
        respond_with_error_text(:unauthorized, 'Authentication failed.')
      end
    end

    def api_allowed?
      case action_name.to_s
      when 'activate'
        @api_token.has_permission?(controller_name, :update)
      when 'changes', 'subscription', 'version', 'gateway_auth_keys', 'gateway_host_keys'
        @api_token.has_permission?(controller_name, :read)
      else
        false
      end
    end

    #
    # Authentication can be done with
    #   1. Api-Application and Api-Token header
    #   2. Basic-Auth Header
    #
    def valid_api_token?
      api_app = request.headers['Api-Application']
      token_hex = request.headers['Api-Token']

      if api_app.blank? or token_hex.blank?
        # Try Basic Auth
        type, base64 =  request.headers['Authorization'].split(' ') rescue [nil, nil]
        if type == 'Basic'
          api_app, token_hex = Base64.decode64(base64).split(':') rescue [nil, nil]
        end
      end

      if api_app
        RequestStore.store[:swift_track_whodunit] = "API (application '#{api_app}')"
        unless api_app.blank? or token_hex.blank?
          token_digest = Digest::SHA256.hexdigest token_hex
          unless (@api_token = ApiToken.find_by(application: api_app, token_digest: token_digest)).blank?
            # Constant-time compare algorithm
            if Devise.secure_compare(@api_token.token_digest, token_digest)
              @partition = @api_token.partition
              @api_app = @api_token.application
              return true
            end
          end
        end
      end
      false
    end

    # Responders
    def respond_with_error_text(code = 404, text = nil)
      error = { errors: [ { message: text.blank? ? 'Not found' : text } ] }
      respond_to do |format|
        format.json { render json: error, status: code }
      end
    end

  end

end
