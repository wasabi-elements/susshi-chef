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

Chef::Application.routes.draw do

  #-- Error pages

  match '/403', :to => 'errors#forbidden', :via => :all
  match '/404', :to => 'errors#not_found', :via => :all
  match '/500', :to => 'errors#internal_server_error', :via => :all

  #-- Home
  root :to => 'dashboards#overview'

  #-- Health Check
  health_check_routes # prefix: 'susshi-health'

  #-- APIs

  concern :config_api_list do
    get '/', action: :index
  end

  concern :config_api_model do
    get '/', action: :index
    get '/:id', action: :show, constraints: { id: /[0-9]+/ }
    get '/:identity', action: :show, constraints: { identity: /[0-9A-Za-z=_.\/: %"@-]+/ }
    post '/', action: :create
    put ':id', action: :update, constraints: { id: /[0-9]+/ }
    put '/:identity', action: :update, constraints: { identity: /[0-9A-Za-z=_.\/: %"@-]+/ }
    delete '/:id', action: :destroy, constraints: { id: /[0-9]+/ }
    delete '/:identity', action: :destroy, constraints: { identity: /[0-9A-Za-z=_.\/: %"@-]+/ }
    patch '/:id/:operation', action: :patch, constraints: { id: /[0-9]+/, operation: /(add|remove)/ }
    patch '/:identity/:operation', action: :patch, constraints: { identity: /[0-9A-Za-z=_.\/: %"@-]+/, operation: /(add|remove)/ }
  end

  concern :operations_health_api_model do
    get '/', action: :index
    get '/:id', action: :show, constraints: { id: /[0-9]+/ }
    get '/:identity', action: :show, constraints: { identity: /[0-9A-Za-z=_.\/: %"@-]+/ }
  end

  namespace :api do
    namespace :v1 do
      resources :gateways, only: [] do
        post 'register', action: :register, on: :collection
        post 'sic', action: :sic, on: :collection
      end

      resources :reports, only: [] do
        post 'sessions', action: :sessions, on: :collection
      end

      resources :sessions, only: []  do
        post 'context', action: :context, on: :collection
      end

      resources :target_hostkeys, only: [] do
        post 'create', action: :create, on: :collection
        post 'update', action: :update, on: :collection
      end

      resources :users, only: [] do
        post 'interactive', controller: :users, action: :interactive, on: :collection
        # post 'ip_cache', controller: :users, action: :ip_cache, on: :collection
      end

      #-- Operations API

      resource :operations, only: [], defaults: { format: :json } do
        get '/activate_changes', action: :activate, on: :collection
        get '/pending_changes', action: :changes, on: :collection
        get '/subscription', action: :subscription, on: :collection
        get '/version', action: :version, on: :collection
        get '/gateway_auth_keys', action: :gateway_auth_keys, on: :collection
        get '/gateway_host_keys', action: :gateway_host_keys, on: :collection
      end

      namespace :operations, defaults: { format: :json } do
        namespace :health do
          namespace :gateways do
            concerns :operations_health_api_model
          end

          namespace :proxies do
            concerns :operations_health_api_model
          end
        end

        #-- DOTP authentication callback for Radius backend
        resource :dotp, only: [] do
          post 'validate', controller: :dotp, action: :validate, on: :collection
        end

        #-- OpenID authentication and logout callback for SSH Authentication
        resource :oidc, only: [] do
          post 'validate', controller: :oidc, action: :validate, on: :collection, constraints: { secret: /[A-Za-z0-9]{32}/ }
          post 'logout', controller: :oidc, action: :logout, on: :collection
        end
      end

      #-- Config API

      namespace :config, defaults: { format: :json } do
        get '/', controller: :config, action: :index

        namespace :accesses do
          get '/flat', action: :index_flat_csv, defaults: { format: :csv }
          concerns :config_api_model
        end

        namespace :bastions do
          concerns :config_api_model
        end

        namespace :bastion_profiles do
          concerns :config_api_model
        end

        namespace :profiles do
          concerns :config_api_model
        end

        namespace :proxies do
          concerns :config_api_model
        end

        namespace :source_ips do
          concerns :config_api_list
          scope :nets  , defaults: { sub_class: 'nets' }  do concerns :config_api_model end
          scope :groups, defaults: { sub_class: 'groups'} do concerns :config_api_model end
        end

        namespace :susshi_users do
          concerns :config_api_list
          scope :logins, defaults: { sub_class: 'logins' } do
            get '/flat', action: :index_flat_csv, defaults: { format: :csv }
            concerns :config_api_model
          end
          scope :groups, defaults: { sub_class: 'groups' } do
            get '/flat', action: :index_flat_csv, defaults: { format: :csv }
            concerns :config_api_model
          end
        end

        namespace :susshi_user_keys do
          concerns :config_api_model
        end

        namespace :target_users do
          concerns :config_api_list
          scope :logins  , defaults: { sub_class: 'logins' }   do concerns :config_api_model end
          scope :mappings, defaults: { sub_class: 'mappings' } do concerns :config_api_model end
          scope :regexes , defaults: { sub_class: 'regexes' }  do concerns :config_api_model end
          scope :groups  , defaults: { sub_class: 'groups' }   do concerns :config_api_model end
        end

        namespace :targets do
          concerns :config_api_list
          scope :domains , defaults: { sub_class: 'domains' }  do concerns :config_api_model end
          scope :dynamics, defaults: { sub_class: 'dynamics' } do concerns :config_api_model end
          scope :hosts   , defaults: { sub_class: 'hosts' }    do concerns :config_api_model end
          scope :networks, defaults: { sub_class: 'networks' } do concerns :config_api_model end
          scope :groups  , defaults: { sub_class: 'groups' }   do concerns :config_api_model end
        end

        namespace :target_fusions do
          concerns :config_api_list
          scope :links , defaults: { sub_class: 'links' } do concerns :config_api_model end
          scope :groups, defaults: { sub_class: 'groups'} do concerns :config_api_model end
        end

        namespace :target_host_keys do
          concerns :config_api_model
        end

      end

    end

  end

  match '/api/*any', to: 'errors#not_found', via: [:get, :post], defaults: { format: :json }

  #-- Access

  resources :accesses do
    get 'page/:page', :action => :index, :on => :collection
    post 'move/:dragged', action: :move, on: :collection
    get 'changes', :action => :changes, :on => :collection
    get 'activate', :action => :activate, :on => :collection
    get 'changes_history', action: :changes_history, on: :collection
    post 'changes_history', action: :changes_history, on: :collection
  end

  get '/accesses/:id/move', controller: :accesses, :action => :move_dialog, as: :access_move_dialog

  #-- API Tokens

  resources :api_tokens do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- Client Auth Sets

  resources :client_auth_sets do
    get 'page/:page', :action => :index, :on => :collection
    post 'move/:dragged', action: :move, on: :collection
  end

  #-- Dashboard

  get "dashboards/overview", controller: :dashboards, action: :overview
  get 'dashboards/api_manual', controller: :dashboards, :action => :api_manual
  get 'dashboards/pm_collection', controller: :dashboards, :action => :pm_collection
  get 'dashboards/pm_environment', controller: :dashboards, :action => :pm_environment

  resources :loggings, :only => [ :index, :show ] do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- Gateways

  resources :gateways do
    get 'page/:page', :action => :index, :on => :collection
  end
  get '/gateways/:id/renew', controller: :gateways, :action => :renew, as: :renew_gateway_certificate
  get '/gateways/:id/restart', controller: :gateways, :action => :restart, as: :restart_gateway
  get '/gateways/:id/shutdown', controller: :gateways, :action => :shutdown, as: :shutdown_gateway
  get '/gateways/:id/suspend', controller: :gateways, :action => :suspend, as: :suspend_gateway
  get '/gateways/:id/unsuspend', controller: :gateways, :action => :unsuspend, as: :unsuspend_gateway
  get '/gateways/:id/config', controller: :gateways, :action => :show_config, as: :gateway_config

  #-- Partitions

  resources :partitions do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- PartitionKeys

  resources :partition_keys do
    get 'page/:page', :action => :index, :on => :collection
    get 'new/hostkey', action: :new_host_key, on: :collection
    get 'new/authkey', action: :new_auth_key, on: :collection
    post 'move/:klass', action: :move, on: :collection
  end

  resources :partition_host_keys, controller: :partition_keys, type: 'PartitionHostKey'
  resources :partition_auth_keys, controller: :partition_keys, type: 'PartitionAuthKey'
  resources :proxy_auth_keys, controller: :partition_keys, type: 'ProxyAuthKey'

  #-- PartitionSettings

  resources :partition_settings do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- Preferences

  resources :preferences, :only => [] do
    get 'edit', :action => :edit, :on => :collection, :as => :edit
    patch 'update', :action => :update, :on => :collection, :as => :update
    get 'server_ssl', :action => :server_ssl, :on => :collection
    post 'server_ssl', :action => :upload_server_ssl, :on => :collection, :as => :upload_server_ssl
    post 'certificate', :action => :create_certificate, :on => :collection, :as => :create_certificate
    delete 'certifcate', :action => :destroy_certificate, :on => :collection, :as => :destroy_certificate
    get 'activate_certificate', :action => :activate_certificate, :on => :collection, :as => :activate_certificate
    get 'csr', :action => :csr, :on => :collection
    post 'csr', :action => :create_csr, :on => :collection, :as => :create_csr
    delete 'csr', :action => :destroy_csr, :on => :collection, :as => :destroy_csr
    #get "send_test_mail", :action => :send_test_mail
  end

  namespace :preferences do
    get "send_test_mail", :action => :send_test_mail
  end

  resources :subscriptions

  #-- Profiles

  resources :profiles do
    get 'page/:page', action: :index, :on => :collection
    member do
      get :clone
    end
  end

  #-- SessionReports

  resources :session_reports, :only => [:index, :show] do
    get 'page/:page', :action => :index, :on => :collection
  end

  get '/session_reports/:id/terminate', controller: :session_reports, :action => :terminate, as: :terminate_session

  #-- SourceIps

  resources :source_ips do
    get 'page/:page', :action => :index, :on => :collection
    get 'new/net', action: :new_net, on: :collection
    get 'new/group', action: :new_group, on: :collection
  end

  resources :source_ip_nets, controller: :source_ips, type: 'SourceIpNet'
  resources :source_ip_groups, :controller => :source_ips, type: 'SourceIpGroup'

  #-- SusshiUsers

  resources :susshi_users, only: [ :index ] do
    get 'page/:page', :action => :index, :on => :collection
  end

  resources :susshi_user_logins, except: [ :index ] do
    get "send_activation_token", :action => :send_activation_token
    get "send_qr_code", :action => :send_qr_code
  end

  resources :susshi_user_groups, except: [ :index ]

  patch '/susshi_user_logins/:id/unlock', :controller => :susshi_user_logins, :action => :unlock, as: :unlock_susshi_user_login

  #-- SystemEvents

  resources :system_events, :only => :index do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- Targets

  resources :targets, only: [ :index ] do
    get 'page/:page', :action => :index, :on => :collection
  end

  resources :target_hosts, except: [ :index ] do
    get 'scan', :action => :scan, :on => :collection
    post 'scan/execute', :action => :scan_execute, :on => :collection, as: :execute_scan
    post 'scan/process', :action => :scan_process, :on => :collection, as: :process_scan
  end
  post '/target_hosts/scan_host', controller: :target_hosts, :action => :scan_host, as: :scan_target_host

  resources :target_groups, except: [ :index ]

  resources :target_dynamics, except: [ :index ]
  post '/target_dynamics/scan_host', controller: :target_dynamics, :action => :scan_host, as: :scan_target_dynamic_host_key

  resources :target_networks, except: [ :index ]
  get '/target_networks/:id/host', controller: :target_networks, :action => :show_host, as: :target_network_host

  resources :target_domains, except: [ :index ]
  get '/target_domains/:id/host', controller: :target_domains, :action => :show_host, as: :target_domain_host

  #-- Target Host Keys

  resources :target_host_keys do
    get 'page/:page', :action => :index, :on => :collection
  end

  #-- Target Users

  resources :target_users do
    get 'page/:page', :action => :index, :on => :collection
    get 'new/login', action: :new_login, on: :collection
    get 'new/regex', action: :new_regex, on: :collection
    get 'new/group', action: :new_group, on: :collection
    get 'new/mapping', action: :new_mapping, on: :collection
  end

  resources :target_user_logins, controller: :target_users, type: 'TargetUserLogin'
  resources :target_user_regexes, :controller => :target_users, type: 'TargetUserRegex'
  resources :target_user_groups, :controller => :target_users, type: 'TargetUserGroup'
  resources :target_user_mappings, :controller => :target_users, type: 'TargetUserMapping'

  #-- Users

  resources :users do
    get 'page/:page', :action => :index, :on => :collection
    get 'change_partition', :action => :change_partition
    get "send_activation_token", :action => :send_activation_token
    get "send_qr_code", :action => :send_qr_code
  end

  get '/users/:id/profile', controller: :users, :action => :edit_profile, as: :edit_user_profile
  put '/users/:id/profile', controller: :users, :action => :update_profile, as: :update_user_profile
  get '/users/:id/reset_otp', controller: :users, :action => :reset_otp, as: :reset_user_otp

  #-- Devise
  devise_for :users, path: '', controllers: { sessions: 'users/sessions' }, path_names: { sign_in: 'login', sign_out: 'logout', sign_up: 'register', edit: 'settings' }

  devise_scope :user do
    post "/users/sessions/verify_otp" => "users/sessions#verify_otp"
    post "/users/sessions/verify_otp_activation" => "users/sessions#verify_otp_activation"
    post "/users/sessions/commit_otp" => "users/sessions#commit_otp"

    authenticated :user do
      root 'home#index', as: :authenticated_root
    end

    unauthenticated do
      root 'devise/sessions#new', as: :unauthenticated_root
    end
  end

  mount EE::Engine => "/ee" if defined?(EE::Engine)

  match '*any', to: 'errors#not_found', via: [:get, :post]

end
