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

# Load the Rails application.
require_relative "application"

# Load environment vars from local file
env_vars = File.join(Rails.root.to_s, "config", "env_vars.rb")
load(env_vars) if File.exist?(env_vars)

# Initialize the Rails application.
Rails.application.initialize!

# Update Devise settings from Application Preferences
Preference.update_devise_settings!
