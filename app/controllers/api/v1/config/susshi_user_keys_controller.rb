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
  class SusshiUserKeysController < ApiController

    # activate
    wrap_parameters :susshi_user_key, include: [:title, :public_blob, :username, :user_id, :activate]

    attr_accessor :username, :user_id

    before_action :extract_action_flags, only: [:create, :destroy, :update, :patch]
    before_action :extract_userinfo, only: [:create]
    after_action :activate, if: -> { @activate }, only: [:create, :destroy, :update, :patch]

    private

    def activate
      return unless @object.is_a? SusshiUserKey

      if Swift::Updater::SusshiUser.swift_update_keys(@object.susshi_user_login)
        @object.current_swift_change&.activate(
          whodunit: "API token #{@api_token.application}",
          change_trail: ["Activated with API application token '#{@api_token.application}'"]
        )
      end
    end

    def api_allowed?
      @api_token.has_permission?(:susshi_users)
    end

    def extract_action_flags
      @activate = params[:susshi_user_key]&.delete(:activate)
    end

    def extract_userinfo
      @username ||= params[:susshi_user_key].delete(:username)
      @user_id ||= params[:susshi_user_key].delete(:user_id)
    end

    def strong_params
      params.require(:susshi_user_key).permit(:title, :public_blob)
    end

    def new_object
      if @username and @user_id
        raise Errors::Api::ParametersAmbiguous
      end

      if [@username, @user_id].all?(&:blank?)
        raise Errors::Api::ParametersMissing
      else
        user = SusshiUserLogin.where(partition: @partition).where('id = ? OR name = ?', @user_id, @username).first
        object = SusshiUserKey.new(susshi_user_login: user)
        object.update(strong_params)
        object
      end
    end

    def find_objects(klass = model_class)
      if request.query_parameters.blank?
        SusshiUserKey.api_query_base.where(susshi_users: {partition_id: @partition.id})
      else
        Rack::Reducer.call(
          request.query_parameters,
          dataset: SusshiUserKey.api_query_base.where(susshi_users: { partition_id: @partition.id }),
          filters: rack_reducers
        )
      end
    end

   def find_single_object
     begin
       @object = SusshiUserKey.api_query_base.find_by(susshi_users: { partition_id: @partition.id }, id: @id)
     rescue
       raise Errors::Api::ObjectNotFound
     end
   end

    def rack_reducers
      super + [
          ->(title:) { where(api_query_search_string(:title, title)) },
          ->(fingerprint:) { where(api_query_search_string(:fingerprint, fingerprint)) },
          ->(public_blob:) { where(api_query_search_string(:public_blob, public_blob)) },
          ->(ssh_key_type:) { where(api_query_search_string(:key_type, ssh_key_type)) },
          ->(user_id:) { where(susshi_user_login_id: user_id) },
          ->(username:) { joins(:susshi_user_login).where(api_query_search_string("susshi_users.name", username)) }
      ]
    end

  end
end