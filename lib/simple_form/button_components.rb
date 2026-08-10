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

module SimpleForm
  module ButtonComponents

    def submit_cancel(*args, &block)
      options = args.extract_options!
      options[:class] = [options[:class], 'btn-primary'].compact
      col = options.delete(:col) || 2
      args << options

      # simplify button text, if no value is explicitly given
      if args.first.is_a?(Hash)
        object = convert_to_model(@object)
        args.unshift(object ? (object.persisted? ? 'Update' : 'Create') : 'Submit')
      end

      template.content_tag :div, :class => "form-group" do
        template.content_tag :div, :class => "col-sm-offset-#{col} col-sm-#{12-col}" do

          # with cancel link
          if cancel = options.delete(:cancel)
            submit(*args, &block) + '&nbsp;&nbsp;'.html_safe + template.link_to(I18n.t('simple_form.buttons.cancel'), cancel, class: 'btn btn-default')
          else
            submit(*args, &block)
          end

        end
      end
    end

    def input_dual(*args, &block)
      options = args.extract_options!
      options[:input_html] ||= { class: 'dual_select', multiple: true }
      options[:input_html].reverse_merge!({ multiple: true })
      args << options
      input(*args, &block)
    end

    def input_with_icon(*args, &block)
      options = args.extract_options!
      if (icon = options.delete(:icon))
        options[:icon_html] = { class: "fa #{icon}"}
        options[:wrapper] = :horizontal_input_group
      end
      args << options
      input(*args, &block)
    end

    def input_with_overwrite(*args, &block)
      options = args.extract_options!
      options[:wrapper] = :horizontal_input_group_overwrite

      args << options
      input_with_icon(*args, &block)
    end

    def input_array
      input_html_options[:type] ||= input_type

      existing_values = Array(object.public_send(attribute_name)).map do |array_el|
        @builder.text_field(nil, input_html_options.merge(value: array_el, name: "#{object_name}[#{attribute_name}][]", class: 'form-control'))
      end

      existing_values.push @builder.text_field(nil, input_html_options.merge(value: nil, name: "#{object_name}[#{attribute_name}][]", class: 'form-control'))
      existing_values.join.html_safe
    end
  end
end

SimpleForm::FormBuilder.send :include, SimpleForm::ButtonComponents