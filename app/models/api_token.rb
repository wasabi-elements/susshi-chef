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

class ApiToken < ApplicationRecord
  belongs_to :partition

  validates :application, presence: true
  validates :application, uniqueness: { case_sensitive: false, message: 'API token with same application name already exists' }

  class << self
    def permissions
      { 'source_ips' => 'Source IPs',
        'susshi_users' => 'Gateway Users & Keys',
        'target_users' => 'Target Users',
        'targets' => 'Targets, Target Fusions & Host Keys',
        'profiles' => 'Profiles',
        'accesses' => 'Accesses',
        'proxies' => 'Proxies & Proxy Bastions',
        'operations' => 'Perform Operations',
        'healths' => 'Request Health Information'
      }
    end

    def default_accesses
      { 'create' => false, 'read' => false, 'update' => false, 'destroy' => false }
    end


    def init_accesses
      { 'create' => false, 'read' => false, 'update' => false, 'destroy' => false }
    end

  end

  #-- Initializer
  after_initialize :initialize_permissions

  def initialize_permissions
    return unless self.new_record?
    ApiToken.permissions.each do |key, value|
      self.permissions[key] ||= ApiToken.init_accesses
    end
  end

  # methods are :read, :create, :update and :delete

  def has_permission?(klass, method = :read)
    permission(klass, method)
  end

  def permission(klass, method)
    self.permissions[klass.to_s][method.to_s] rescue false
  end

end
