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
  class TargetHostKeysController < ApiController

    wrap_parameters :target_host_key, include: [:title, :public_blob, :target, :target_id]

    before_action :extract_targetinfo, only: [:create]

    attr_accessor :target, :target_id

    private

    def api_allowed?
      super(:targets)
    end

    def extract_targetinfo
      @target ||= params[:target_host_key].delete(:target)
      @target_id ||= params[:target_host_key].delete(:target_id)
    end

    def strong_params
      params.require(:target_host_key).permit(:title, :public_blob)
    end

    def new_object
      if @target and @target_id
        raise Errors::Api::ParametersAmbiguous
      end

      unless @target.blank? && @target_id.blank?
        target = Target.query_target_by_ids_or_names('members', @partition.id, [@target_id.try(:to_i), @target]).where(type: %w(TargetHost TargetDynamic)).first
        raise Errors::Api::TargetNotFound if target.blank?
        object = TargetHostKey.new(target: target)
        object.update(strong_params)
        object
      else
        raise Errors::Api::ParametersMissing
      end
    end

    def find_objects(klass = model_class)
      unless request.query_parameters.blank?
        Rack::Reducer.call(request.query_parameters,
                           dataset: TargetHostKey.api_query_base.where(targets: { partition_id: @partition.id }),
                           filters: rack_reducers)
      else
        TargetHostKey.api_query_base.where(targets: { partition_id: @partition.id })
      end
    end

    def find_single_object
      begin
        @object = TargetHostKey.api_query_base.where(targets: {partition_id: @partition.id }, id: @id).limit(1).first
      rescue
        raise Errors::Api::ObjectNotFound
      end
    end

    def rack_reducers
      super + [
          ->(fingerprint:) { where(api_query_search_string(:fingerprint, fingerprint)) },
          ->(public_blob:) { where(api_query_search_string(:public_blob, public_blob)) },
          ->(ssh_key_type:) { where(api_query_search_string(:key_type, ssh_key_type)) },
          ->(target_id:) { where(target_id: target_id) },
          ->(target:) { joins(:target).where(api_query_search_string("targets.name", target)) }
      ]
    end

  end
end