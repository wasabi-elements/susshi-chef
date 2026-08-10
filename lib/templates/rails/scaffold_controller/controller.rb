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

<% if namespaced? -%>
require_dependency "<%= namespaced_path %>/application_controller"

<% end -%>
<% module_namespacing do -%>
class <%= controller_class_name %>Controller < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy]

  def index
    authorize :<%= singular_table_name %>, :index?

    @q = <%= class_name %>.ransack(params_query)
    ransack_default_sort(@q, :name, :asc)
    @<%= plural_table_name %> = @q.result.page(params_page).per(params_per_page)
  end

  def show
    @title = "Details of '#{@<%= singular_table_name %>.name}'"
  end

  def new
    authorize :<%= singular_table_name %>, :new?
    @<%= singular_table_name %> = <%= orm_class.build(class_name) %>
    @title = 'New <%= human_name %>'
  end

  def edit
    @title = "Edit '#{@<%= singular_table_name %>.name}'"
  end

  def create
    authorize :<%= singular_table_name %>, :create?
    @<%= singular_table_name %> = <%= orm_class.build(class_name, "#{singular_table_name}_params") %>

    if @<%= orm_instance.save %>
      redirect_to @<%= singular_table_name %>, flash: { success: <%= "'#{human_name} was successfully created.'" %> }
    else
      render :new
    end
  end

  def update
    if @<%= orm_instance.update("#{singular_table_name}_params") %>
      redirect_to @<%= singular_table_name %>, flash: { success: <%= "'#{human_name} was successfully updated.'" %> }
    else
      render :edit
    end
  end

  def destroy
    @<%= orm_instance.destroy %>
    redirect_to <%= index_helper %>_url, flash: { destroy: <%= "'#{human_name} was successfully destroyed.'" %> }
  end

  private

    def find_and_authorize(id = params[:id])
      @<%= singular_table_name %> = <%= class_name %>.readonly(false).find(id)
      authorize @<%= singular_table_name %>
    end

    def <%= "#{singular_table_name}_params" %>
      <%- if attributes_names.empty? -%>
      params.fetch(:<%= singular_table_name %>, {})
      <%- else -%>
      params.require(:<%= singular_table_name %>).permit(<%= attributes_names.map { |name| ":#{name}" }.join(', ') %>)
      <%- end -%>
    end

end


<% end -%>
