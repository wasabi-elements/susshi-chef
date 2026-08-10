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

module Chef
  #  This class variable may be set temporarily to true from some controllers
  class SwiftTracker
    class << self
      def skip?
        RequestStore.store[:chef_swift_tracker_skip].is_a?(TrueClass)
      end

      def skip=(value)
        RequestStore.store[:chef_swift_tracker_skip] = value
      end
      def with_skip
        self.skip = true
        yield
      ensure
        self.skip = false
      end
    end
  end
end
