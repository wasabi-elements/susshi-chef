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

class Subscription < ActiveRecord::Base

  encrypts :token, :subscription_key

  VENDOR   = "Wasabi Elements GmbH".freeze
  AUDIENCE = "suSSHi".freeze

  SUBSCRIPTION_FILE_PATHS = [
    "/run/secrets/subscription.token",
    "/subscription.token",
    Rails.root.join('config', 'subscription.token')
  ].freeze

  Claims = Data.define(:installation_id, :vendor, :audience, :company, :user,
                       :valid_not_before, :valid_not_after, :features, :users, :targets)

  #-- Validations
  validates :installation_id, presence: true
  validates :installation_id, format: {
    with: /\A([0-9a-f]{8}|[0-9a-f]{4,5})-[0-9a-f]{4,5}-[0-9a-f]{4,5}-[0-9a-f]{4,5}-([0-9a-f]{12}|[0-9a-f]{4,5})\z/i,
    message: "Installation ID is wrong"
  }
  validates :company, presence: true
  validates :features, presence: true
  validates :user, presence: true
  validates :valid_not_before, presence: true
  validates :valid_not_after, presence: true
  validates :audience, presence: true
  validates :audience, inclusion: { in: [AUDIENCE], message: "Wrong subscription audience" }
  validates :vendor, presence: true
  validates :vendor, inclusion: { in: [VENDOR], message: "Wrong subscription vendor" }
  validates :users, presence: true
  validates :users, numericality: {
    only_integer:             true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to:    9999999,
    message: "Number of Users must be between 0 and 999999"
  }
  validates :targets, presence: true
  validates :targets, numericality: {
    only_integer:             true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to:    9999999,
    message: "Number of Targets must be between 0 and 999999"
  }

  validate :validate_token
  validate :validate_installation_id
  validate :validate_period
  validate :map_error_messages_to_subscription_key

  #-- Class Methods
  class << self
    def instance
      sub = Subscription.first_or_initialize
      if sub.new_record? || sub.expired?
        # See if we have a subscription mapped into the container and load it
        sub.load
      end
      sub
    end

    def destroy
      destroy_all
    end

    def mount_hint
      "Please mount it as a Docker secret at /run/secrets/subscription.token or as a file at /subscription.token into the container."
    end
  end

  #-- Instance methods

  def load
    path = SUBSCRIPTION_FILE_PATHS.find { |p| File.exist?(p) }
    return ["No subscription.token found. #{Subscription.mount_hint}"] unless path

    self.token        = File.read(path).strip
    self.activated_at = Time.now
    self.save!
    return nil
  rescue => e
    self.token = nil
    self.activated_at = nil
    return [e.message]
  end

  # The verified claims of the subscription token, or nil if no token is
  # installed or its signature does not verify. Claims are only ever derived
  # from the signed token — never from mutable database state — and are
  # re-verified whenever the token value changes.
  def claims
    digest = token.blank? ? nil : Digest::SHA256.hexdigest(token)
    unless @claims_digest == digest && defined?(@claims)
      @claims_digest = digest
      @claims_error  = nil
      @claims        = digest ? verify_token : nil
    end
    @claims
  end

  #-- Attributes are always read from the verified claims
  def installation_id  = claims&.installation_id
  def vendor           = claims&.vendor
  def audience         = claims&.audience
  def company          = claims&.company
  def user             = claims&.user
  def valid_not_before = claims&.valid_not_before
  def valid_not_after  = claims&.valid_not_after
  def features         = claims&.features
  def users            = claims&.users
  def targets          = claims&.targets

  def installed?
    installation_id.present?
  end

  # Authoritative gate for every feature decision. All conditions are
  # re-evaluated from the signed claims on every call — there is no cached
  # boolean or database-backed state that could be flipped to enable features.
  def active?
    claims.present? &&
      claims.vendor == VENDOR &&
      claims.audience == AUDIENCE &&
      claims.installation_id == Preference.instance.installation_identifier &&
      Time.now.between?(claims.valid_not_before, claims.valid_not_after)
  end

  def expired?
    !valid? || valid_not_after < Time.now
  end

  def expires_in_days
    (((valid_not_after - Time.now) rescue 0) / 86400).round
  end

  def expires_soon?
    expires_in_days <= 30
  end

  def feature?(feature_name)
    defined?(EE::Engine) && active? && claims.features.include?(feature_name)
  end

  def feature_audit_log_encryption? = feature?('audit-log-encryption')
  def feature_dynamic_otp? = feature?('dynamic-otp')
  def feature_proxies? = feature?('susshi-proxy')
  def feature_target_fusions? = feature?('target-fusions')

  # Configured counts
  def configured_partitions
    Partition.count
  end

  def configured_gateways
    Gateway.count
  end

  def configured_proxies
    Proxy.count
  end

  def configured_users
    SusshiUserLogin.count
  end

  def configured_targets
    Target.where(type: %w[TargetDomain TargetDynamic TargetHost TargetNetwork]).count
  end

  private

  # Verification of the subscription token (the Ed25519 signature check and the
  # associated key material) is provided by the Enterprise Edition, which
  # overrides this method via EE::SubscriptionExtensions. Without the Enterprise
  # Edition installed no token can be verified, so #claims stays nil, the
  # subscription is never #active? and no features are enabled.
  def verify_token
    @claims_error = "Subscription verification requires the Enterprise Edition."
    nil
  end

  def validate_token
    if token.blank?
      errors.add(:token, "No subscription token installed")
    elsif claims.nil?
      errors.add(:token, @claims_error || "The subscription token is not valid")
    elsif claims.audience != AUDIENCE
      errors.add(:token, "The subscription token was not issued for suSSHi")
    end
  end

  def validate_installation_id
    return unless installation_id
    if installation_id != Preference.instance.installation_identifier
      errors.add(:installation_id, "The installation ID of the subscription does not match the installation")
    end
  end

  def validate_period
    return unless valid_not_before && valid_not_after
    if valid_not_before > Time.now
      errors.add(:valid_not_before, "Your Subscription is not valid before #{valid_not_before}")
    end
    if valid_not_after < Time.now
      errors.add(:valid_not_after, "Your Subscription is no longer valid. Expired at #{valid_not_after}")
    end
  end

  def map_error_messages_to_subscription_key
    return unless installation_id
    if errors.any?
      errors.add(:subscription_key, "We are sorry: #{errors.messages.values.flatten.join(", ")}")
    end
  end

end
