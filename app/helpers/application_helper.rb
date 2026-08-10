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

module ApplicationHelper

  COUNTER_BADGE_DEFAULTS = {
    color: "primary",
    color_zero: "warning",
    tooltip: true,
    type: :badge,
    zero_value: "None",
    zero_blank: false
  }.freeze

  def bootstrap_search_form_for(record, options = {}, &proc)
    options[:builder] ||= BootstrapForm::FormBuilder
    search_form_for(record, options, &proc)
  end

  def object_counter_badge(objects, **params)
    params = COUNTER_BADGE_DEFAULTS.merge(params.compact)
    params[:type] = :label if params[:type] == :pill

    size = objects.to_a.flatten.size
    params[:title] ||= object_counter_tooltip(objects) unless params[:tooltip] == false

    if size.zero?
      classes = params[:zero_blank] ? nil : [params[:type], "#{params[:type]}-#{params[:color_zero]}"]
      content_tag(:span, params[:zero_value], class: classes)
    else
      content_tag(:span, size, class: [params[:type], "#{params[:type]}-#{params[:color]}"], title: params[:title])
    end
  end

  def object_counter_tooltip(objects, scope: nil)
    flat = objects.to_a.flatten

    scope ||= begin
      names = flat.map(&:class).map(&:name).uniq
      names.first if names.one?
    end

    return pluralize(objects.size, scope.to_s).titleize unless objects.any?(Enumerable)
    return pluralize(flat.size, scope.to_s).titleize if objects.one?

    tooltip = []
    tooltip << "#{pluralize(objects.first.size, scope).titleize}" if objects.first.any?
    tooltip << "#{pluralize(objects.last.size, "group #{scope}").titleize}" if objects.last.any?
    tooltip.join(", ")
  end

  def flash_class(level)
    case level.to_sym
      when :notice then 'info'
      when :success then 'success'
      when :error then 'warning'
      when :alert then 'error'
      when :destroy then 'warning'
    end
  end

  def flash_toastr
    flash.collect do |level, text|
      unless(flash_class(level)).blank?
        "toastr[\"#{flash_class(level)}\"](\"#{text}\");"
      end
    end
  end

  def is_active_controller(controller_name, class_name = nil)
    if controller_name.class == Array
      if controller_name.include?(params[:controller])
        class_name == nil ? "active" : class_name
      else
        nil
      end
    else
      if params[:controller] == controller_name
       class_name == nil ? "active" : class_name
      else
         nil
      end
    end

  end

  def is_active_action(action_name)
    params[:action] == action_name ? "active" : nil
  end

  def is_active_controller_action(controller_name, action_name)
    if action_name.class == Array
      action_name.include?(params[:action]) ? is_active_controller(controller_name) : nil
    else
      params[:action] == action_name ? is_active_controller(controller_name) : nil
    end
  end

  def javascript_include_view_js
    [
      if FileTest.exist? "app/assets/javascripts/"+params[:controller]+"/"+params[:action]+".js"
        '<script src="/assets/'+params[:controller]+'/'+params[:action]+'.js" type="text/javascript"></script>'
      end,
      if FileTest.exist? "app/assets/javascripts/"+params[:controller]+".js"
        '<script src="/assets/'+params[:controller]+'.js" type="text/javascript"></script>'
      end
    ].join("\n")
  end

  def auto_title
    name = params[:controller].split("/").last.gsub("_", " ").titleize

    return if content_for?(:title)
    content_for :title do
      unless @title.blank?
        @title
      else
        case params[:action].to_s
          when "index"
            name.pluralize.gsub("Ip", "IP")
          else
            "#{params[:action].capitalize} #{name.singularize}"
        end
      end
    end
  end

  def count_not_null(value)
    (!value.nil? and value > 0) ? value : '-'
  end

  def current_controller_is?(a = nil)
    [a].flatten.include?(@_controller.controller_name.classify.to_s)
  end

  def value_not_blank(value)
    value.blank? ? '-' : value
  end

  def show_flash
    [:notice, :warning, :message, :alert].collect do |key|
      content_tag(:div, flash[key], :class => "flash flash_#{key}") unless flash[key].blank?
    end.join
  end
  
  def sortable(column, title = nil)
    title ||= column.titleize
    css_class = "sortable#{ column == sort_column? ? " sorted-#{sort_direction?}" : nil}"
    direction = column == sort_column? && sort_direction? == "asc" ? "desc" : "asc"
    link_to title, {:sort => column, :direction => direction}, :class => css_class, :remote => true
  end


  def row_key_value_block(key, options = {}, &block)
    key[0]=key[0].capitalize unless key.blank?
    key="#{key}:" unless key.blank?

    content_tag(:tr) do
      concat(
        content_tag(:td, class: 'col-sm-3 text-right') do
          if options[:wrap_key]
            concat(
              content_tag(options[:wrap_key]) do
                concat("#{key}")
              end
            )
          else
            concat("#{key} ")
          end

          concat(
            content_tag(:td, class: 'col-sm-icon text-center border-left') do
              if options[:icon]
                fa = (options[:icon].include?('fas') or options[:icon].include?('far')) ? '':'fa'
                content_tag(:i, nil, class: "#{fa} #{options[:icon]}")
              end
            end
          )
        end
      )

      concat(
        content_tag(:td, class: 'col-sm-9') do
          if options[:wrap_value]
            concat(
              content_tag(options[:wrap_value]) do
                yield
              end
            )
          else
            yield
          end
        end
      )
    end
  end

  def row_key_value(key, value, options = {})
    row_key_value_block(key, options) do
      concat(value)
    end
  end

  def row_key_values(key, values, options = {})
    row_key_value_block(key, options) do
      concat(
        content_tag(:ul, class: 'values') do
          values.each do |value|
            concat content_tag(:li, value)
          end
        end
      )
    end
  end

  def index_action_buttons(object, options = {})
    options.reverse_merge! show: true, clone: false, edit: true, destroy: true, remote: false, data: nil
    klass = 'btn btn-xs btn-white'
    links = Array.new

    # Show
    disabled, title = case options[:show]
                        when FalseClass
                          [true, 'Show is not allowed.']
                        when TrueClass
                          [false, "Show #{object.class.to_s.underscore.titleize} details"]
                        else
                          [false, "Show #{object.class.to_s.underscore.titleize} details"]
                      end
    if disabled
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-search')),
                       '#', class: klass, disabled: true, title: title)
    else
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-search')),
                       polymorphic_path(object), class: klass, remote: options[:remote],
                       data: options[:data], title: title) if options[:show]
    end

    # Edit
    disabled, title = case options[:edit]
                        when FalseClass
                          [true, 'Edit is not allowed.']
                        when TrueClass
                          [false, "Edit #{object.class.to_s.underscore.titleize}"]
                        else
                          [false, "Edit #{object.class.to_s.underscore.titleize}"]
                      end

    if disabled
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-edit')),
                       '#', class: klass, disabled: true, title: title)
    else
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-edit')),
                       polymorphic_path(object, { action: 'edit' }), class: klass, remote: options[:remote],
                       data: options[:data], title: title) if options[:edit]
    end

    # Destroy
    disabled, title = case options[:destroy]
                        when FalseClass
                          [true, 'Deletion is not allowed.']
                        when TrueClass
                          [false, "Delete #{object.class.to_s.underscore.titleize}"]
                        when Hash
                          unless options[:destroy][:false].blank?
                            [true, options[:destroy][:false]]
                          else
                            unless options[:destroy][:true].blank?
                              [false, options[:destroy][:true]]
                            end
                          end
                        else
                          [false, "Delete #{object.class.to_s.underscore.titleize}"]
                      end

    if disabled
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-trash')),
                       '#', class: klass, disabled: true, title: title)
    else
      links << link_to(raw(content_tag(:i, nil, class: 'fa fa-trash')),
                       object, class: klass, method: :delete, remote: options[:remote],
                       data: options[:data] || { title: title, confirm: 'Are you sure?', commit: 'Sure!'},
                       title: title)
    end

    links.join.html_safe
  end

  def show_action_buttons(object, options = {})
    options.reverse_merge! show: true, clone: false, edit: true, destroy: true, remote: false, data: nil
    klass = 'btn btn-xs btn-white'
    links = Array.new

    # Edit
    disabled, title = case options[:edit]
                      when FalseClass
                        [true, 'Edit is not allowed']
                      else
                        [false, 'Edit']
                      end
    if disabled
      links << content_tag(:span, class: 'btn btn-default m-t') do
        [ raw(content_tag(:i, nil, class: 'fas fa-ban')),
          "#{title}" ].join('&nbsp; &nbsp;').html_safe
      end
    else
      links << link_to(polymorphic_path(object, { action: 'edit' })) do
        content_tag(:span, class: 'btn btn-primary m-t') do
          title
        end
      end
    end

    # Destroy
    disabled, title = case options[:destroy]
                      when FalseClass
                        [true, 'Deletion is not allowed.']
                      when TrueClass
                        [false, 'Delete']
                      when Hash
                        unless options[:destroy][:false].blank?
                          [true, options[:destroy][:false]]
                        else
                          unless options[:destroy][:true].blank?
                            [false, options[:destroy][:true]]
                          end
                        end
                      else
                        [false, "Delete #{object.class.to_s.underscore.titleize}"]
                      end

    if disabled
      links << content_tag(:span, class: 'btn btn-default m-t') do
        [ raw(content_tag(:i, nil, class: 'fas fa-ban')),
          "#{title}" ].join('&nbsp; &nbsp;').html_safe
      end
    else
      links << link_to(object, method: :delete, remote: options[:remote],
                       data: options[:data] || { title: title, confirm: 'Are you sure?', commit: 'Sure!' }) do
        content_tag(:span, class: 'btn btn-warning m-t') do
          [ raw(content_tag(:i, nil, class: 'fas fa-trash')),
            'Delete' ].join('&nbsp; &nbsp;').html_safe
        end
      end
    end

    raw(content_tag(:div, class: 'row') do
      [content_tag(:div, class: 'col-sm-3') {},
       content_tag(:div, class: 'col-sm-9') do
         links.join('&nbsp; &nbsp;').html_safe
       end].join.html_safe
    end)
  end

  def searchform_action_buttons
    [ content_tag(:td, image_tag("reload.gif", :id => "load_indicator", :class => "load_indicator", :hidden => true), :width => "25px"),
      content_tag(:td, image_submit_tag("search.png"), :title => 'Search', :width => "25px"),
      content_tag(:td, image_submit_tag("erase.png", :title => 'Clear Search Form', :class => "button_clear_search_form"), :width => "25px")
    ].join.html_safe
  end

  def panel(title = nil, options = {}, &block)
    title ||= auto_title
    content_for(:title, title)

    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-12') do
        content_tag(:div, class: 'ibox float-e-margins') do
          if title
            content_tag(:div, class: 'ibox-title') do
              content_tag(:h5) do
                concat(title)

                if (options[:subtitle])
                  content_tag(:small, options[:subtitle])
                end
              end
            end
          end

          concat(
            content_tag(:div, class: 'ibox-content m-b-sm border-bottom') do
              yield
            end
          )
        end
      end
    end
  end

  def list_panel(label, objects, query, options = {})
    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-12') do
        content_tag(:div, class: 'ibox float-e-margins') do
          content_tag(:div, class: 'ibox-content m-b-sm border-bottom') do
            concat(render( partial: 'shared/list_head', :locals => { objects: objects }))

            concat(
              content_tag(:table, class: 'table table-striped toggle-arrow-tiny tablet breakpoint') do
                concat(
                  content_tag(:thead, id: "#{label.to_s.pluralize}-thead") do
                    concat(render partial: options[:thead_partial] || 'thead', locals: { query: query})
                  end
                )

                concat(
                  content_tag(:tbody, id: "#{label.to_s.pluralize}-tbody") do
                    concat(render partial: options[:body_partial] || label.to_s.singularize, :collection => objects)
                  end
                )
              end
            )

            concat(render( partial: 'shared/list_foot', :locals => { objects: objects }))
          end
        end
      end
    end
  end

  def attributes_panel(title = nil, options = {}, &block)
    title ||= auto_title

    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-12') do
        content_tag(:div, class: 'ibox float-e-margins') do
          if title
            concat(
              content_tag(:div, class: 'ibox-title') do
                content_tag(:h5) do
                  concat(title)

                  if (options[:subtitle])
                    concat content_tag(:small, options[:subtitle])
                  end
                end
              end
            )
          end

          concat(
            content_tag(:div, class: 'ibox-content m-b-sm border-bottom') do
              attributes_table(&block)
            end
          )
        end
      end
    end
  end

  def attributes_table(&block)
    content_tag(:table, class: 'table') do
      concat(
        content_tag(:thead) do
          content_tag(:tr) do
            concat content_tag(:th, 'Field', class: 'col-sm-3 text-right')
            concat content_tag(:th, '', class: 'col-sm-icon border-left')
            concat content_tag(:th, 'Value', class: 'col-sm-9')
          end
        end
      )

      concat(
        content_tag(:tbody) do
          yield
        end
      )
    end

  end

  def list_panel_update_js(label, objects, query, options = {})
    concat((
        "$('##{label.to_s.pluralize}-thead').html('#{escape_javascript render(partial: options[:thead_partial] || 'thead', locals: { query: query})}');" +
        "$('##{label.to_s.pluralize}-tbody').html('#{escape_javascript render(partial: options[:body_partial] || label.to_s.singularize, :collection => objects)}');" +
        "$('.paginator_pager').html('#{escape_javascript(paginate(objects, :remote => true, views_prefix: 'layouts').to_s)}');" +
        "$('#paginator_info').html('#{escape_javascript((page_entries_info objects).to_s)}');"
    ).html_safe)
  end

  def number_not_null(value, null_sign = '-')
    value != 0 ? value : null_sign
  end

  def my_truncate(text, params = {})
    params.reverse_merge! :length => 50, :omission => " ... (cont.)", :separator => ' '
    truncate(text, params)
  end

  def sortable_link(query, column, title = nil)
    title ||= column.to_s.titleize
    css_class = "sortable"
    query.blank? ? title : (sort_link query, column, title, {:remote => true})
  end

  def boolean_value(value, titles: %w(On Off))
    if value.class == String
      content_tag(:i, nil, class: value == 'true' ? 'fa fa-check text-success' : 'far fa-circle', title: titles[value == 'true' ? 0 : 1])
    else
      content_tag(:i, nil, class: value ? 'fa fa-check text-success' : 'far fa-circle', title: titles[value ? 0 : 1])
    end
  end

  def modal(title, &block)
    content_tag(:div, class: 'modal-dialog') do
      content_tag(:div, class: 'modal-content') do
        [content_tag(:div, class: 'modal-header') do
          [ content_tag(:button,'x', class: 'close', data: { dismiss: 'modal' }, aria: { hidden: "true" }),
            content_tag(:h3, title) ].join.html_safe
        end,
        content_tag(:div, class: 'modal-body') do
          yield
        end
        ].join.html_safe
      end
    end

  end

  def add_fields_link_helper(form, association, title)
    link = content_tag(:div, class: 'form-group text optional') do
      content_tag(:div, class: 'col-sm-10 col-sm-offset-2 margin-bottom-sm') do
        content_tag(:p, class: 'help-block') do
          content_tag(:span, class: 'btn btn-primary btn-xs') do
            [content_tag(:i, nil, class: 'fa fa-plus'),
            content_tag(:span, " #{title}")].join.html_safe
          end
        end
      end
    end
    form.add_fields_link(association, link)
  end

  def remove_fields_link_helper(form, title)
    link = content_tag(:div, class: 'form-group text optional') do
      content_tag(:div, class: 'col-sm-10 col-sm-offset-2') do
        content_tag(:p, class: 'help-block') do
          content_tag(:span, class: 'btn btn-warning btn-xs') do
            [content_tag(:i, nil, class: 'fa fa-minus-circle'),
             content_tag(:span, " #{title}")].join.html_safe
          end
        end
      end
    end
    form.remove_fields_link(link)
  end

  def message_box(header, type: :info, icon: :info, &block)
    content_tag(:div, class: 'row') do
      content_tag(:div, class: 'col-md-12') do
        content_tag(:div, class: "alert alert-#{type}") do
          unless header.nil?
            content_tag(:h3, {style: 'font-size: large;'})do
              concat content_tag(:i, nil, class: "fa fa-#{icon}")
              concat header
            end
          end

          if block
            concat content_tag :hr unless header.nil?
            concat(
              content_tag(:p) do
                yield block
              end
            )
          end
        end
      end
    end
  end

  def message_panel(header, type: :info, icon: :info, &block)
    content_tag(:div, class: "panel panel-#{type}") do
      concat(
        content_tag(:div, class: 'panel-heading') do
          concat content_tag(:i, nil, class: "fa fa-#{icon}")
          concat content_tag(:span, header, style: "padding-left: 4px;")
        end
      )

      concat(
        content_tag(:div, class: 'panel-body') do
          content_tag(:p) do
            yield block
          end
        end
      )
    end
  end

  def render_partial_if_exists(partial, **options)
    return unless partial_exists?(partial)
    render(partial: partial, **options)
  end

  def partial_exists?(partial)
    lookup_context.exists?(partial, [], true)
  end

  def main_app
    Rails.application.routes.url_helpers
  end

end
