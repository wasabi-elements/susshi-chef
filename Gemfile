source 'https://rubygems.org'

gem "rails", "~> 8.1.3"

gem 'jquery-rails'

gem 'jquery-ui-rails'

gem 'pg'
gem 'with_advisory_lock'

# Writing and deploying cron jobs
gem 'whenever', require: false

# Active Record Bulk importing
gem 'activerecord-import'

# ActiveRecord SessionStore
gem 'activerecord-session_store'

# ActiveRecord TypedStore
gem 'activerecord-typedstore'

# ActiveModel Serializer
gem 'active_model_serializers'

# ActiveRecord Act as List
gem 'acts_as_list'

# Bootstrap
gem 'bootstrap-sass'
gem 'data-confirm-modal'

# Bootstrap Form (Bootstrap 3 requires version 2.7)
gem 'bootstrap_form', '~> 2.7'

# AAA
gem 'cancan'

# Country selector
gem 'country-select'

# AAA
gem 'devise'
gem 'devise-bootstrap-views'
gem 'devise-security'
gem 'devise-two-factor'
gem 'pundit'

# Gretel - Breadcrumbs
gem 'gretel'

# HAML
gem 'haml'
gem 'haml-rails'

# Awesome fonts
gem 'font_awesome5_rails'

# Prefix css with vendor
gem 'autoprefixer-rails'

# IPaddress gem
gem 'ipaddress'

# OpenSSL
gem 'openssl'

# Domain names
gem 'public_suffix'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder'

# Faster JSON parser
gem 'yajl-ruby', require: 'yajl'

# Pagination
gem 'kaminari'

# Use puma as app server
gem 'puma'

# JWT
gem 'jwt'

# Autocomplete
gem 'rails-jquery-autocomplete'

# Instead of Thread.current problems with passenger
gem 'request_store'

# Net::SSH
gem 'net-ssh'
gem 'rbnacl', '< 5.0' # Net:SSH requirement for chacha20-poly1305@openssh.com support
gem 'ed25519'
gem 'x25519'          # Net:SSH requirement for curve25519-sha256 support
gem 'bcrypt_pbkdf'

# Search engine
gem 'ransack'

# QR Code
gem 'rqrcode'

# Beautiful CSS
gem 'sass-rails'

# Simple Forms
gem 'simple_form'

# Dynamic fields for
gem 'dynamic-fields-for'

# SSH Keygen (used for Key-Gen to Gateways)
gem 'sshkey'

# Protect from malicious clients / API usage
gem 'rack-attack'

# Rack-Reducer Gem
gem 'rack-reducer', require: 'rack/reducer'

# Turbolinks
gem 'turbolinks'
gem 'nprogress-rails'

# range_operators
gem 'range_operators'

# Required on Linux systems
gem 'tzinfo-data'

# Health Check
gem 'health_check'

# Client auth plugins
gem 'ruby-radius'

# OpenStruct
gem 'ostruct'

# Rails 3.4.4 Upgrade
gem 'base64'
gem 'bigdecimal'
gem 'csv'
gem 'mutex_m'

# Rest-Client
gem "rest-client"

gem "dotenv-rails"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'activerecord-nulldb-adapter'
  gem 'coffee-rails'
  gem 'listen'
  gem 'terser'
end

group :development, :devint, :integration, :apitest do
  gem 'awesome_print' # Console command ap
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'brakeman'
  gem 'dotenv'
  gem 'faker'
  gem 'gem-licenses'
  gem 'gemsurance'
  gem 'table_print' # Console command tp
  gem 'web-console'
  gem "rubocop-rails-omakase", require: false

  # --- Benchmarking GEMs - activate if necessary
  gem 'bullet'
  # gem 'memory_profiler'
  # gem 'derailed_benchmarks'
  # gem 'gc_tracer'
  # gem 'rbtrace'
end

group :test do
  gem "mocha"
end

unless ENV["NO_INTERNAL"]
  local_gemfile = File.expand_path("Gemfile.internal", __dir__)
  eval_gemfile(local_gemfile) if File.exist?(local_gemfile)
end
