json.extract! source_ip, :id, :type, :name, :description, :ip_address, :version, :ip4_first, :ip4_last, :ip6_first, :ip6_last, :prefix, :created_at, :updated_at
json.url source_ip_url(source_ip, format: :json)
