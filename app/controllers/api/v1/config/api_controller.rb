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
  class ApiController < ApiApplicationController

    WRITE_ACTIONS = %w[create update patch destroy].freeze

    respond_to :json, :csv

    before_action :initialize_api_controller
    before_action :find_single_object, only: [:show, :patch, :update, :destroy]

    attr_accessor :api_token, :id, :identity, :partition, :object, :operation, :sub_class

    #-- Exception handling
    rescue_from ActionController::UnpermittedParameters, with: :rescue_from_exception
    rescue_from ActiveRecord::RecordInvalid, with: :rescue_from_exception

    ActionController::Parameters.action_on_unpermitted_parameters = :raise

    #
    # Generic Methods used by inherited controller classes
    #

    #
    # get /<model>
    # get /<model>/<sub_class>
    #
    def index
      respond_to do |format|

        # Regular JSON output
        format.json do
          respond_to_get do
            if @sub_class
              find_objects
            else
              if sub_classes
                sub_classes.to_h do |sub_class|
                  [
                    sub_class,
                    ActiveModelSerializers::SerializableResource.new(find_objects(model_class(sub_class)), api_token: @api_token)
                  ]
                end
              else
                find_objects
              end
            end
          end
        end

        # CSV output
        format.csv do
          index_csv
        end
      end
    end

    def index_csv
      begin

        require 'csv'

        all_objs    = []
        all_columns = [:sub_class]

        if sub_classes

          # Model has sub_classes
          if @sub_class
            unless (objs = find_objects).blank?
              all_objs    = ActiveModelSerializers::SerializableResource.new(objs).as_json
              all_columns += all_objs.first.keys
              all_objs.each { |obj| obj[:sub_class] = @sub_class.singularize }
            end
          else
            sub_classes.each do |sub_class|
              unless (objs = find_objects(model_class(sub_class))).blank?
                objs_json = ActiveModelSerializers::SerializableResource.new(objs).as_json
                objs_json.each { |obj| obj[:sub_class] = sub_class.singularize }
                all_objs    += objs_json
                all_columns += objs_json.first.keys
              end
            end
            all_columns.uniq!
          end

        else

          # Model has no sub_classes
          unless (objs = find_objects).blank?
            all_objs    = ActiveModelSerializers::SerializableResource.new(objs).as_json
            all_columns = all_objs.first.keys
          end

        end

        unless all_objs.blank?
          filename = @sub_class ? "#{controller_name.classify.downcase}_#{@sub_class}.csv" : "#{controller_name.classify.pluralize.downcase}.csv"
          all_columns.sort_by! { |a| %w(id sub_class name username fullname).index(a.to_s) || a.to_s[0].ord }
          col_sep = params['col_sep'] || ','

          csv_file = CSV.generate(headers: true, col_sep: col_sep) do |csv|
            csv << all_columns

            all_objs.each do |obj|
              csv << all_columns.collect { |column| obj[column] }
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

    #
    # get /<model>/<sub_class>/:id|:identity
    #
    def show
      respond_to_get(single: true) do
        @object
      end
    end

    #
    # post /<model>/<sub_class>/
    #
    # { "<attribute>": "<value>", ... }
    #
    def create
      respond_to_post do
        @object = new_object
        @object.save!

        @object.reload
      end
    end

    #
    # put /<model>/<sub_class>/:id|:identity
    #
    # { "<attribute>": "<value>", ... }
    #
    def update
      respond_to_put do
        raise Errors::Api::SystemInternalObject if @object.try(:system_int)

        @object.class.transaction do
          @object.assign_attributes(strong_params)
          @object.save!
        end

        @object.reload
      end
    end

    #
    # patch /<model>/<sub_class>/:id|:identity/add
    # patch /<model>/<sub_class>/:id|:identity/remove
    #
    # { "<attribute>": "<value>" }
    #
    def patch
      respond_to_put do
        @object.transaction do
          strong_params_patch.each do |key, value|
            case @operation
              when 'add'
                if value.class == Array
                  @object.send("#{key}_add", value)
                end
              when 'remove'
                if value.class == Array
                  @object.send("#{key}_remove", value)
                end
            end
          end
          @object.save!
        end

        @object.reload
      end
    end

    #
    # delete /<model>/<sub_class>/:id|:identity
    #
    def destroy
      begin
        raise Errors::Api::SystemInternalObject if @object.try(:system_int)
        @object.destroy
        if @object.errors.any?
          errors = @object.errors.collect { |e| { field: e.attribute.to_s.gsub('_ids','_members').gsub('_id',''), message: e.message } }
          respond_to do |format|
            format.json { render json: { errors: errors }, status: 406 }
            format.csv { head code }
          end
        else
          respond_with_success(nil)
        end
      rescue Errors::Api::SystemInternalObject
        respond_with_error_text(404, 'Internal objects cannot be deleted.')
      rescue ActiveRecord::RecordInvalid => e
        respond_with_validation_error(e)
      rescue Exception
        respond_with_error_text(404)
      end
    end


    private

    def initialize_api_controller
      if valid_api_token?
        if !api_allowed?
          respond_with_error_text( :unauthorized, 'API token is not authorized to access this config.')
        elsif !ee_write_allowed?
          respond_with_error_text( :forbidden, 'This resource requires an active subscription.')
        else
          @sub_class = params.delete(:sub_class)  # Sub Class if any
          @id = params.delete(:id)                # Object ID
          @identity = params.delete(:identity)    # Search for name
          @operation = params.delete(:operation)  # PATCH operation
        end
      else
        response.headers['WWW-Authenticate'] = 'Basic realm="suSSHi Chef Configuration API"'
        respond_with_error_text( :unauthorized, 'Authentication failed.')
      end
    end

    def api_allowed?(controller_name = self.controller_name)
      case action_name.to_s
        when 'index', 'index_csv', 'index_flat_csv', 'show'
          @api_token.has_permission?(controller_name, :read)
        when 'create'
          @api_token.has_permission?(controller_name, :create)
        when 'update', 'patch'
          @api_token.has_permission?(controller_name, :update)
        when 'destroy'
          @api_token.has_permission?(controller_name, :destroy)
        else
          false
      end
    end

    # Subscription feature required to MODIFY this resource. OSS resources
    # return true (no EE gate). EE-migrated controllers override this to
    # require the matching subscription feature. Reads are never gated.
    def ee_write_feature? = true

    def ee_write_allowed?
      return true unless WRITE_ACTIONS.include?(action_name.to_s)
      ee_write_feature?
    end

    #
    # Authentication can be done with
    #   1. Api-Application and Api-Token header
    #   2. Basic-Auth Header
    #
    def valid_api_token?
      api_app = request.headers['Api-Application']
      token_hex = request.headers['Api-Token']

      if api_app.blank? or token_hex.blank?
        # Try Basic Auth
        type, base64 =  request.headers['Authorization'].split(' ') rescue [nil, nil]
        if type == 'Basic'
          api_app, token_hex = Base64.decode64(base64).split(':') rescue [nil, nil]
        end
      end

      if api_app
        RequestStore.store[:swift_track_whodunit] = "API (application '#{api_app}')"
        unless api_app.blank? or token_hex.blank?
          token_digest = Digest::SHA256.hexdigest token_hex
          unless (@api_token = ApiToken.find_by(application: api_app, token_digest: token_digest)).blank?
            # Constant-time compare algorithm
            if Devise.secure_compare(@api_token.token_digest, token_digest)
              @partition = @api_token.partition
              return true
            end
          end
        end
      end
      false
    end

    # Create new object
    def new_object
      unless sub_classes.blank?
        if @sub_class.blank?
          raise Errors::Api::TypeUnknown
        end
      end
      object = model_class.new(partition: @partition)
      object.update(strong_params)
      object
    end

    # Find (multiple) objects
    def find_objects(klass = model_class)
      unless request.query_parameters.blank?
        Rack::Reducer.call(request.query_parameters,
                           dataset: klass.api_query_base.where(partition: @partition),
                           filters: rack_reducers)
      else
        klass.api_query_base.where(partition: @partition)
      end
    end

    # Find single object
    #
    # May be overwritten in models controller for better / more specific search
    def find_single_object
      begin
        @object = model_class.api_query_base.where(partition: @partition).where('id = ? OR name = ?', @id, @identity).limit(1).first
        respond_with_error_text(404) if @object.blank?
      rescue
        respond_with_error_text(404)
      end
    end

    # Respond wrapper
    def respond_to_get(single: false)
      begin
        hash = yield
        (single and hash.blank?) ? respond_with_error_text(404) : respond_with_success(hash)
      rescue Errors::Api::Any => e
        respond_with_error_text(:bad_request, e.message)
        # rescue Exception
        # respond_with_error_text(404)
      end
    end

    # Respond wrapper
    def respond_to_post
      begin
        response = yield
        respond_with_success(response)
      rescue ActiveRecord::RecordInvalid => e
        respond_with_validation_error(e)
      rescue ActionController::UnpermittedParameters => e
        respond_with_error_text(:bad_request, e.message)
      rescue ActiveRecord::RecordNotUnique
        respond_with_error_text(409, 'The object/relationship already exists.')
      rescue Errors::Api::Any => e
        respond_with_error_text(:bad_request, e.message)
      rescue ArgumentError => e
        respond_with_error_text(:bad_request, e.to_s.gsub('"',"'"))
      rescue SshKey::PublicKeyError => e
        respond_with_error_text(:bad_request, "SSH public-key error: #{e.to_s}")
      rescue Exception
        respond_with_error_text(:bad_request, 'Bad request / a general error occurred. Please review request / data.')
      end
    end

    # Respond wrapper
    def respond_to_put
      begin
        response = yield
        respond_with_success(response)
      rescue ActiveRecord::RecordInvalid => e
        respond_with_validation_error(e)
      rescue Errors::Api::Any => e
        respond_with_error_text(:bad_request, e.message)
      rescue ActionController::UnpermittedParameters => e
        respond_with_error_text(:bad_request, e.message)
      rescue ActiveRecord::RecordNotUnique
        respond_with_error_text(409, 'The object or relationship already exists')
      rescue ArgumentError => e
        respond_with_error_text(:bad_request, e.to_s.gsub('"',"'"))
      rescue SshKey::PublicKeyError => e
        respond_with_error_text(:bad_request, "SSH public-key error: #{e.to_s}")
      rescue Exception
        respond_with_error_text(:bad_request, 'Bad request / a general error occurred. Please review request / data.')
      end
    end

    # Responders
    def respond_with_success(response)
      respond_to do |format|
        # We include @api_token here, so that the serializers can use @instance_options[:api_token] to access API token
        format.json { render json: response, :status => response ? 200 : 204, api_token: @api_token }
      end
    end

    # Responders
    def respond_with_error_text(code = 404, text = nil)
      error = { errors: [ { message: text.blank? ? 'Not found' : text } ] }
      respond_to do |format|
        format.json { render json: error, status: code }
        format.csv { head code }
      end
    end

    # Responders
    def respond_with_validation_error(exception)
      code = 422
      begin
        exception.record.errors.details.keys.each do |key|
          code = 409 if exception.record.errors.details[key][0][:error] == :taken
        end
      rescue
      end
      errors = exception.record.errors.collect { |e| { field: e.attribute.to_s.gsub('_ids','_members').gsub('_id',''), message: e.message } }
      respond_to do |format|
        format.json { render json: { errors: errors }, status: code }
        format.csv { head code }
      end
    end

    def rescue_from_exception(exception)
      errors = exception.errors.collect { |e| { field: e.attribute, message: e.message } } rescue exception.to_s
      render json: { errors: errors },  status: :bad_request
    end

    def model_class(sub_class = @sub_class)
      sub_class.blank? ? controller_name.classify.constantize : "#{controller_name.classify.to_s}#{sub_class.singularize.camelcase}".constantize
    end

    # Strong Parameters for POST and PUT method
    def strong_params
      # This is a stub for methods created in sub classes
      #
      # Warning - In the inherited controllers, we use wrap_parameters. Due to the wrap_parameters, permit will never get hit on
      #           any unpermitted attributes since they will not get wrapped into <model>: hash by wrap_parameters
    end

    # Strong Parameters for PATCH method
    def strong_params_patch
      # This is a stub for methods created in sub classes
    end

    def sub_classes
      nil
    end

    def cname
      controller_name.classify
    end

    def rack_reducers
      [
          ->(name:) { where(api_query_search_string(:name, name)) },
          ->(removable:) { removable == "true" ? select { |x| x.is_removable? } : select { |x| !x.is_removable? } }
      ]
    end

  end
end