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

class SusshiUser < ApplicationRecord
  encrypts :properties

  include SwiftChangeTracker

  #-- Datatypes

  #-- Associations
  belongs_to :partition

  has_many :accesses_susshi_users, dependent: :destroy
  has_many :accesses, -> { distinct }, through: :accesses_susshi_users

  has_many :bastions_susshi_users, dependent: :destroy
  has_many :bastions, -> { distinct }, through: :bastions_susshi_users

  #-- Scopes

  #-- Validations


  #-- Class Methods

  class << self

    def active_collection
      [ ['Active', true], ['Inactive', false] ]
    end

    def shell_login_collection
      [ ['allowed', true], ['not allowed', false] ]
    end

    def types_collection
      [ ['Gateway Users', 'SusshiUserLogin'], ['Gateway Groups', 'SusshiUserGroup'] ]
    end

    def password_collection
      [ ['set', true], ['not set', false] ]
    end

    def last_use_at_collection
      [ ['Last 24 hours', Time.now - 24.hours], ['Last 7 days', Date.today - 7.days ], ['Last 30 days', Date.today - 30.days ],
        ['Last 3 months', Date.today - 3.months ], ['Last 6 months', Date.today - 6.months ], ['Never', 'never' ] ]
    end

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      SusshiUser.where(partition: User.current_user.partition).count
    end

    def duallist_collection(partition_id)
      SusshiUser.where(partition_id: partition_id).order("type ASC, LOWER(name) ASC").all.pluck(:name, :fullname, :id, :type)
          .collect{|t| ["#{t.first} (#{t.last == 'SusshiUserLogin' ? t.second : 'Group'})", t.third]}
    end

  end

  #-- Instance Methods

  def icon
    'fa-exclamation'
  end

  def is_destroyable?
    return {false: 'Is assigned to an Access Rule'} if accesses.any?
    return {false: 'Is assigned to an Bastion Rule'} if bastions.any?
    { true: "Delete Gateway User '#{self.name}'" }
  end

  def title
    self.class.name.demodulize.titleize rescue "Susshi User Base"
  end

end
