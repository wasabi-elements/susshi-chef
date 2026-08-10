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

class PartitionKey < ApplicationRecord

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition
  belongs_to :proxy, optional: true

  #-- Scopes

  #-- Validations

  validates :title, presence: true
  validates :title, :uniqueness => { scope: [:partition_id, :proxy_id] }
  validates :key_type, presence: true
  validates :bits, presence: true

  #-- Class Methods

  class << self

    def types_collection
      [ ['Gateway Host Key', 'PartitionHostKey'], ['Gateway Authentication Key', 'PartitionAuthKey'], ['Proxy Authentication Key', 'ProxyAuthKey'] ]
    end

    def active_collection
      [ ['Active', true], ['Inactive', false] ]
    end

    def human_key_type(key_type)
      SshKey.ssh_key_type_collection.select{|title, key| key == key_type }.first.first
    end

    def skip_attributes_in_swift_log
      %w(title)
    end

  end

  #-- Instance Methods

  def human_type
    PartitionKey.types_collection.select{|title, key| key == self.type }.first.first
  end

  def human_key_type
    SshKey.ssh_key_type_collection.select{|title, key| key == self.key_type }&.first&.first || "Unknown"
  end

  def swift_config_hash
    { 'key_type'     => self.key_type, 'fingerprint' => self.fingerprint,
      'public_blob'  => "#{self.public_blob}\n",
      'private_blob' => self.private_blob }
  end

  def public_blob_base64
    self.public_blob.split(" ")[1]
  end

  #-- Helper

  def order_formatted
    '%04d' % self.order
  end

end
