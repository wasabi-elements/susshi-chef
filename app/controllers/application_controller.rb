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

class ApplicationController < ActionController::Base

  include Pundit::Authorization

  layout :layout_by_resource

  protect_from_forgery

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized


  #--- Filters
  before_action :authenticate_user!
  before_action :authorize_user
  before_action :devise_permitted_parameters, if: :devise_controller?
  before_action :ensure_otp_activation, unless: :devise_controller?
  before_action :better_errors_hack, if: -> { Rails.env.development? }

  #--- Helper Methods
  helper_method :sort_column?, :sort_direction?, :params_per_page, :cname

  #--- Class Methods

  #--- Instance Methods
  def sort_column?
    session["#{controller_action}_sort".to_sym]
  end
 
  def sort_direction?
    session["#{controller_action}_sort_dir".to_sym]
  end
  
  private

  def pundit_user
    Context.new(controller_name)
  end

  def authorize_user
    unless current_user.blank?
      if (current_user.has_any_role? rescue false)
        User.current_user = current_user
        partition_id = cookies[:partition_id] || User.partition.id rescue nil
        User.set_partition_by_id(partition_id)
      else
        reset_session
      end
    else
      unless devise_controller?
        reset_session
      end
    end
  end

  def ensure_otp_activation
    return if current_user.otp_activation_token.blank?
    return unless Preference.any?
    return unless Preference.first.otp_active?

    render "devise/sessions/otp_activation", layout: "devise"
  end

  def user_not_authorized
    flash[:alert] = 'You are not authorized to perform this action.'
    referer_uri = URI.parse(request.referer.to_s) rescue nil
    same_host   = referer_uri&.host == request.host && referer_uri&.port == request.port

    if request.referer.blank? || request.referer == request.url || !same_host
      redirect_to root_path
    else
      redirect_to request.referer
    end
  end

  def sort_column(def_col)
    sort = params[:sort] || session["#{controller_action}_sort".to_sym] || def_col
    session["#{controller_action}_sort".to_sym] = sort # cclass.column_names.include?(sort.to_s) ? sort : nil
  end
  
  def sort_direction(def_dir)
    dir = params[:direction] || session["#{controller_action}_sort_dir".to_sym] || def_dir
    session["#{controller_action}_sort_dir".to_sym] = %w[asc desc].include?(dir) ? dir : nil
  end
  
  def params_sort(def_col='name', def_dir='ASC')
    "\"#{sort_column(def_col)}\" #{sort_direction(def_dir)}"
  end
  
  def params_page
    # kaminari does not send params[:page] on page 1, so flash[] is used to determine this situation.
    session["#{cname}_page".to_sym] = if params[:page].blank? then
                                        flash["on_#{cname}_index".to_sym] ? params[:page] : session["#{cname}_page".to_sym]
                                      else
                                        params[:page]
                                      end
    flash["on_#{cname}_index".to_sym] = true
    session["#{cname}_page".to_sym]
  end
 
  def params_per_page
    session["#{controller_action}_per_page".to_sym] = params[:per_page] || session["#{controller_action}_per_page".to_sym] || 30
  end

  def params_query(_params = params[:q])
    _params ||= session["#{controller_action}_query".to_sym] ||= {}

    # Storing the query object (ActionController::Parameters) triggers `TypeError - can't dump IO` in Rails 7
    _params = _params.to_unsafe_h if _params.respond_to?(:to_unsafe_h)

    # Pagination - (re)set page when query changes
    # Looks like this is no longer needed ... delete me on review ;)
    #_params[:page] = 1 unless _params == session["#{controller_action}_query".to_sym]

    session["#{controller_action}_query".to_sym] = _params
  end

  def cname
    controller_name.classify
  end

  def controller_action
    "#{controller_name}__#{action_name}"
  end
  
  def cclass
    controller_name.classify.constantize
  end

  def ransack_default_sort(query, def_col= :name, def_dir= :desc)
    query.sorts = (session["#{controller_action}_sort".to_sym] || "#{def_col.to_s} #{def_dir.to_s}") if query.sorts.empty?
    session["#{controller_action}_sort".to_sym] = "#{query.sorts.first.name} #{query.sorts.first.dir}"
  end

  private

  def better_errors_hack
    request.env['puma.config'].options.user_options.delete(:app) if request.env.has_key?('puma.config')
  end

  def layout_by_resource
    devise_controller? ? 'devise' : 'application'
  end

  def devise_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: [:otp_attempt])
  end

end