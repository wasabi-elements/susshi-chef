json.extract! target_user, :id, :name, :created_at, :updated_at
json.url target_user_url(target_user, format: :json)
