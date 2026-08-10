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
  class SessionsController < ApiApplicationController

    respond_to :json

    before_action :validate_session_params, only: [:context]

    #--- Called on user login

    rescue_from StandardError do |error|
      render json: { error: error.message },
             status: :internal_server_error
    end

    def context

      @auth_hook = Plugin::AuthHooks::Session::Context.new(@params)

      @auth_hook.gw_version = gateway_version_uint32

      case @auth_hook.operation_mode

      when 'gateway'

        #=== Gateway Mode (Normal operation)

        #
        #  Session Evaluation Strategy
        #  ---------------------------
        #
        #   1. Lookup Gateway and Partition
        #      In this first step, only the existence of the Gateway ID is checked by looking up the Gateway and retrieving the partition_id,
        #      the Gateway belongs to. Beside the partition_id, a boolean value :has_target_fusions is gathered to skip Step 5 (and thus
        #      reduce latency by one query if no target fusions are used in partition). The :has_target_fusions is set to true for all
        #      gateways within one partition if at least one target_fusion object is in use within the access rules.
        #
        #   Each of the following steps, gathers access_ids, the object has associated with (array within record) and reduces the list
        #   of possible access_ids by intersection of the array gathered so far from the step before. If one of the steps results in
        #   an empty list of access_ids, the procedure interrupts with a deny message.
        #
        #   2. Lookup Gateway User
        #      -> First array of access_ids
        #   3. Lookup possible Targets
        #      -> Reduce array of access_ids by access_ids from Targets
        #   4. Lookup Target User
        #      a. Login User
        #      b. Regex Users
        #      c. Mapping Users
        #      -> Reduce array of access_ids by access_ids from Target Users
        #   5. Lookup Target Fusions (if Login User is found)
        #      Found Login User and target_ids
        #      --> add found access_ids to list of access_ids
        #   6. In the next step, the remaining list of access_ids is used to get all possible accesses in given order (:position)
        #   7. All Accesses, that do not match the given Source IP of the Connection are sorted out
        #   8. The Accesses list is reduced to a list up to the first rule with a Deny (empty Profile, id == 0)
        #   9. All Targets that are no longer addressed by the remaining Accesses list are removed from list of targets
        #   10. Within all remaining targets, the access_ids are sorted by the remaining access list
        #   11. In a last Step, the object serializer is triggered to generate the whole response
        #       - If target proxies are referred and they have their own, individual gateway authentication
        #         keys for target authentication, this keys are added in TargetUserKeys: attribute.
        #   12. Peek in Information from Client Auth Set

        while true # Just to break out in case of @auth_hook.error

          #-- 1. Lookup Gateway and Partition + has_target_fusions (which allows to skip SwiftTargetFusion query if no TargetFusions in use for Partition)
          @auth_hook.partition_id, has_target_fusions = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id, :has_target_fusions).first
          unless @auth_hook.partition_id
            @auth_hook.error = 'Gateway or Partition not found'
            break
          end

          @auth_hook.partition_id = @auth_hook.partition_id

          #-- 2. Susshi Users
          @auth_hook.susshi_user = SwiftSusshiUser.where(partition_id: @auth_hook.partition_id, name: @params.susshi_user).first
          unless @auth_hook.susshi_user
            @auth_hook.error = 'Gateway User not found or not used in any access rule'
            break
          end

          unless @auth_hook.susshi_user.auth_passable?
            @auth_hook.error = 'Too many authentication failures for Gateway User'
            auth_locked = true
            break
          end

          access_ids = @auth_hook.susshi_user.access_ids
          unless access_ids.any?
            @auth_hook.error = 'Gateway User is not allowed in any access rule'
            break
          end

          #-- 3. Targets
          @auth_hook.targets = SwiftTarget.where(partition_id: @auth_hook.partition_id, proxy_realm: @params.target_proxy_realm)
                                          .where('((target_ip >>= ANY(array[?]::inet[])) OR (target_name IN (?)))',
                                          @params.target_ips, ([@params.target_host_name] + @params.target_domains)).load

          unless @auth_hook.targets.any?
            @auth_hook.error = 'Target not found or not used in any access rule'
            break
          end

          access_ids &= @auth_hook.targets.collect { |t| t.access_ids }.flatten.uniq
          unless access_ids.any?
            @auth_hook.error = 'Target not found in any access rule'
            break
          end

          #-- 4. Target Users (a) - Login Users
          target_user = SwiftTargetUser.where(partition_id: @auth_hook.partition_id, name: @params.target_user).first
          tu_access_ids = target_user.access_ids rescue []

          #-- 4. Target Users (b) - Regex Users
          SwiftTargetUserRegex.where(access_id: access_ids).each do |user|
            tu_access_ids << user.access_id if user.regexes.select { |regex|
              begin
                @params.target_user =~ /#{regex}/
              rescue RegexpError
                false
              end
            }.any?
          end

          #-- 4. Target Users (c) - Mapping Users
          SwiftTargetUserMapping.where(access_id: access_ids).each do |user|
            user.translations.each do |translation|
              begin
                next unless @params.susshi_user =~ /#{translation.first}/
                translated = @params.susshi_user.gsub(/#{translation.first}/, translation.second.gsub('$', '\\'))
                if SwiftTargetUserMapping.regex_target_user(translation.last, translated) =~ @params.target_user
                  tu_access_ids << user.access_id
                end
              rescue RegexpError
                next
              end
            end
          end

          #-- 5. Find TargetFusions (if SwiftGateway.has_target_fusions is true and TargetUserLogin is found)
          if has_target_fusions and target_user
            tu_access_ids += SwiftTargetFusion.where(target_user_id: target_user.id, target_id: @auth_hook.targets.map(&:target_id))
                                              .map(&:access_ids).flatten
          end

          # Reduce access_ids by sum of all target user access IDs (tu_access_ids)
          access_ids &= tu_access_ids

          unless access_ids.any?
            @auth_hook.error = 'Target User is not allowed in any access rule'
          end

          #-- 6. Access Rules ordered by position
          @auth_hook.accesses = SwiftAccess.order(:position).where(id: access_ids).to_a

          #-- 7. Sort out Accesses where SourceIPs do not match
          @auth_hook.accesses.select! do |access|
            sources = SwiftSource.where(id: access.source_ids).pluck(:ip)
            ip_address_included?(sources, @params.client_ip)
          end

          #-- 8. Deny rules (profile_id == 0)
          unless (first_deny_rule = @auth_hook.accesses.index { |access| access.profile_id == 0 }).blank?
            @auth_hook.accesses = first_deny_rule == 0 ? [] : @auth_hook.accesses[0..(first_deny_rule - 1)]
          end

          break unless @auth_hook.accesses.any?

          #- Refine access_ids
          @auth_hook.access_ids = @auth_hook.accesses.collect { |access| access.id }

          #-- 9. Reduce targets to only contain targets referenced by remaining access_ids
          @auth_hook.targets = @auth_hook.targets.reject do |target|
            (target.access_ids & @auth_hook.access_ids).blank?
          end.uniq

          break unless @auth_hook.targets.any?

          #-- 10. Sort access_ids within targets according access_ids list
          #-> later in ControllersSerializers::Sessions::Context.Target, we access first element of access_ids
          #   for sorting out order the targets are within the access rules
          @auth_hook.targets.each { |target|
            target.access_ids = @auth_hook.access_ids & target.access_ids
          }

          # Used in Serializer
          @auth_hook.target_proxy_realm = @params.target_proxy_realm

          #-- 11. Serialize Response
          @auth_hook.response = ControllersSerializers::Sessions::ContextGatewayMode.new(@auth_hook).to_h

          #-- 12. Add Information from Client Auth Set
          if @auth_hook.response[:ClientAuthSetId] != 'invalid'
            add_client_auth_set_information_and_ip_cache
          else
            @auth_hook.error = 'Client authentication to be used is ambiguous for different targets.'
            break
          end

          # Hook: Before Response success
          break unless @auth_hook.hook_before_response_success

          if ENV["VERBOSE_SESSIONS_CONTROLLER"]
            puts "Response to susshid: #{@auth_hook.response.to_yaml}"
          end

          #-- Success!
          respond_to do |format|
            format.json do
              render json: @auth_hook.response.to_json
              return
            end
          end

        end

        @auth_hook.error ||= 'Access prohibited'

        deny_request(@auth_hook.partition_id, :gateway, @auth_hook.error,
                     @params.susshi_uniq_id, @params.client_ip, @params.client_port,
                     @params.susshi_user, @params.login_string, target_user: @params.target_user,
                     target_host: @params.target_host_name, target_ips: @params.target_ips,
                     target_port: @params.target_port, proxy_realm: @params.target_proxy_realm,
                     http_code: auth_locked ? 406 : 404)

      when 'bastion'

        #=== Bastion Mode

        while true # Just to break out in case of @auth_hook.error

          #-- 1. Lookup Gateway and Partition
          @auth_hook.partition_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
          unless @auth_hook.partition_id
            @auth_hook.error = 'Partition not found'
            break
          end

          #-- 2. Susshi Users
          @auth_hook.susshi_user = SwiftSusshiUser.where(partition_id: @auth_hook.partition_id, name: @params.susshi_user).first
          unless @auth_hook.susshi_user
            @auth_hook.error = 'User not found or not used in any bastion rule'
            break
          end

          unless @auth_hook.susshi_user.auth_passable?
            @auth_hook.error = 'Too many authentication failures for Gateway User'
            auth_locked = true
            break
          end

          bastion_ids = @auth_hook.susshi_user.bastion_ids

          unless bastion_ids.any?
            @auth_hook.error = 'User is not allowed in any bastion rule'
            break
          end

          #-- 3. Proxy
          unless @params.target_proxy_realm
            @auth_hook.error = 'Bastion mode only supported with proxy realm'
            break
          end

          proxy = SwiftProxy.where(partition_id: @auth_hook.partition_id, realm: @params.target_proxy_realm).first
          unless proxy
            @auth_hook.error = 'Proxy realm not found'
            break
          end

          # Reduce bastion_ids to match proxy bastion_ids
          bastion_ids &= proxy.bastion_ids
          break unless bastion_ids.any?

          #-- 4. Bastion Rules
          bastions = SwiftBastion.order(:position).where(id: bastion_ids).to_a
          break unless bastions.any?

          # Bastions are already ordered
          @auth_hook.bastion = bastions.select do |bastion|
            sources = SwiftSource.where(id: bastion.source_ids).pluck(:ip)
            ip_address_included?(sources, @params.client_ip)
          end.first

          break unless @auth_hook.bastion

          #-- 5. Response

          # Used in Serializer
          @auth_hook.target_proxy_realm = @params.target_proxy_realm

          #-- 6. Serialize Response
          @auth_hook.response = ControllersSerializers::Sessions::ContextBastionMode.new(@auth_hook).to_h

          #-- 7. Add Information from Client Auth Set
          add_client_auth_set_information_and_ip_cache

          # Hook: Before Response success
          break unless @auth_hook.hook_before_response_success

          if ENV["VERBOSE_SESSIONS_CONTROLLER"]
            puts "Response to susshid: #{@auth_hook.response.to_yaml}"
          end

          #-- Success!
          respond_to do |format|
            format.json do
              render json: @auth_hook.response.to_json
              return
            end
          end

        end

        @auth_hook.error ||= 'User is not allowed to run bastion mode'

        deny_request(@auth_hook.partition_id, :bastion, @auth_hook.error,
                     @params.susshi_uniq_id, @params.client_ip, @params.client_port,
                     @params.susshi_user, @params.login_string,
                     http_code: auth_locked ? 406 : 404)

      when 'shell'

        #=== Access to suSSHi Shell

        while true # Just to break out in case of @auth_hook.error

          #-- 1. Lookup Gateway and Partition
          @auth_hook.partition_id = SwiftGateway.where(identifier: @params.susshid_id).pluck(:partition_id).first
          unless @auth_hook.partition_id
            @auth_hook.error = 'Partition not found'
            break
          end

          #-- 2. Susshi Users
          @auth_hook.susshi_user = SwiftSusshiUser.where(partition_id: @auth_hook.partition_id, name: @params.susshi_user).first
          unless @auth_hook.susshi_user
            @auth_hook.error = 'User not found'
            break
          end

          @auth_hook.error = 'Shell Mode is not supported at all'
          break

          break unless @auth_hook.susshi_user.shell_login

          access_ids = @auth_hook.susshi_user.access_ids
          break unless access_ids.any?

          #-- Access Rules
          accesses = SwiftAccess.order(:position).where(id: access_ids).to_a

          # Accesses are already ordered
          @auth_hook.access = accesses.select do |access|
            sources = SwiftSource.where(id: access.source_ids).pluck(:ip)
            ip_address_included?(sources, @params.client_ip)
          end.first

          break unless @auth_hook.access

          # Deny rule
          break if @auth_hook.access.profile_id == 0

          @auth_hook.response = ControllersSerializers::Sessions::ContextShellMode.new(@auth_hook).to_h

          # Hook: Before Response success
          break unless @auth_hook.hook_before_response_success

          if ENV["VERBOSE_SESSIONS_CONTROLLER"]
            puts "Response to susshid: #{@auth_hook.response.to_yaml}"
          end

          #-- Success!
          respond_to do |format|
            format.json do
              render json: @auth_hook.response.to_json
              return
            end
          end

        end
        @auth_hook.error ||= 'User is not allowed to access suSSHi shell.'

        deny_request(@auth_hook.partition_id, :shell, @auth_hook.error,
                     @params.susshi_uniq_id, @params.client_ip, @params.client_port,
                     @params.susshi_user, @params.login_string)
      end

    end

    private

    def validate_session_params
      @params = Api::V1::Validate::Sessions.new(params)
      validate_params(@params)
    end

    def deny_request(partition_id, op_mode, text, susshi_uniq_id, client_ip, client_port, susshi_user, login_string, target_user: nil, target_host: nil, target_ips: nil, target_port: nil, proxy_realm: nil, http_code: 404)
      now = Time.now
      SessionReport.create(partition_id:  partition_id, operation_mode: SessionReport.operation_modes_sym.key(op_mode), message: "#{text}.", susshi_uniqid: susshi_uniq_id,
                           session_state: 'denied', client_ip: client_ip, client_port: client_port, susshi_user: susshi_user, target_user: target_user,
                           target_ip:     (target_ips.first rescue nil), target_host: target_host, target_port: target_port, proxy_realm: proxy_realm,
                           session_start: now, login_string: login_string, session_end: now, session_time: 0)
      respond_with_error(text, http_code)
    end

    def log_accept_request(partition_id, op_mode, susshi_uniq_id, client_ip, client_port, susshi_user, login_string, target_user = nil, target_host = nil, target_ips = nil, target_port = nil, proxy_realm = nil)
      now = Time.now
      SessionReport.create(partition_id:  partition_id, operation_mode: SessionReport.operation_modes_sym.key(op_mode), susshi_uniqid: susshi_uniq_id,
                           session_state: 'new', client_ip: client_ip, client_port: client_port, susshi_user: susshi_user, target_user: target_user,
                           target_ip:     (target_ips.first rescue nil), target_host: target_host, target_port: target_port, proxy_realm: proxy_realm,
                           session_start: now, login_string: login_string, session_time: 0)
    end

    def ip_address_included?(source_ips, source_ip)
      source_ips.each do |ip|
        return true if ip.include?(IPAddr.new(source_ip))
      end
      false
    end

    def respond_with_error(text, code)
      respond_to do |format|
        format.text { render :text => text, :status => code }
        format.json { render :json => { :error => text }, :status => code }
        format.xml { render :xml => { :error => text }, :status => code }
      end
    end

    def add_client_auth_set_information_and_ip_cache
      if (cas = SwiftClientAuthSet.find_by(id: @auth_hook.response[:ClientAuthSetId]))
        @auth_hook.response.merge! cas.auth_hook_response_params(@auth_hook, @params, @auth_hook.response)
      end
    end

  end
end
