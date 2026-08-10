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

class Swift::Updater

  #-- Class methods
  class << self

    def klasses
      %w(Access Partition Profile Proxy Source SusshiUser TargetFusion Target TargetDomainHost TargetNetworkHost TargetUser TargetUserRegex TargetUserMapping Gateway Bastion BastionProfile ClientAuthSet)
    end

    def updaters
      klasses.collect { |klass| "Swift::Updater::#{klass}" }
    end

    def truncaters
      klasses.collect { |klass| "Swift#{klass}" }
    end

    #
    # Call this method to run all "child" updaters
    #
    def swift_update_all(partition_id)
      updaters.each do |klass|
        klass.constantize.swift_update(partition_id)
      end

      true
    end

    #
    # Call this method to truncate all data for specified partition
    #
    def swift_truncate_all(partition_id = nil)
      if partition_id
        truncaters.each do |klass|
          klass.constantize.where(partition_id: partition_id).delete_all
        end
      else
        truncaters.each do |klass|
          klass.constantize.delete_all
        end
      end
      true
    end
  end

end

