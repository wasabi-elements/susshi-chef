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

class ArrayInput < SimpleForm::Inputs::StringInput

  attr_accessor :output_buffer

  def input(wrapper_options)
    input_html_options[:type] ||= input_type
    max = input_html_options.delete(:max) || 1000

    count = 0
    existing_values = Array(object.public_send(attribute_name)).collect do |array_el|
      count+=1
      @builder.text_field(nil, input_html_options.merge(value: array_el, name: "#{object_name}[#{attribute_name}][]",
                                                        data: { max: max }, class: 'form-control margin-bottom-sm',
                                                        id: "#{object_name}_#{attribute_name.to_s.underscore}_#{count}"))
    end

    min = input_html_options.delete(:min) || count


    plus = min > count ? min - count : 0
    plus = 0 if (count + plus) > max

    for i in (1..plus) do
      count+=1
      existing_values.push @builder.text_field(nil, input_html_options.merge(value: nil, name: "#{object_name}[#{attribute_name}][]",
                                                                             data: { max: max }, class: "form-control margin-bottom-sm",
                                                                             id: "#{object_name}_#{attribute_name.to_s.underscore}_#{count}"))
    end

    if count < max
      plus_button = content_tag(:a, href: '#', class: "btn btn-primary btn-xs add-fields") do
        content_tag(:i, nil, class: 'fa fa-plus') +
            content_tag(:span, raw("&nbsp;&nbsp;Add #{label_text.singularize}"))
      end

      options[:hint] = [ options[:hint], plus_button ].compact.join('<br/><br/>').html_safe
    end

    existing_values.join.html_safe
  end

  def input_type
    :text
  end

  def label_html_options
    super.merge(for: "#{@builder.object_name}_#{attribute_name}_1i")
  end
end
