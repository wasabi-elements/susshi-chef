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

crumb :root do
  link "Home", main_app.root_path
end

#--- Dashboards

crumb :dashboards do
  link "Dashboards"
end

#--- System

crumb :system do
  link "System"
end

#--- Gateways

crumb :gateways do
  link "Gateways"
  parent :partition_settings
end

crumb :gateway do |gateway|
  link gateway.name, gateway
  parent :gateways
end

#--- License

crumb :subscription do
  link "Subscription", main_app.subscriptions_path
  parent :dashboards
end

#--- Partitions

crumb :partitions do
  link "Partitions", main_app.partitions_path
  parent :system
end

crumb :partition do |partition|
  link partition.name, partition
  parent :partitions
end

#--- Partitions

crumb :partition_keys do
  link "Partition Keys", main_app.partition_keys_path
  parent :partition_settings
end

crumb :partition_key do |partition|
  link partition.title, partition
  parent :partition_keys
end

crumb :partition_auth_key do |partition|
  link partition.title, partition
  parent :partition_keys
end

crumb :partition_host_key do |partition|
  link partition.title, partition
  parent :partition_keys
end

crumb :proxy_auth_key do |partition|
  link partition.title, partition
  parent :partition_keys
end

#--- Access

crumb :accesses do
  link "Access Policies", main_app.accesses_path
end

crumb :access do |access|
  link access.name_not_blank, access
  parent :accesses
end

crumb :swift_changes do
  link "Pending Changes"
end

crumb :swift_changes_history do
  link "Changes History"
end

#--- API Tokens

crumb :api_tokens do
  link "API Tokens"
  parent :system
end

crumb :api_token do |api_token|
  link api_token.application, api_token
  parent :api_tokens
end

#--- Bastions

crumb :bastions do
  link "Bastion Policies", ee.bastions_path
end

crumb :bastion do |bastion|
  link bastion.name_not_blank, bastion
  parent :bastions
end

#--- BastionProfiles

crumb :bastion_profiles do
  link "Bastion Profiles", ee.bastion_profiles_path
end

crumb :bastion_profile do |bastion_profile|
  link bastion_profile.name, bastion_profile
  parent :bastion_profiles
end

#--- ClientAuthSets

crumb :client_auth_sets do
  link "Client Authentication Sets", client_auth_sets_path
end

crumb :client_auth_set do |client_auth_set|
  link client_auth_set.name, client_auth_set
  parent :client_auth_sets
end

#--- PartitionSettings

crumb :partition_settings do
  link "Partition"
end

crumb :partition_setting do |partition_setting|
  link partition_setting.partition.name, partition_setting
  parent :partition_settings
end

#--- Preferences

crumb :preferences do
  link "Preferences", main_app.edit_preferences_path
  parent :system
end

#--- Profiles

crumb :profiles do
  link "Access Profiles", main_app.profiles_path
end

crumb :profile do |profile|
  link profile.name, profile
  parent :profiles
end

#--- Proxies

crumb :proxies do
  link "Proxies"
end

crumb :proxy do |proxy|
  link proxy.name, proxy
  parent :proxies
end


#--- SessionReports

crumb :session_reports do
  link "Session Reports"
end

crumb :session_report do |session_report|
  link session_report.susshi_uniqid
  parent :session_reports
end

#--- SourceIps

crumb :source_ips do
  link "Source IP Addresses & Groups"
end

crumb :source_ip do |source_ip|
  link source_ip.name
  parent :source_ips
end

crumb :source_ip_group do |source_ip_group|
  link source_ip_group.name
  parent :source_ips
end

crumb :source_ip_net do |source_ip_net|
  link source_ip_net.ip_address
  parent :source_ips
end

#--- SusshiUsers

crumb :susshi_users do
  link "Gateway Users & Groups"
end

crumb :susshi_user do |susshi_user|
  link susshi_user.fullname
  parent :susshi_users
end

crumb :susshi_user_logins do
  link "Gateway Users"
end

crumb :susshi_user_login do |susshi_user_login|
  link susshi_user_login.fullname
  parent :susshi_user_logins
end

crumb :susshi_user_groups do
  link "Gateway Groups"
end

crumb :susshi_user_group do |susshi_user_group|
  link susshi_user_group.groupname
  parent :susshi_user_groups
end

#--- SystemEvents

crumb :system_events do
  link "System Events"
end

#--- Targets

crumb :targets do
  link "Targets & Groups"
end

crumb :target do |target|
  link target.name
  parent :targets
end

crumb :target_hosts do
  link "Static Target"
end

crumb :target_host do |target_host|
  link target_host.hostname
  parent :target_hosts
end

crumb :target_groups do
  link "Target Groups"
end

crumb :target_group do |target_group|
  link target_group.groupname
  parent :target_groups
end

crumb :target_domains do
  link "Domain Target"
end

crumb :target_domain do |target_domain|
  link target_domain.domainname
  parent :target_domains
end

crumb :target_domain_hosts do
  link "Domain Target (Host)"
end

crumb :target_domain_host do |target_domain_host|
  link target_domain_host.hostname
  parent :target_domain_hosts
end

crumb :target_dynamics do
  link "Dynamic Target"
end

crumb :target_dynamic do |target_dynamic|
  link target_dynamic.hostname
  parent :target_dynamics
end

crumb :target_networks do
  link "Domain Target"
end

crumb :target_network do |target_network|
  link target_network.network
  parent :target_networks
end

crumb :target_network_hosts do
  link "Domain Target (Host)"
end

crumb :target_network_host do |target_network_host|
  link target_network_host.address
  parent :target_network_hosts
end

#--- Target Fusions

crumb :target_fusions do
  link "Target Fusions"
end

crumb :target_fusion do |target_fusion|
  link target_fusion.name
  parent :target_fusions
end

crumb :target_fusion_group do |target_fusion_group|
  link target_fusion_group.groupname
  parent :target_fusions
end

crumb :target_fusion_link do |target_fusion_link|
  link target_fusion_link.name
  parent :target_fusions
end

#--- Target Hostkeys

crumb :target_host_keys do
  link "Target Hostkeys"
end

crumb :target_host_key do |target_host_key|
  link target_host_key.target.name
  parent :target_host_keys
end

#--- Target Users

crumb :target_users do
  link "Target Users & Groups"
end

crumb :target_user do |target_user|
  link target_user.name
  parent :target_users
end

crumb :target_user_group do |target_user_group|
  link target_user_group.name
  parent :target_users
end

crumb :target_user_login do |target_user_login|
  link target_user_login.name
  parent :target_users
end

crumb :target_user_mapping do |target_user_mapping|
  link target_user_mapping.name
  parent :target_users
end

crumb :target_user_regex do |target_user_regex|
  link target_user_regex.name
  parent :target_users
end

#--- (Admin)Users

crumb :users do
  link "Admin Users", users_path
  parent :system
end

crumb :user do |user|
  link user.fullname, user
  parent :users
end



# crumb :projects do
#   link "Projects", projects_path
# end

# crumb :project do |project|
#   link project.name, project_path(project)
#   parent :projects
# end

# crumb :project_issues do |project|
#   link "Issues", project_issues_path(project)
#   parent :project, project
# end

# crumb :issue do |issue|
#   link issue.title, issue_path(issue)
#   parent :project_issues, issue.project
# end

# If you want to split your breadcrumbs configuration over multiple files, you
# can create a folder named `config/breadcrumbs` and put your configuration
# files there. All *.rb files (e.g. `frontend.rb` or `products.rb`) in that
# folder are loaded and reloaded automatically when you change them, just like
# this file (`config/breadcrumbs.rb`).