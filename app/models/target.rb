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

class Target < ApplicationRecord

  #-- Datatypes

  #-- Associations
  belongs_to :partition
  belongs_to :proxy, optional: true

  has_many :accesses_targets, dependent: :restrict_with_error
  has_many :accesses, -> { distinct }, through: :accesses_targets

  has_many :target_fusions

  #-- Scopes

  #-- Validations

  #-- Callbacks

  after_save :touch_target_fusions

  #-- Class Methods

  class << self

    def active_collection
      [ ['Active', true], ['Inactive', false] ]
    end

    def types_collection
      [ ['Domain Targets', 'TargetDomain'], ['Dynamic Targets', 'TargetDynamic'], ['Network Targets', 'TargetNetwork'], ['Static Targets', 'TargetHost'], ['Target Groups', 'TargetGroup'] ]
    end

    def types_collection_without_group
      [ ['Dynamic Targets', 'TargetDynamic'], ['Static Targets', 'TargetHost'] ]
    end

    def types_collection_for_hostkeys
      [ ['Domain Targets', 'TargetDomainHost'], ['Dynamic Targets', 'TargetDynamic'], ['Network Targets', 'TargetNetworkHost'],  ['Static Targets', 'TargetHost'] ]
    end

    def count_for_partition
      return 0 if User.current_user.partition.blank?
      Target.where(partition: User.current_user.partition, type: types_collection.map { |x| x.last }).count
    end

    def duallist_collection(partition_id, include_group = true)

      @proxies = Proxy.where(partition_id: partition_id).pluck(:id, :name, :realm).map{|p| [p[0], " @ #{p[2]} (#{p[1]})"]}.to_h

      result = []
      if include_group
        result.push(*TargetGroup.where(partition_id: partition_id)
                                .order("LOWER(name) ASC")
                                .pluck(:id, :name, :proxy_id)
                                .collect { |t| [collection_name(name: t[1], append: '(Group)'), t[0]] }.sort { |x, y| x.first <=> y.first })
      end

      result.push(*TargetNetwork.where(partition_id: partition_id)
                     .order("LOWER(name) ASC")
                     .pluck(:id, :name, :proxy_id)
                     .collect{|t| [collection_name(name: t[1], proxy_id: t[2], append: '(Network)'), t[0]]}.sort{|x,y| x.first <=> y.first})

      result.push(*TargetDynamic.where(partition_id: partition_id)
                     .order("LOWER(name) ASC")
                     .pluck(:id, :name, :proxy_id)
                     .collect{|t| [collection_name(name: t[1], proxy_id: t[2], append: '(Dynamic by FQDN)'), t[0]]}.sort{|x,y| x.first <=> y.first})

      result.push(*TargetDomain.where(partition_id: partition_id)
                     .order("LOWER(name) ASC")
                     .pluck(:id, :name, :proxy_id)
                     .collect{|t| [collection_name(name: t[1], proxy_id: t[2], append: '(DNS Domain)'), t[0]]}.sort{|x,y| x.first <=> y.first})

      result.push(*TargetHost.left_outer_joins(:target_sockets).group(:id).where(partition_id: partition_id)
                     .order("LOWER(name) ASC")
                     .pluck(:id, :name, :proxy_id, "array_agg(target_sockets.ip_address)")
                     .collect { |t| [collection_name(name: t[1], proxy_id: t[2], ips: t[3].compact), t[0]] }.sort { |x, y| x.first <=> y.first })

      result
    end

    def collection_name(name:, proxy_id: nil, sockets: nil, ips: nil, append: nil)
      title = proxy_id ? "#{name}#{@proxies[proxy_id]}" : name
      title = "#{title} - #{ips.map{|ip| ip.split('/').first}.join(', ')}" unless ips.blank?
      title = "#{title} - #{append}" unless append.blank?
      title
    end

    def query_target_by_ids_or_names(relation, partition_id, values, ignore_duplicates = [])
      ids = values.uniq.compact.select{|x| x.class == Integer}
      names = values.uniq.compact.select{|x| x.class == String}
      names_with_proxy = names.select{|name| name.include?('@')}
      names_without_proxy = names - names_with_proxy

      if ids.any?
        records = self.where(partition_id: partition_id, id: ids).pluck(:id)
        if records.size != ids.size
          missing = ids - records
          raise Errors::Api::MemberReferencesNotFound, "Referenced #{relation} #{'ID'.pluralize(missing.size)} #{missing.join(', ')} not existing."
        end
      end

      if names_without_proxy.any?
        records = self.where(partition_id: partition_id, name: names_without_proxy, proxy_id: nil).pluck(:id, :name)
        record_ids = records.map(&:first)
        record_names = records.map(&:second)
        if record_names.size == names_without_proxy.size
          ids += record_ids
        else
          raise Errors::Api::MemberReferencesNotFound, "Referenced #{relation} #{(names_without_proxy - record_names).map{|x| "'#{x}'"}.join(', ')} not existing."
        end
      end

      names_with_proxy.each do |name_with_proxy|
        name, proxy = name_with_proxy.split('@').map(&:strip)
        id = Target.joins(:proxy).where(name: name, proxies: { realm: proxy }).pluck(:id).first
        if id
          ids << id
        else
          raise Errors::Api::MemberReferencesNotFound, "Referenced #{relation} '#{name_with_proxy}' not existing."
        end
      end

      unless ignore_duplicates.empty?
        if ignore_duplicates.first.class == Integer
          return self.api_query_base.where(partition_id: partition_id, id: ids).where.not(id: ignore_duplicates)
        else
          return self.api_query_base.where(partition_id: partition_id, id: ids).where.not(id: ignore_duplicates.pluck(:id))
        end
      else
        return self.api_query_base.where(partition_id: partition_id, id: ids)
      end
    end

  end

  #-- Instance Methods

  STRING = 'fa-exclamation'

  def icon
    STRING
  end

  def display_name
    display_name_a.join(' - ')
  end

  def display_name_a
    [name_with_proxy]
  end

  def name_with_proxy
    self.proxy ? "#{self.name} @ #{self.proxy.realm} (#{self.proxy.name})" : self.name
  end

  def display_type
    self.type
  end

  def is_destroyable?
    return {false: 'Is assigned to an Access Rule'} if accesses.any?
    return {false: 'Is assigned to an Target Fusion'} if target_fusions.any?
    {true: "Delete Target '#{self.name}'"}
  end

  def memberships
    self.target_groups.pluck(:name)
  end

  def memberships=(values)
    self.target_groups = TargetGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def memberships_add(values)
    self.target_groups << TargetGroup.query_by_ids_or_names('memberships', self.partition_id, values, self.target_groups)
  end

  def memberships_remove(values)
    self.target_groups.delete TargetGroup.query_by_ids_or_names('memberships', self.partition_id, values)
  end

  def proxy_realm=(value)
    if value == 'none' or value.nil?
      self.proxy = nil
    else
      self.proxy = Proxy.where('partition_id = ? AND realm = ?', self.partition_id, value.to_s).first
      if self.proxy.nil?
        errors.add(:proxy_realm, "Proxy realm not found.")
        raise ActiveRecord::RecordInvalid, self
      end
    end
  end

  def proxy_realm
    self.proxy.try(:realm)
  end

  def target_host_keys
    []
  end

  def target_host_keys_count
    target_host_keys.count
  end

  def target_user_host_keys
    []
  end

  def target_user_host_keys_count
    target_user_host_keys.count
  end

  def title
    self.class.name.demodulize.titleize rescue "Target Base"
  end

  protected

  def update_target_host_keys(values)
    want = values.map {|s| SshKey.pubkey_without_comment(s[:public_blob]) }
    self.target_host_keys.each do |host_key|
      if want.include?(host_key.public_blob)
        want.delete(host_key.public_blob)
      else
        host_key.destroy
      end
    end
    want.each do |blob|
      self.target_host_keys.build({public_blob: blob})
    end
  end

  private

  def touch_target_fusions
    target_fusions.each do |target_fusion|
      target_fusion.save
    end
  end

  def favor_system_wide_host_keys
    if target_host_keys.any?
      target_user_host_keys.destroy_all
    end
  end

end
