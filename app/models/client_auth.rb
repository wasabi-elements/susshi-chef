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

class ClientAuth < ApplicationRecord

  include SwiftChangeTracker

  store_accessor :properties, :kbd_int_auth_title, :kbd_int_auth_instruction, :kbd_int_auth_prompt

  # Collect all store accessor properties from the subclasses
  Rails.application.config.after_initialize do
    unless descendants.any?
      # Load client auth types to make them available through "descendants", environments w/o eager loading
      Dir.glob(Rails.root.join("app", "models", "client_auth", "**/*"))
         .each { |f| require_dependency f if File.file? f }
    end

    descendants.each do |client_auth|
      if client_auth.const_defined? "PROPERTIES"
        properties = client_auth.const_get "PROPERTIES"

        keys = if properties.is_a? Hash
                 properties.keys
               elsif properties.is_a? Array
                 properties
               end

        store_accessor :properties, *keys unless keys.nil?
      end
    end
  end

  #-- Associations

  belongs_to :client_auth_set, optional: true

  # Used for SwiftChangeTracker

  delegate :partition, to: :client_auth_set
  delegate :name, to: :client_auth_set

  #-- Class methods

  class << self
    def icon
      'fa-question-circle'
    end

    def publickey_types
      descendants.select { |x| x.category == 'publickey' && x.type_available? }
    end

    def publickey_types_collection
      publickey_types.map { |x| x.type_for_collection }
    end

    def interactive_types
      descendants.select { |x| x.category == 'interactive' && x.type_available? }
    end

    def interactive_types_collection
      interactive_types.map { |x| x.type_for_collection }
    end

    def category
      'invalid'
    end

    def operational?(properties = {})
      true
    end

    def partial_name
      name.split(/::/).map(&:underscore).join('_')
    end

    def type_available?
      true
    end

    def type_for_collection
      'invalid'
    end

    def valid_user_input?(swift_susshi_user:, user_input:, properties: {})
      false
    end
  end

  #-- Validations

  validates :category, uniqueness: { case_sensitive: false, scope: :client_auth_set_id, message: 'another client auth method with same category already exists' }

  #-- Initializer

  after_initialize :initialize_category

  def initialize_category
    self.category ||= self.class.category
  end

  #-- Callbacks

  #-- Instance methods

  # This allows overriding in inherited classes like OpenidConnect
  def required_auth
    self.category
  end

  def properties_with_defaults
    props = self.properties
    if self.class.const_defined? "PROPERTIES"
      properties_def = self.class.const_get "PROPERTIES"
      properties_def.each do |key, values|
        if props[key.to_s].blank? and values[:placeholder]
          props[key] = values[:placeholder]
        end
      end
    end
    props
  end

  def human_type
    (ClientAuth.interactive_types_collection + ClientAuth.publickey_types_collection).find { |_, y| y == self.type }&.first
  end

  def icon
    self.class.icon
  end

  def preferred_authentications
    case self.class.category
    when 'interactive'
      %w[keyboard-interactive password]
    when 'publickey'
      %w[publickey]
    else
      []
    end
  end

end
