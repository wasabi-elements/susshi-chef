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

class Partition < ApplicationRecord

  has_and_belongs_to_many :users

  has_one :partition_setting, dependent: :destroy
  has_many :gateways, dependent: :destroy

  has_many :session_reports, dependent: :destroy
  has_many :susshi_users, dependent: :destroy
  has_many :accesses, dependent: :destroy
  has_many :bastions, dependent: :destroy
  has_many :profiles, dependent: :destroy
  has_many :bastion_profiles, dependent: :destroy
  has_many :client_auth_sets, dependent: :destroy
  has_many :target_auth_keys, dependent: :destroy
  has_many :target_domain_hosts, dependent: :destroy
  has_many :target_fusions, dependent: :destroy
  has_many :targets, dependent: :destroy
  has_many :target_users, dependent: :destroy
  has_many :proxies, dependent: :destroy
  has_many :source_ips, dependent: :destroy

  has_many :partition_host_keys, dependent: :destroy
  has_many :partition_auth_keys, dependent: :destroy

  has_many :swift_changes, dependent: :destroy
  has_many :swift_client_auth_sets, dependent: :destroy
  has_many :swift_accesses, dependent: :delete_all
  has_many :swift_bastions, dependent: :delete_all
  has_many :swift_bastion_profiles, dependent: :delete_all
  has_many :swift_gateways, dependent: :delete_all
  has_many :swift_partitions, dependent: :delete_all
  has_many :swift_profiles, dependent: :delete_all
  has_many :swift_proxies, dependent: :delete_all
  has_many :swift_sources, dependent: :delete_all
  has_many :swift_susshi_users, dependent: :delete_all
  has_many :swift_targets, dependent: :delete_all
  has_many :swift_target_users, dependent: :delete_all
  has_many :swift_target_user_regexes, dependent: :delete_all
  has_many :swift_target_user_mappings, dependent: :delete_all
  has_many :api_tokens, dependent: :destroy

  #-- susshid settings

  include Chef::SusshidSettings

  #-- Validations

  validates :name, :presence => true
  validates :name, :uniqueness => { :case_sensitive => false, :message => 'partition with same name already exists' }

  #-- Callbacks

  after_create_commit do
    self.class.create_partition_related_models(self)

    users = users_with_log_encryption_key.sort_by(&:name).to_a
    if users.any?
      SwiftChange.create_for(
        self,
        change_trail: users.map { |u| "Added Encryption Key for User '#{u.name}'" },
        whodunit: User.current_user&.name || "System"
      )
    end

    Access.activate(self, "System", ["Activated by System"])
  end

  #-- Class methods

  class << self

    # Called from Gateway after_destroy callback
    def update_all_partition_settings!
      Partition.all.each do |partition|
        partition.partition_setting.update_gateways!
      end
    end

    def create_partition_related_models(partition)
      PartitionSetting.create(partition: partition,
                              ClientCiphers: %w(aes256-ctr aes256-cbc aes192-ctr aes192-cbc),
                              TargetCiphers: %w(aes256-ctr aes256-cbc aes192-ctr aes192-cbc aes128-ctr aes128-cbc blowfish-cbc))

      TargetUserRegex.create(partition: partition, name: 'Any', regex: '.*',
                             description: 'Any user on target', system_int: true)
      TargetUserMapping.create(partition: partition, name: 'Gateway-Username', regex: '(.*)', translate: '$1', regex_target_user: '%translated%',
                               description: 'Same Username used for gateway authentication', system_int: true)
      %w[admin root].each { |name| TargetUserLogin.create(partition: partition, name:, description: 'Admin User', system_int: true) }
      TargetUserGroup.create(partition: partition, name: 'Admin-Users', target_users: TargetUserLogin.where(partition: partition).all,
                             description: 'Administrative Users')

      SourceIpNet.create(partition: partition, name: 'Any IPv4', description: 'IPv4 Internet', ip_address: '0.0.0.0/0', system_int: true)
      SourceIpNet.create(partition: partition, name: 'Any IPv6', description: 'IPv6 Internet', ip_address: '::0/0', system_int: true)
      SourceIpGroup.create(partition: partition, name: 'Any', description: 'Any sources', source_ip_nets: SourceIpNet.where(partition: partition).all)

      cas = ClientAuthSet.create(partition:               partition, name: 'Default', description: 'Default client authentication set',
                                 comment:                 'This is the system provided default client authentication set.',
                                 auth_logic:              'any', system_int: true,
                                 publickey_client_auth:   ClientAuth::Publickey.new,
                                 interactive_client_auth: ClientAuth::Password.new)

      Profile.create(partition: partition, name: 'Full access', description: 'Full access and logging', client_auth_set: cas)
      Profile.create(partition: partition, name: 'Interactive only', description: 'Interactive SSH access only', client_auth_set: cas,
                     SSHSessionSubsystems: [], SSHLocalForwards: [], SSHRemoteForwards: [], SSHCommandExecs: [],
                     SSHAgentForward: false, SSHX11Forward: false, SSHSecureCopy: false, SSHSecureFileTransfer: false, SSHTcpForwardSsh: false )
      Profile.create(partition: partition, name: 'Secure Copy only', description: 'Secure Copy only', client_auth_set: cas,
                     SSHSessionSubsystems: [], SSHLocalForwards: [], SSHRemoteForwards: [], SSHCommandExecs: [],
                     SSHAgentForward: false, SSHX11Forward: false, SSHInteractive: false, SSHTcpForwardSsh: false )

      PartitionHostKey.create(partition: partition, title: 'RSA Host Key', key_type: 'ssh-rsa', bits: 4096)
      PartitionHostKey.create(partition: partition, title: 'ED25519 Host Key', key_type: 'ssh-ed25519', bits: 256)

      PartitionAuthKey.create(partition: partition, title: 'RSA Authentication Key', key_type: 'ssh-rsa', bits: 4096)
      PartitionAuthKey.create(partition: partition, title: 'ED25519 Authentication Key', key_type: 'ssh-ed25519', bits: 256)

      BastionProfile.create(partition: partition, name: 'Bastion Full access', description: 'Full access and logging', client_auth_set: cas)
    end
  end

  def last_swift_changes_activation
    swift_changes.find_by(klass: "Activation", partition: self, swift_version: previous_swift_version)
  end

  def num_swift_changes
    pending_swift_changes.count
  end

  def pending_swift_changes
    swift_changes.where(partition: self, swift_version: current_swift_version).where.not(klass: "Activation")
  end

  def previous_swift_version
    current_swift_version - 1
  end

  def swift_config_hash
    config = partition_setting.swift_config_hash
    unless (hostkeys = self.partition_host_keys.order(:order).where(active: true).limit(256)).blank?
      config.merge!('HostKeys' => hostkeys.collect { |k| k.swift_config_hash })
    end
    unless (authkeys = self.partition_auth_keys.order(:order).where(active: true).limit(256)).blank?
      config.merge!('TargetIdentityKeys' => authkeys.collect { |k| k.swift_config_hash })
    end
    config
  end

  def users_with_log_encryption_key
    users.where.not(log_encryption_key: [nil, ""])
  end
end
