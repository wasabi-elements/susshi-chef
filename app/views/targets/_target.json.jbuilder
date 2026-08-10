json.extract! target, :id, :references, :name, :active, :created_at, :updated_at
json.url target_url(target, format: :json)
