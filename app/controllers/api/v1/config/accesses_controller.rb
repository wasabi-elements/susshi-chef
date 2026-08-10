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

module Api::V1::Config
  class AccessesController < ApiController

    wrap_parameters :access, include: [:name, :description, :position, :position_after, :position_before, :active, :source_ip_members, :susshi_user_members, :target_user_members, :target_members, :target_fusion_members, :access_profile, :debug_level]

    def index_flat_csv
      begin

        require 'csv'

        unless (objs = find_objects).blank?
          all_objs    = ActiveModelSerializers::SerializableResource.new(objs).as_json
          all_columns = [:id, :name, :access_profile, :active, :description, :position, :source_ip_members, :susshi_user_members, :target_user_members, :target_members, :target_fusion_members, :valid]
        end

        unless all_objs.blank?
          filename = "accesses_flat.csv"
          col_sep = params['col_sep'] || ','

          csv_file = CSV.generate(headers: true, col_sep: col_sep) do |csv|
            csv << all_columns

            all_objs.each do |obj|
              valid = true
              csv << all_columns.collect do |column|
                if column == :valid
                  valid
                else
                  case obj[column].class.to_s
                    when 'Array'
                      if obj[column].size <= 1
                        obj[column].first
                      else
                        valid = false
                        '_MULTIPLE_'
                      end
                    else
                      obj[column]
                  end
                end
              end
            end
          end
          send_data csv_file, filename: filename, status: 200
        else
          respond_with_error_text(404)
        end
      rescue
        respond_with_error_text(500)
      end
    end

    private

    def sub_classes
      nil
    end

    def strong_params
      normalized_params.require(:access).permit(:name, :description, :position_after, :position_before, :active, :access_profile, :debug_level, source_ip_members: [], susshi_user_members: [], target_user_members: [], target_members: [], target_fusion_members: [] )
    end

    def strong_params_patch
      normalized_params.require(:access).permit(source_ip_members: [], susshi_user_members: [], target_user_members: [], target_members: [], target_fusion_members: [] )
    end

    def normalized_params
      _params = params
      case (pos = _params[:access].delete(:position))
        when nil, 'end', 'bottom'
          return _params
        when 'begin', 'top'
          pos = 1
      end
      _params[:access][:position_before] = pos
      _params
    end

    def rack_reducers
      super + [
          ->(active:) { where(active: active) },
          ->(description:) { where(api_query_search_string(:description, description)) },
          ->(source_ip_members_include:) { joins(:source_ips).where(api_query_search_string("source_ips.name", source_ip_members_include)) },
          ->(susshi_user_members_include:) { joins(:susshi_users).where(api_query_search_string("susshi_users.name", susshi_user_members_include)) },
          ->(target_user_members_include:) { joins(:target_users).where(api_query_search_string("target_users.name", target_user_members_include)) },
          ->(target_members_include:) { joins(:targets).where(api_query_search_string("targets.name", target_members_include)) },
          ->(target_fusion_members_include:) { joins(:target_fusions).where(api_query_search_string("target_fusions.name", target_fusion_members_include)) },
          ->(access_profile:) { access_profile == 'DENY' ? where(profile_id: nil) : joins(:profile).where(api_query_search_string("profiles.name", access_profile)) },
          ->(debug_level:) { where(debug_level: debug_level) }
      ]
    end

  end
end