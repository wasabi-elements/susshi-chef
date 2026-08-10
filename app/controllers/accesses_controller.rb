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

class AccessesController < ApplicationController

  before_action :find_and_authorize, only: [:show, :edit, :update, :destroy, :move_dialog]

  def index
    @title = 'Access Policies'
    authorize :access, :index?

    #-- Load session if no params set (required for assist queries)
    if params[:q].nil?
      params[:q] = session["#{controller_action}_query".to_sym] rescue {}
    end

    @show_last_use = !params.dig(:q, :last_use_at_gteq).blank?
    if params.dig(:q, :last_use_at_gteq) == 'never'
      params[:q].delete(:last_use_at_gteq)
      params[:q][:last_use_at_null] = true
    end

    @q = Access.includes([:source_ips, :susshi_users, :target_users, :target_fusions, :profile, targets: [:proxy]]).where(partition_id: current_user.partition.id)
    susshi_user_names = []

    unless (assist = params[:q][:assist] rescue nil).blank?
      assist.each do |key, value|
        next if value.blank?
        case key
        when 'position'
          min = Access.where(partition_id: current_user.partition.id).minimum(:position)
          @q = @q.where('accesses.position >= ?', min + value.to_i - 1)

        when 'source_ip'
          sq = SourceIp.where(partition_id: current_user.partition.id).where('name iLIKE ?', "%#{value}%").collect do |source|
            if source.class == SourceIpGroup
              source.id
            else
              [source.id] + source.source_ip_groups.pluck(:id)
            end
          end.flatten

          if (ip = IPAddress(value) rescue nil)
            SourceIpNet.where(partition_id: current_user.partition.id).collect do |source|
              if (IPAddress(source.ip_address).include?(ip) rescue nil)
                sq << ([source.id] + source.source_ip_groups.pluck(:id)).flatten
              end
            end
          end

          @q = @q.joins(:source_ips).where(source_ips: { id: sq.flatten })

        when 'susshi_user_name'
          result = SusshiUser.where(partition_id: current_user.partition.id).where('name iLIKE ?', "%#{value}%").collect do |user|
            if user.class == SusshiUserGroup
              [ user.id, user.name ]
            else
              [ ([user.id] + user.susshi_user_groups.pluck(:id)).flatten, ([user.name] + user.susshi_user_groups.pluck(:name)).flatten ]
            end
          end
          ids = result.collect(&:first).flatten
          susshi_user_names = result.collect(&:last).flatten
          @q = @q.joins(:susshi_users).where(susshi_users: { id: ids })

        when 'target_user_name'
        sq = TargetUser.where(partition_id: current_user.partition.id).where('name iLIKE ?', "%#{value}%").collect do |user|
          if user.class == TargetUserGroup
            user.id
          else
            [user.id] + user.target_user_groups.pluck(:id)
          end
        end.flatten

        TargetUserRegex.where(partition_id: current_user.partition.id).each do |tuser|
          begin
            if value =~ /#{tuser.regex_effective}/
              sq << ([tuser.id] + tuser.target_user_groups.pluck(:id)).flatten
            end
          rescue RegexpError
            next
          end
        end

        susshi_user_names.each do |suser|
          TargetUserMapping.where(partition_id: current_user.partition.id).each do |tuser|
            begin
              if suser.gsub(/#{tuser.regex_effective}/, tuser.translate.gsub('$','\\')) =~ /#{Regexp.escape(value)}/
                sq << ([tuser.id] + tuser.target_user_groups.pluck(:id)).flatten
              end
            rescue RegexpError
              next
            end
          end
        end

        tf = TargetFusionLink.where(partition_id: current_user.partition.id).where(target_user_id: sq).collect do |fusion|
          [fusion.id] + fusion.target_fusion_groups.pluck(:id)
        end.flatten

        if tf.any?
          access_ids = @q.joins(:target_users).where(target_users: { id: sq.flatten }).pluck(:id)
          access_ids += @q.joins(:target_fusions).where(target_fusions: { id: tf }).pluck(:id)
          @q = @q.where(id: access_ids.flatten.compact)
        else
          @q = @q.joins(:target_users).where(target_users: { id: sq.flatten })
        end

        when 'target'
          sq = Target.where(partition_id: current_user.partition.id)
                     .where(type: %w(TargetDomain TargetDynamic TargetGroup TargetHost TargetNetwork))
                     .where('name iLIKE ?', "%#{value}%").collect do |target|
            if target.class == TargetGroup
              target.id
            else
              [target.id] + target.target_groups.pluck(:id)
            end
          end.flatten

          if (ip = IPAddress(value) rescue nil)
            TargetHost.joins(:target_sockets).where(partition_id: current_user.partition.id).collect do |target|
              target.target_sockets.each do |socket|
                if (IPAddress(socket.ip_address).include?(ip) rescue nil)
                  sq << ([target.id] + target.target_groups.pluck(:id)).flatten
                end
              end
            end

            TargetNetwork.where(partition_id: current_user.partition.id).collect do |target|
              if (IPAddress(target.name).include?(ip) rescue nil)
                sq << ([target.id] + target.target_groups.pluck(:id)).flatten
              end
            end
          end

          tf = TargetFusionLink.where(partition_id: current_user.partition.id).where(target_id: sq).collect do |fusion|
            [fusion.id] + fusion.target_fusion_groups.pluck(:id)
          end.flatten

          if tf.any?
            access_ids = @q.joins(:targets).where(targets: { id: sq.flatten }).pluck(:id)
            access_ids += @q.joins(:target_fusions).where(target_fusions: { id: tf }).pluck(:id)
            @q = @q.where(id: access_ids.flatten.compact)
          else
            @q = @q.joins(:targets).where(targets: { id: sq.flatten })
          end

        end
      end
    end

    @assist = (params[:q][:assist] rescue session["#{controller_action}_query".to_sym][:assist]) rescue {}
    @q = @q.ransack(params_query)
    ransack_default_sort(@q, :position, :asc)
    @accesses = @q.result.distinct.page(params_page).per(params_per_page)
    @rule_no_offset = (Access.minimum(:position) - 1) rescue 0
  end

  def show
    @title = "Details of '#{@access.name_not_blank}'"
  end

  def new
    @title = "New Access Policy"
    authorize :access, :new?
    @partition = Partition.find(current_user.partition.id)
    @access = Access.new(partition: @partition)
    prepare_positions
  end

  def edit
    @title = "Edit '#{@access.name_not_blank}'"
    prepare_positions
  end

  def create
    authorize :access, :create?

    @access = Access.create(access_params)
    if (@access.save)
      redirect_to accesses_path, flash: { success: 'Access Policy was successfully created.' }
    else
      prepare_positions
      render :new
    end
  end

  def update
    if @access.update(access_params)
      redirect_to accesses_path, flash: { success: 'Access Policy was successfully updated.' }
    else
      prepare_positions
      render :edit
    end
  end

  def destroy
    @access.destroy
    redirect_to accesses_path, flash: { destroy: 'Access Policy was successfully destroyed.' }
  end

  def move
    authorize :access, :move?
    Access.reorder(params[:access].collect{|p| p.to_i}, params[:dragged].to_i)
    head  :no_content
  end

  def move_dialog
    prepare_positions
    render
  end

  def changes
    @title = 'Pending Changes'
    authorize :access, :changes?

    @swift_changes = current_user.partition.pending_swift_changes.order(created_at: :desc)
    @last_activation = current_user.partition.last_swift_changes_activation

    @problems = current_user.partition.partition_host_keys.where(active: true).none? ||
                current_user.partition.partition_auth_keys.where(active: true).none?
  end

  def activate
    authorize :access, :activate?

    if Access.activate(current_user.partition, User.current_user.name,["Activated by #{User.current_user.name} (#{User.current_user.username})"])
      respond_to do |format|
        format.html { redirect_to changes_accesses_path, flash: { success: 'Changes were successfully activated.' } }
      end
    else
      respond_to do |format|
        format.html { redirect_to changes_accesses_path, flash: { error: 'Internal error. Changes were not activated.' } }
      end
    end
  end

  def changes_history
    @title = "Changes History"
    authorize :access, :changes_history?

    unless (params['swift_changes']['version'] rescue nil).blank?
      @title = "Details of '##{params['swift_changes']['version']}'"
      @version = params['swift_changes']['version']
      @changes_history = SwiftChange.order(created_at: :desc).where(partition_id: current_user.partition.id, swift_version: @version)
    end
  end

  private

    def find_and_authorize(id = params[:id])
      @access = Access.readonly(false).find(id)
      authorize @access
    end

    def access_params
      params.require(:access).permit(:partition_id, :name, :description, :active, :debug_level, :position, :profile_id, source_ip_ids: [], susshi_user_ids: [], target_user_ids: [], target_ids: [], target_fusion_ids: [])
    end

    def prepare_positions
      if %w(new create).include?(params[:action])
        @positions = Access.where(partition: current_user.partition).order(:position).pluck(:id, :position, :name).collect do |a|
          ["in front of Pos. ##{'%04i' % a.second} (ID ##{'%05i' % a.first} - #{a.last.blank? ? 'no policy title given' : a.last})", a.second]
        end
      else
        cpos = @access.try(:position) || 0
        @positions = Access.where(partition: current_user.partition).order(:position).pluck(:id, :position, :name).collect do |a|
          ptext = if a.second == cpos
                    'current'
                  else
                    if a.second < cpos
                      'in front of'
                    else
                      'after'
                    end
                  end
          ["#{ptext} Pos. ##{'%04i' % a.second} (ID ##{'%05i' % a.first} - #{a.last.blank? ? 'no policy title given' : a.last})", a.second]
        end
      end
    end

end


