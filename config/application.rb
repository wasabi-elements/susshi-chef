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

require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Chef
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[generators tasks templates])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Custom Settings

    # suSSHi Chef does not use Active Storage attachments/variants, and the image_processing gem is not in the Gemfile.
    config.active_storage.variant_processor = :disabled

    # Active Record Session Store does not sign nor encrypt cookies by default, nor is there a config option to do so
    #
    # https://discuss.rubyonrails.org/t/session-ids-naming-footguns/86425/3
    # https://github.com/rails/activerecord-session_store/issues/48
    # https://github.com/rails/activerecord-session_store/pull/140
    #
    # However, we must set this value, otherwise the startup of the application will fail.
    config.secret_key_base = SecureRandom.hex(64)

    # ActiveRecord::Encryption Setup
    config.before_initialize do
      unless Rails.env.assets?
        require "chef/active_record/encryption"
        Chef::ActiveRecord::Encryption.setup
      end
    end
  end
end
