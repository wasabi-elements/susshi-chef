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

class TargetHostKey < SshKey

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :target, optional: true
  belongs_to :target_host, foreign_key: 'target_id', class_name: 'TargetHost', optional: true
  belongs_to :target_dynamic, foreign_key: 'target_id', class_name: 'TargetDynamic', optional: true
  belongs_to :target_domain_host, foreign_key: 'target_id', class_name: 'TargetDomainHost', optional: true
  belongs_to :target_network_host, foreign_key: 'target_id', class_name: 'TargetNetworkHost', optional: true
  belongs_to :susshi_user_login, optional: true

  # Delegations used for SwiftChangeTracker
  alias_attribute :name, :key_type

  #-- Scopes

  #-- Validations
  validates :public_blob, uniqueness: { case_sensitive: false, scope: [:target_id, :susshi_user_login_id], message: 'same host key already exists for this target' }

  #-- Callbacks
  before_destroy :before_destroy_remove_keys_from_swift
  after_destroy :after_destroy_remove_orphan_target_domain_hosts

  #-- Class Methods

  class << self

    def api_query_base
      self.includes([:target]).joins(:target).order('target_host_keys.id ASC')
    end

  end

  #-- Instance Methods

  # Delegations used for SwiftChangeTracker
  def partition
    return target_host.partition if target_host
    return target_dynamic.partition if target_dynamic
    return susshi_user_login.partition if susshi_user_login
  end

  def proxy_realm
    proxy.try(:realm)
  end

  private

  def before_destroy_remove_keys_from_swift
    case self.target.type
      when 'TargetDomainHost'
        SwiftDomainHost.remove_user_key(self.target_id, self.susshi_user_login, self.target.proxy_realm)
      when 'TargetNetworkHost'
        SwiftNetworkHost.remove_user_key(self.target_id, self.susshi_user_login, self.target.proxy_realm)
      else
        SwiftTarget.remove_user_key(self.target_id, self.susshi_user_login, self.target.proxy_realm)
    end
  end

  def after_destroy_remove_orphan_target_domain_hosts
    if self.target_domain_host
      self.target_domain_host.destroy_if_orphan
    end
    if self.target_network_host
      self.target_network_host.destroy_if_orphan
    end
  end

end
