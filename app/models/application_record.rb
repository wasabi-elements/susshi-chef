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

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  class << self

    # https://activerecord-hackery.github.io/ransack/going-further/other-notes/#authorization-allowlistingdenylisting
    # https://younes.codes/posts/how-to-hack-with-ransack
    # https://positive.security/blog/ransack-data-exfiltration

    def ransackable_attributes(auth_object = nil)
      column_names + _ransackers.keys
    end

    def ransackable_associations(auth_object = nil)
      reflect_on_all_associations.map { |a| a.name.to_s } + _ransackers.keys
    end

    def query_by_ids_or_names(relation, partition_id, values, ignore_duplicates = [])
      names = values.uniq.compact.select{|x| x.class == String}
      ids = values.uniq.compact.select{|x| x.class == Integer}

      if ids.any?
        records = self.where(partition_id: partition_id, id: ids).pluck(:id)
        if records.size != ids.size
          missing = ids - records
          raise Errors::Api::MemberReferencesNotFound, "Referenced #{relation} #{'ID'.pluralize(missing.size)} #{missing.join(', ')} not existing."
        end
      end

      if names.any?
        records = self.where(partition_id: partition_id, name: names).pluck(:id, :name)
        record_ids = records.map(&:first)
        record_names = records.map(&:second)
        if record_names.size == names.size
          ids += record_ids
        else
          raise Errors::Api::MemberReferencesNotFound, "Referenced #{relation} #{(names - record_names).map{|x| "'#{x}'"}.join(', ')} not existing."
        end
      end

      unless ignore_duplicates.empty?
        if ignore_duplicates.first.class == Integer
          return self.where(partition_id: partition_id, id: ids).where.not(id: ignore_duplicates)
        else
          return self.where(partition_id: partition_id, id: ids).where.not(id: ignore_duplicates.pluck(:id))
        end
      else
        return self.where(partition_id: partition_id, id: ids)
      end
    end

    def api_query_search_string(column, value)
      case value
      when /^begin::/
        ["#{column.to_s} LIKE ?", "#{value.gsub(/^begin::/,'')}%"]
      when /^ibegin::/
        ["#{column.to_s} iLIKE ?", "#{value.gsub(/^ibegin::/,'')}%"]
      when /^end::/
        ["#{column.to_s} LIKE ?", "%#{value.gsub(/^end::/,'')}"]
      when /^iend::/
        ["#{column.to_s} iLIKE ?", "%#{value.gsub(/^iend::/,'')}"]
      when /^match::/
        ["#{column.to_s} LIKE ?", "#{value.gsub(/^match::/,'').gsub('*','%')}"]
      when /^imatch::/
        ["#{column.to_s} iLIKE ?", "#{value.gsub(/^imatch::/,'').gsub('*','%')}"]
      else
        ["#{column.to_s} = ?", value]
      end
    end

    def api_query_base
      self.order('name ASC')
    end

    def get_duplicates(columns = nil)
      if columns.blank?
        columns = self.column_names
        columns.delete('id')
        columns.delete('created_at')
        columns.delete('updated_at')
      end
      cols = columns.map{|col| col.to_s}.join(', ')
      sql =
      <<-SQL
        SELECT * FROM #{self.table_name} WHERE #{self.table_name}.id NOT IN 
        (SELECT id FROM (
            SELECT DISTINCT ON (#{cols}) *
          FROM #{self.table_name}) AS id);
      SQL
      ActiveRecord::Base.connection.execute(sanitize_sql(sql)).map{|x| x['id']}
    end

    def delete_duplicates(columns = nil, silent = false)
      ids = self.get_duplicates(columns)
      puts "   Removing #{ids.size} duplicate record(s) from #{self.table_name}." unless silent or ids.size == 0
      ids.each do |id|
        self.find(id).destroy
      end
    end

  end

  def is_removable?
    unless(d = self.try(:is_destroyable?)).blank?
      case d
        when FalseClass
          return false
        when TrueClass
          return true
        when Hash
          unless d[:true].blank?
            return true
          else
            return false
          end
      end
    else
      return true
    end
  end

end
