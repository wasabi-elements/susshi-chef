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

require 'rails/generators/erb/scaffold/scaffold_generator'

module Haml
  module Generators
    class ScaffoldGenerator < Erb::Generators::ScaffoldGenerator
      source_root File.expand_path("../templates", __FILE__)

      def copy_view_files
        [:html, :js].each do |format|
          available_views.each do |view|
            filename = filename_with_extensions(view == '_model' ? "_#{singular_table_name}" : view, format)
            template "#{view}.#{format}.haml", File.join("app/views", controller_file_path, filename) rescue nil
          end
        end
      end

      hook_for :form_builder, :as => :scaffold

    protected

      def available_views
        %w(index edit show new _thead _model _form)
      end

      def handler
        :haml
      end

    end
  end
end
