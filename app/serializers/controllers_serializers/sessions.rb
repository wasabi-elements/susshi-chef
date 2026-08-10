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

module ControllersSerializers

  class Sessions

    class ContextGatewayMode < ActiveModel::Serializer

      attr_accessor :preserve_password, :client_auth_set_id

      attributes :UserAuthorizedKeys, :Target, :PreservePassword, :ClientAuthSetId

      attribute :TargetUserKeys, if: :include_target_user_keys?

      def include_target_user_keys?
        object.params.target_proxy_realm &&
          !SwiftProxy.find_by(partition: object.partition_id, realm: object.params.target_proxy_realm).identities.blank?
      end

      def UserAuthorizedKeys
        object.susshi_user.keys
      end

      def Target
        targets = {}
        object.targets
            .sort{|x,y| object.access_ids.index(x.access_ids.first) <=> object.access_ids.index(y.access_ids.first)}
            .each do |target|
          set_targets = case target.kind
                          when 'Static'
                            [ target.target_ip.to_s ]
                          when 'Network'
                            object.params.target_ips.select{|ip| target.target_ip.include?(IPAddr.new(ip))}
                          when 'Dynamic'
                            [ target.target_name ]
                          when 'Domain'
                            [ object.params.target_host_name ]
                        end
          set_targets.each do |identity|
            targets[identity] ||= ControllersSerializers::Sessions::Target.new(object, target, identity).to_h
          end
        end
        @preserve_password  = (targets.select{|target, values| values[:TargetPasswordSource] == 'preserve' }.count > 0)
        @client_auth_set_id = (targets.map   {|target, values| values[:ClientAuthSetId] }).uniq
        @client_auth_set_id = @client_auth_set_id.count == 1 ? @client_auth_set_id.first : 'invalid'
        targets
      end

      def TargetUserKeys
        proxy = SwiftProxy.find_by(partition: object.partition_id, realm: object.params.target_proxy_realm)

        # Generate opaque cache key (avoid exposing sensitive identifiers in filesystem)
        cache_key = Digest::MD5.hexdigest("#{object.params.susshid_id}/#{proxy.id}/identities")
        cache = Rails.cache.read(cache_key) || {}

        crc = proxy.identities.reduce(Zlib.crc32(object.params.memcrypt_key)) { |crc, i| Zlib.crc32(i["fingerprint"], crc) }

        unless cache[:crc] == crc
          cache = {crc:, identities: proxy.identities_encrypted(object.params.memcrypt_key)}
          Rails.cache.write(cache_key, cache)
        end

        cache[:identities]
      end

      def PreservePassword
        @preserve_password
      end

      def ClientAuthSetId
        @client_auth_set_id
      end

    end



    class ContextShellMode < ActiveModel::Serializer

      attributes :UserAuthorizedKeys, :Target

      def UserAuthorizedKeys
        object.susshi_user.keys
      end

      def Target
        {
            Gateway: {
                AccessRuleId:  object.access.id,
                ShellLogin:    true,
                Configuration: {}
            }
        }
      end

    end

    class ContextBastionMode < ActiveModel::Serializer

      attr_accessor :client_auth_set_id

      attributes :UserAuthorizedKeys, :Target, :ClientAuthSetId

      def UserAuthorizedKeys
        object.susshi_user.keys
      end

      def Target
        @bastion_profile = SwiftBastionProfile.find(object.bastion.bastion_profile_id)
        @client_auth_set_id = @bastion_profile.config['client_auth_set_id']
        {
            Bastion: {
                BastionRuleId:  object.bastion.id,
                ProfileName: @bastion_profile.config['name'],
                ClientAuthSetId: @client_auth_set_id,
                LoggingMask: @bastion_profile.config['LoggingMask'],
                MaxSessionSeconds: @bastion_profile.config['MaxSessionSeconds'],
                MaxSessionIdleSeconds: @bastion_profile.config['MaxSessionIdleSeconds'],
                SSHInteractive: true, # This allows clients that request interactive login to access Bastion, but does not allow login
                SSHTcpForwardSsh: @bastion_profile.config['SSHTcpForwardSsh'],
                SSHLocalForwards: @bastion_profile.config['SSHLocalForwards'].collect { |fwd| fwd.reverse.sub(':', '|').reverse.gsub(/[\[\]]/, '') }.reject { |fwd| fwd.blank? },
                Configuration: {
                    TargetPreferredAuthentications: ['publickey']
                }.merge(@bastion_profile.config['SessionLogEncryptionKeys'].blank? ? {} : { 'SessionLogEncryptionKeys' => @bastion_profile.config['SessionLogEncryptionKeys'] })
            }
        }
      end

      def ClientAuthSetId
        @client_auth_set_id
      end

    end


    class Target < ActiveModel::Serializer

      attributes :Id, :AccessRuleId, :ClientAuthSetId, :ProfileName, :LoggingMask,
                 :MaxSessionSeconds, :MaxSessionIdleSeconds, :SSHSessionSubsystems,
                 :TargetHostKeyLearning, :TargetHostKeys, :TargetPasswordSource,
                 :SSHAgentForward, :SSHX11Forward, :SSHInteractive, :SSHSecureCopy, :SSHTcpForwardSsh, :SSHSecureFileTransfer,
                 :SSHSocketForward, :SSHLocalForwards, :SSHRemoteForwards, :SSHCommandExecs, :Configuration

      attribute :OverwriteTargetUser, unless: -> { @profile.config['TargetUser'].blank? }
      attribute :TargetPassword, if: -> { %w(static dotp).include?(@profile.config['TargetPasswordSource']) }
      attribute :TargetPasswordContinue, if: -> { %w(preserve static dotp).include?(@profile.config['TargetPasswordSource']) }

      delegate  :MaxSessionsSeconds, to: :profile_config

      def initialize(auth_hook, target, target_identity)
        super auth_hook
        @auth_hook = auth_hook
        @target = target
        @target_identity = target_identity
        @access  = object.accesses.select { |access| target.access_ids.include?(access.id) }.first
        @profile = SwiftProfile.find(@access.profile_id)
      end

      def Id
        @target.target_id
      end

      def AccessRuleId
        @access.id
      end

      def ClientAuthSetId
        @profile.config['client_auth_set_id']
      end

      def ProfileName
        @profile.config['name']
      end

      def LoggingMask
        @profile.config['LoggingMask']
      end

      def MaxSessionIdleSeconds
        @profile.config['MaxSessionIdleSeconds'] ||= 31622400
      end

      def MaxSessionSeconds
        @profile.config['MaxSessionSeconds'] ||= 31622400
      end

      def SSHAgentForward
        @profile.config['SSHAgentForward']
      end

      def SSHSecureFileTransfer
        @profile.config['SSHSecureFileTransfer']
      end

      def SSHInteractive
        @profile.config['SSHInteractive']
      end

      def SSHSecureCopy
        @profile.config['SSHSecureCopy']
      end

      def SSHTcpForwardSsh
        @profile.config['SSHTcpForwardSsh']
      end

      def SSHX11Forward
        @profile.config['SSHX11Forward']
      end

      def SSHSocketForward
        @profile.config['SSHSocketForward']
      end

      def SSHSessionSubsystems
        @profile.config['SSHSessionSubsystems']
      end

      def TargetHostKeyLearning
        @profile.config['TargetHostKeyLearning']
      end

      def SSHLocalForwards
        @profile.config['SSHLocalForwards'].collect { |fwd| fwd.reverse.sub(':', '|').reverse.gsub(/[\[\]]/, '') }.reject { |fwd| fwd.blank? }
      end

      def SSHRemoteForwards
        @profile.config['SSHRemoteForwards'].collect { |fwd| fwd.reverse.sub(':', '|').reverse.gsub(/[\[\]]/, '') }.reject { |fwd| fwd.blank? }
      end

      def SSHCommandExecs
        @profile.config['SSHCommandExecs'].reject { |cmd| cmd.blank? }.collect { |cmd| "^#{cmd}$" }
      end

      def TargetPassword
        case @profile.config['TargetPasswordSource']
        when 'static'
          @profile.config['TargetPassword'].blank? ? '' : @profile.config['TargetPassword']
        when 'dotp'
          if @profile.config['TargetPasswordCheckIdentity'] then
            target_identity = (IPAddress.parse(@target_identity) rescue nil) || @target_identity.split('.').first
          end

          # Add some extra time for the DOTP ticket if user can use interactive method,
          # otherwise ticket may expire before user enters its credentials
          valid_time_add =
            if SwiftClientAuthSet.find(@profile.config["client_auth_set_id"])&.interactive_auth_properties == {"type" => "none"}
              0
            else
              SwiftPartition.find(@profile.partition_id).config["LoginGraceTime"]
            end

          target_user = @profile.config['TargetUser'].blank? ?
                          @auth_hook.params.target_user : @profile.config['TargetUser'].gsub('$1', @auth_hook.params.target_user)
          SwiftDotpTicket.create_ticket(partition_id:    @profile.partition_id,
                                        target_user:     target_user,
                                        target_identity: target_identity,
                                        valid_time:      @profile.config['TargetPasswordValidSeconds'] + valid_time_add,
                                        password_length: @profile.config['TargetPasswordLength'],
                                        susshi_uniqid:   @auth_hook.params.susshi_uniq_id)
        end
      end

      def TargetPasswordSource
        @profile.config['TargetPasswordSource']
      end

      def TargetPasswordContinue
        @profile.config['TargetPasswordContinue']
      end

      def OverwriteTargetUser
        @profile.config['TargetUser'].blank? ? nil : @profile.config['TargetUser'].gsub('$1', @auth_hook.params.target_user)
      end

      def Configuration
        config = {}
        config['DebugLevel'] = (@access.debug_level || 0) unless object.gw_version < 190500
        config['TargetPreferredAuthentications'] = @profile.config['TargetPreferredAuthentications'] unless @profile.config['TargetPreferredAuthentications'].blank?
        config['SessionLogEncryptionKeys'] = @profile.config['SessionLogEncryptionKeys'] unless @profile.config['SessionLogEncryptionKeys'].blank?
        config
      end

      def TargetHostKeys
        keys = []
        case @target.kind
          when 'Domain'
            target_host = SwiftDomainHost.where(partition_id: object.partition_id, name: @target_identity, proxy_realm: object.params.target_proxy_realm).first
            if target_host
              keys = target_host.user_keys[object.susshi_user.name] if target_host.user_keys && target_host.user_keys[object.susshi_user.name]
            end
          when 'Network'
            # Look in static targets first
            target_host = SwiftTarget.where(partition_id: object.partition_id, target_ip: @target_identity, proxy_realm: object.params.target_proxy_realm).first
            if target_host
              keys = (target_host.user_keys && target_host.user_keys[object.susshi_user.name]) ? target_host.user_keys[object.susshi_user.name] : target_host.keys
              return keys unless keys.blank?
              # We fall through here if the target host keys have been recorded under SwiftNetworkHosts ...
            end
            target_host = SwiftNetworkHost.where(partition_id: object.partition_id, address: @target_identity, proxy_realm: object.params.target_proxy_realm).first
            if target_host
              keys = target_host.user_keys[object.susshi_user.name] if target_host.user_keys && target_host.user_keys[object.susshi_user.name]
            end
          else
            # Static or Dynamic
            keys = (@target.user_keys && @target.user_keys[object.susshi_user.name]) ? @target.user_keys[object.susshi_user.name] : @target.keys
        end
        keys
      end
    end

  end
end
