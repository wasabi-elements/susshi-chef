json.extract! target_host_key, :id, :references, :key_type, :source, :fingerprint, :public_blob, :created_at, :updated_at
json.url target_host_key_url(target_host_key, format: :json)
