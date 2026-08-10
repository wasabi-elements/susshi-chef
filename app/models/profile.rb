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

class Profile < ApplicationRecord
  encrypts :TargetPassword

  include SwiftChangeTracker

  #-- Datatypes
  attr_accessor :lm # Just for strong parameters in validation

  #-- Associations
  belongs_to :partition
  belongs_to :client_auth_set
  has_many :accesses, dependent: :restrict_with_error

  #-- Scopes

  #-- Validations

  validates :name, :presence => true
  validates :name, exclusion: { in: %w(DENY), message: 'DENY is a reserved keyword' }
  validates :name, :uniqueness => { case_sensitive: false, scope: :partition_id, message: 'profile with same name already exists within partition' }
  validate :local_forwards_validation
  validate :remote_forwards_validation
  validate :validate_TargetPreferredAuthentications

  validates :MaxSessionSeconds, inclusion: { in: 60..31622400, message: 'valid range is between 60 - 31622400, default is 86400', :allow_nil => true }
  validates :MaxSessionIdleSeconds, inclusion: { in: 60..31622400, message: 'valid range is between 60 - 31622400, default is 43200', :allow_nil => true }
  validate :validate_MaxSessionIdleSeconds

  validates :TargetPasswordSource, inclusion: { in: %w(dialog preserve static dotp) }
  validates :TargetPasswordLength, inclusion: { in: 8..64, message: 'valid range is between 8 - 64, default is 32' }
  validates :TargetPasswordValidSeconds, inclusion: { in: 2..300, message: 'valid range is between 2 - 30, default is 5' }
  validates :TargetPassword, :presence => true,
            if: -> { self.TargetPasswordSource == 'static' }
  validates :TargetPassword_confirmation, presence: true,
            if: -> { self.TargetPasswordSource == 'static' and self.TargetPassword_changed? }

  validates_confirmation_of :TargetPassword, :message => "should match Target Password",
                            if: -> { self.TargetPasswordSource == 'static' and self.TargetPassword_changed? }

  #-- Callbacks

  before_validation :normalize_command_exec
  before_validation :normalize_forwards
  before_validation :normalize_session_subsystem
  before_validation :normalize_TargetPreferredAuthentications
  before_validation :normalize_TargetUser
  before_validation :normalize_TargetPasswordSource
  before_validation :default_client_auth_set

  #-- Class Methods

  class << self

    def icon
      'fa-toggle-on'
    end

    def hostkey_learning_collection
      [ ['Never', 'never'],
        ['Automatically: If unknown', 'ifunknown'],
        ['Automatically: If unknown and if changes', 'update'],
        ['Prompt User for new and changed keys', 'prompt'] ]
    end

    def all_collection
      Profile.order("LOWER(name) ASC").where(partition_id: User.current_user.partition.id).collect {|p| [p.name, p.id]}
    end

    def config_params
      [ :LoggingMask, :MaxSessionIdleSeconds, :MaxSessionSeconds, :SSHAgentForward, :SSHSecureFileTransfer, :SSHInteractive, :SSHSecureCopy,
        :SSHTcpForwardSsh, :SSHX11Forward, :SSHSocketForward,
        SSHCommandExecs: [], SSHLocalForwards: [], SSHRemoteForwards: [], SSHSessionSubsystems: [] ]
    end

    def configuration_keys_auto
      [ :LoggingMask, :MaxSessionIdleSeconds, :MaxSessionSeconds, :SSHAgentForward, :SSHSecureFileTransfer, :SSHInteractive, :SSHSecureCopy,
        :SSHTcpForwardSsh, :SSHX11Forward, :SSHSocketForward, :SSHSessionSubsystems ]
    end

    def target_authentication_collection
      [ ['Public Key - Gateway (or Proxy Individual) Identities', 'publickey'],
        ['Public Key - User SSH Auth Agent Forwarding *', 'publickey-ssh-agent'],
        ['Keyboard Interactive', 'keyboard-interactive'],
        ['Password', 'password'] ]
    end

    def target_password_source_collection
      [ ['User Dialog', 'dialog'],
        ['Preserve Password', 'preserve'],
        ['Static Password', 'static'],
        Subscription.instance.feature_dynamic_otp? ? ['Dynamic One-Time Password', 'dotp'] : nil ].compact
    end

    def split_ip_port(socket)
      case socket
        when /\A\[(?<address> .* )\]:(?<port> (\d+|\*) )\z/x      # socket like "[::1]:80" or "[::1]:*"
          address, port = $~[:address], $~[:port]
        when /\A(?<address> [^:]+ ):(?<port> (\d+|\*) )\z/x       # socket like "127.0.0.1:80" or "127.0.0.1:*"
          address, port = $~[:address], $~[:port]
        else                                                      # socket without port
          address, port = socket.gsub(/[\[\]]/,""), nil
      end
      return address, port
    end

  end

  #-- Instance Methods

  def SSHLocalForwards_api
    self.SSHLocalForwards.collect do |fwd|
      fwd.reverse.sub(':','|').reverse.gsub(/[\[\]]/,'')
    end.reject{|fwd| fwd.blank?}
  end

  def SSHRemoteForwards_api
    self.SSHRemoteForwards.collect do |fwd|
      fwd.reverse.sub(':','|').reverse.gsub(/[\[\]]/,'')
    end.reject{|fwd| fwd.blank?}
  end

  def SSHCommandExecs_api
    self.SSHCommandExecs.reject{|fwd| fwd.blank?}.collect do |fwd|
      "^#{fwd}$"
    end
  end

  def SessionLogEncryptionKeys
    return {} unless self.respond_to?(:LogEncryption) # Guard against missing attribute (e.g. pending migrations)
    return {} unless self.LogEncryption

    {
      "SessionLogEncryptionKeys" => User.joins(:partitions).where(partitions: { id: partition_id })
                                 .where.not(log_encryption_key: [nil, ""])
                                 .pluck(:log_encryption_key, :username)
                                 .map{|key, username| [key, username].join(" ")}
    }
  end

  def swift_config_hash
    attributes.except('id', 'description', 'created_at', 'updated_at', 'partition_id', 'LogEncryption').merge(self.SessionLogEncryptionKeys).compact.to_h
  end

  def is_destroyable?
    return {false: 'Is assigned to an Access Rule'}  if accesses.any?
    {true: "Delete Profile '#{self.name}'"}
  end

  def SSHCommandExecs_add(values)
    self.SSHCommandExecs += values
  end

  def SSHCommandExecs_remove(values)
    self.SSHCommandExecs -= values
  end

  def SSHLocalForwards_add(values)
    self.SSHLocalForwards += values
  end

  def SSHLocalForwards_remove(values)
    self.SSHLocalForwards -= values
  end

  def SSHRemoteForwards_add(values)
    self.SSHRemoteForwards += values
  end

  def SSHRemoteForwards_remove(values)
    self.SSHRemoteForwards -= values
  end

  def SSHSessionSubsystems_add(values)
    self.SSHSessionSubsystems += values
  end

  def SSHSessionSubsystems_remove(values)
    self.SSHSessionSubsystems -= values
  end

  def TargetPasswordSource_human
    Profile.target_password_source_collection.select{|d,v| v == self.TargetPasswordSource}.first.first
  end

  def TargetHostKeyLearning_human
    Profile.hostkey_learning_collection.select{|d,v| v == self.TargetHostKeyLearning}.first.first
  end

  private

  #-- Custom validations

  def local_forwards_validation
    self.SSHLocalForwards.reject!(&:empty?)
    self.SSHLocalForwards.each_with_index do |fwd, i|
      errors.add(:SSHLocalForwards, 'one or more fields have invalid syntax') unless forward_valid?(fwd)
    end
  end

  def remote_forwards_validation
    self.SSHRemoteForwards.reject!(&:empty?)
    self.SSHRemoteForwards.each_with_index do |fwd, i|
      errors.add(:SSHRemoteForwards, 'one or more fields have invalid syntax') unless forward_valid?(fwd)
    end
  end

  def forward_valid?(fwd)
    return true if fwd.blank?
    address, port = Profile.split_ip_port(fwd)
    if ((address == '*') || (address =~ /^([a-z0-9\.-]+\.[a-z]|[a-z0-9-]+)+$/) || IPAddress(address) rescue nil)
      return true if port == '*'
      return true if (port.to_i > 0) && (port.to_i <= 65535)
    end
    false
  end

  def validate_TargetPreferredAuthentications
    if (self.TargetPreferredAuthentications.index('publickey-ssh-agent') || 100) < (self.TargetPreferredAuthentications.index('publickey') || -1)
      errors.add('TargetPreferredAuthentications', :invalid, message: "'Public Key - User SSH Auth Agent Forwarding' cannot be used before 'Public Key - Gateway (or Proxy Individual) Identities'.")
    end
  end

  def validate_MaxSessionIdleSeconds
    if self.MaxSessionSeconds.nil?
      unless self.MaxSessionIdleSeconds.nil?
        errors.add('MaxSessionIdleSeconds', :invalid, message: "can't be set to any value if Max Session Time is blank")
        return
      end
    else
      unless self.MaxSessionIdleSeconds.nil?
        if self.MaxSessionIdleSeconds >= self.MaxSessionSeconds
          errors.add('MaxSessionIdleSeconds', :invalid, message: "must be less than Max Session Time")
        end
      end
    end
  end

  #-- Callbacks

  def normalize_command_exec
    self.SSHCommandExecs.reject!(&:empty?)
  end

  def normalize_forwards
    self.SSHLocalForwards = self.SSHLocalForwards.reject{|fwd| fwd.blank?}.collect{|fwd| fwd.downcase}
    self.SSHRemoteForwards = self.SSHRemoteForwards.reject{|fwd| fwd.blank?}.collect{|fwd| fwd.downcase}
  end

  def normalize_session_subsystem
    self.SSHSessionSubsystems.reject!(&:empty?)
  end

  def normalize_TargetPreferredAuthentications
    return if self.TargetPreferredAuthentications.blank?

    if self.TargetPreferredAuthentications.first.blank?
      self.TargetPreferredAuthentications = []
    end

    remove_blanks_and_dups(self.TargetPreferredAuthentications)
  end

  def normalize_TargetUser
    # Set TargetUser to nil if an empty String is given
    self.TargetUser = nil if self.TargetUser.is_a?(String) && self.TargetUser.strip.empty?
  end

  def normalize_TargetPasswordSource
    case self.TargetPasswordSource
      when 'dialog', 'preserve'
        #self.TargetUser = nil
        self.TargetPassword = nil
        self.TargetPasswordCheckIdentity = false
        self.TargetPasswordLength = 32
        self.TargetPasswordValidSeconds = 5
      when 'static'
        self.TargetPasswordCheckIdentity = false
        self.TargetPasswordLength = 32
        self.TargetPasswordValidSeconds = 5
      when 'dotp'
        #self.TargetPassword = nil
    end
    self.TargetPasswordContinue = false if self.TargetPasswordSource == 'dialog'
  end

  def default_client_auth_set
    self.client_auth_set ||= ClientAuthSet.partition_default(self.partition_id) unless partition_id.blank?
  end

  def remove_blanks_and_dups(object)
    object.reject!(&:blank?)
    object.uniq!
    object.compact!
  end
end
