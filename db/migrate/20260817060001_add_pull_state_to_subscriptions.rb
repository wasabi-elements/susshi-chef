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

class AddPullStateToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :subscriptions, :last_pull_at, :datetime
    add_column :subscriptions, :last_pull_state, :string
    add_column :subscriptions, :last_pull_message, :string

    # Set when the vendor withdrew the subscription. Deliberately separate from
    # last_pull_state: an unreachable service overwrites the state of the last
    # attempt, and a withdrawal must not evaporate with it.
    add_column :subscriptions, :withdrawn_at, :datetime
  end
end
