# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

scale = (ENV["SCALE"].blank? ? 1 : ENV["SCALE"]).to_i

partition = Partition.find_by_name("The Partition")

if partition.blank?
  puts "Creating ..."
  puts "... Partition"

  partition = Partition.create(name: "The Partition", description: "Created by db:seed")
  Partition.create_partition_related_models(partition)
else
  puts "Destroying ..."
  puts "... AdminUsers"
  User.where.not(username: %w[admin oliver aheckel]).all.destroy_all
  puts "... SessionReports"
  SessionReport.where(partition:).destroy_all
  puts "... Accesses"
  Access.where(partition:).destroy_all
  puts "... Bastions"
  Bastion.where(partition:).destroy_all
  puts "... SourceIpGroups"
  SourceIpGroup.where(partition: partition).where.not(name: "Any").destroy_all
  puts "... SourceIpNets"
  SourceIpNet.where(partition: partition).where.not(system_int: true).destroy_all
  puts "... SusshiUserGroups"
  SusshiUserGroup.where(partition: partition).destroy_all
  puts "... SusshiUsers"
  SusshiUser.where(partition: partition).where.not(name: %w[oliver aheckel]).destroy_all
  puts "... TargetFusionGroups"
  TargetFusionGroup.where(partition: partition).destroy_all
  puts "... TargetFusions"
  TargetFusion.where(partition:).destroy_all
  puts "... TargetGroups"
  TargetGroup.where(partition:).destroy_all
  puts "... Targets"
  Target.where(partition:).destroy_all
  puts "... TargetUserGroups"
  TargetUserGroup.where(partition: partition).where.not(system_int: true).destroy_all
  puts "... TargetUsers"
  TargetUser.where(partition: partition).where.not(system_int: true).destroy_all
  puts "... Proxies"
  Proxy.where(partition:).destroy_all
end

# Helper - SSH Keys

user_keys = partition.partition_setting.AllowedUserKeyTypes.map do |key_type|
  type, bits = key_type.split(':')
  SshKey.generate_key_data(type[/rsa|ecdsa|ed25519/]&.upcase, bits.to_i, key_type)&.first
end

host_keys = partition.partition_setting.AllowedUserKeyTypes.map do |key_type|
  type, bits = key_type.split(':')
  SshKey.generate_key_data(type[/rsa|ecdsa|ed25519/]&.upcase, bits.to_i, key_type)&.first
end

# AdminUsers

puts "Creating ..."

puts "... AdminUsers"
Faker::UniqueGenerator.clear

partitions = Partition.all

(1..(3*scale)).each do
  name = Faker::Name.unique.name
  username = name.tr(".-","").split.collect{|x| x[0..4]}.join()[0..8]

  User.create(
    username: Faker::Internet.unique.user_name(specifier: username),
    fullname: name,
    email: Faker::Internet.unique.email(name: name),
    password: "Test&1234",
    password_confirmation: "Test&1234",
    partitions: partitions.sample([1, rand(partitions.size)].max),
    role: %w[admin readonly super].sample
  )
end

# Proxies

puts "... Proxies"
Faker::UniqueGenerator.clear

(1..(5*scale)).each do
  domain_name = Faker::Internet.domain_name

  Proxy.create(
    hostname: domain_name,
    name: domain_name,
    partition:,
    realm: Faker::Internet.slug(glue: "-")
  )
end

# SourceIps

puts "... SourceIps"
Faker::UniqueGenerator.clear

(1..(25 * scale)).each do
  ip_address = [Faker::Internet.ip_v4_address, Faker::Internet.ip_v6_address].sample
  SourceIpNet.create(ip_address:, name: ip_address, partition:)
end

puts "... SourceIpGroups"
Faker::UniqueGenerator.clear

source_ips = SourceIpNet.where(partition: partition)

(1..(15 * scale)).each do
  SourceIpGroup.create(
    name: "Group - #{Faker::Appliance.brand}",
    partition:,
    source_ip_nets: source_ips.sample(rand(1..5))
  )
end

# SusshiUsers

puts "... SusshiUsers"

Faker::UniqueGenerator.clear
(1..(25 * scale)).each do
  name = Faker::Name.unique.name
  username = name.tr(".-","").split.collect{|x| x[0..4]}.join()[0..8]

  susshi_user_keys = user_keys.sample([3, rand(user_keys.size)].min).map.with_index do |public_blob, index|
    SusshiUserKey.new(title: "User-Key #{index + 1}", public_blob:)
  end

  SusshiUserLogin.create(
    partition:        partition,
    name:             Faker::Internet.unique.user_name(specifier: username),
    fullname:         name,
    email:            Faker::Internet.unique.email(name: name),
    susshi_user_keys: susshi_user_keys,
    totp_state:       %w[active activation_pending inactive].sample
  )
end

puts "... SusshiUserGroups"

Faker::UniqueGenerator.clear
susshi_user_logins = SusshiUserLogin.where(partition: partition).order("RANDOM()")
(1..(10*scale)).each do
  SusshiUserGroup.create(
    name: "Group - #{Faker::Music.band}",
    partition:,
    susshi_user_logins: susshi_user_logins.sample(rand(1..5))
  )
end

# Targets

puts "... Targets"

Faker::UniqueGenerator.clear
proxies = Proxy.where(partition: partition).order("RANDOM()")
(1..(150 * scale)).each do
  sockets = (1..rand(1..2)).map do
    TargetSocket.create(
      ip_address: [Faker::Internet.unique.public_ip_v4_address, Faker::Internet.unique.ip_v6_address].sample,
      port_range: "22"
    )
  end

  TargetHost.create(
    name: Faker::Internet.unique.domain_name(subdomain: true),
    partition:,
    proxy: proxies.sample,
    target_host_keys: host_keys.sample(rand(1..3)).map { |host_key| TargetHostKey.new(public_blob: host_key) } ,
    target_sockets: sockets
  )
end

Faker::UniqueGenerator.clear
(1..(10 * scale)).each do
  TargetDomain.create(name: "#{Faker::Internet.unique.domain_name}", partition: partition)
end

Faker::UniqueGenerator.clear
(1..(10 * scale)).each do
  TargetDynamic.create(name: Faker::Internet.unique.domain_name(subdomain: true), partition: partition)
end

Faker::UniqueGenerator.clear
(1..(10 * scale)).each do
  network = [Faker::Internet.unique.ip_v4_cidr, Faker::Internet.unique.ip_v6_cidr].sample
  TargetNetwork.create(network:, partition: partition)
end

puts "... TargetGroups"
Faker::UniqueGenerator.clear

targets = Target.where(partition: partition).order("RANDOM()")
(1..(10*scale)).each do
  TargetGroup.create(name: "Group - #{Faker::Music.band}", partition: partition, targets: targets.sample(rand(1..5)))
end

# TargetUsers

puts "... TargetUsers"

Faker::UniqueGenerator.clear
(1..(8*scale)).each do
  name = Faker::Name.unique.name
  username = name.tr(".-","").split.collect{|x| x[0..4]}.join()[0..8]

  TargetUserLogin.create(
    description: name,
    partition:,
    username: Faker::Internet.unique.user_name(specifier: username)
  )
end

puts "... TargetUserGroups"

Faker::UniqueGenerator.clear
target_user_logins = TargetUserLogin.where(partition: partition).order("RANDOM()")

(1..(5*scale)).each do
  TargetUserGroup.create(
    name: "Group - #{Faker::Company.name}",
    partition: partition,
    target_users: target_user_logins.sample(rand(1..5))
  )
end

# TargetFusions

puts "... TargetFusionLinks"

target_users = TargetUserLogin.order("RANDOM()")
targets = Target.order("RANDOM()")

(1..(25*scale)).each do
  TargetFusionLink.create(
    partition:,
    target: targets.sample,
    target_user: target_users.sample,
  )
end

puts "... TargetFusionGroups"

target_fusion_links = TargetFusionLink.order("RANDOM()")

Faker::UniqueGenerator.clear
(1..(15*scale)).each do
  TargetFusionGroup.create(
    name: "Group - #{Faker::Team.name.titleize}",
    target_fusion_links: target_fusion_links.sample(rand(1..5)),
    partition: partition
  )
end

# AccessPolicies

puts "... AccessPolicies"

source_ips = SourceIp.where(partition:).order("RANDOM()")
susshi_users = SusshiUser.where(partition:).order("RANDOM()")
targets = Target.where(partition:).order("RANDOM()")
target_users = TargetUser.where(partition:).order("RANDOM()")
target_fusions = TargetFusion.order("RANDOM()")
profiles = Profile.where(partition:).order("RANDOM()")
proxies = Proxy.where(partition:).order("RANDOM()")

Faker::UniqueGenerator.clear
(1..(100*scale)).each do |i|
  options = {
    partition:,
    name: "Rule %04d" % i,
    active: Faker::Boolean.boolean,
    debug_level: [0, 1, 2, 3].sample,
    source_ips: source_ips.sample(rand(1..5)),
    susshi_users: susshi_users.sample(rand(1..5)),
    profile: profiles.sample
  }

  if rand(4).zero?
    options.merge!(target_fusions: target_fusions.sample(rand(1..5)))
  else
    options.merge!(
      target_users: target_users.sample(rand(1..5)),
      targets: targets.sample(rand(1..5))
    )
  end

  Access.create!(**options)
end

puts "... BastionPolicies"

bastion_profiles = BastionProfile.where(partition:).order("RANDOM()")

Faker::UniqueGenerator.clear
(1..(50*scale)).each do |i|
  options = {
    partition:,
    name: "Rule %04d" % i,
    active: Faker::Boolean.boolean,
    debug_level: [0, 1, 2, 3].sample,
    source_ips: [ source_ips.sample ],
    susshi_users: susshi_users.sample(rand(1..5)),
    bastion_profile: bastion_profiles.sample,
    proxies: proxies.sample(rand(1..2))
  }

  Bastion.create(**options)
end


# SessionReports

puts "... SessionReports"

SSH_MESSAGES = {
  denied: [
    "Permission denied (publickey).",
    "Permission denied, please try again.",
    "Authentication refused.",
    "Access denied.",
    "Host key verification failed."
  ],
  failed: [
    "Failed password for invalid user.",
    "Authentication failed.",
    "Too many authentication failures.",
    "Connection closed by remote host.",
    "User authentication failed."
  ]
}.freeze

susshi_users = SusshiUser.all
target_users = TargetUser.all

Faker::UniqueGenerator.clear
(1..(100*scale)).each do |i|
  state   = %w[denied new active finished failed].sample
  start   = Faker::Time.between(from: 2.day.ago - 1.hour, to: Time.now)
  updated_at = start + Random.rand(86400)
  if updated_at > Time.now
    updated_at = Time.now - Random.rand(2000)
  end
  session = i * Random.rand(1800)
  uniq_id = start.strftime("%Y%m%d-%H%M%d-0001-")+Random.rand(65535).to_s.rjust(5, '0')
  values  = { "susshi_uniqid" => uniq_id,
              "session_state" => state,
              "updated_at"    => updated_at,
              "partition_id"  => partition.id,
              "susshi_user"   => susshi_users.sample.name,
              "client_ip"     => Faker::Internet.private_ip_v4_address,
              "target_ip"     => Faker::Internet.private_ip_v4_address, 'target_port' => 22,
              "target_user"   => target_users.sample.name,
              "session_start" => start,
              "session_time"  => (%w[finished].include?(state) ? session : nil),
              "session_end"   => (%w[finished].include?(state) ? (start + session) : nil),
              "message"       => (SSH_MESSAGES[state.to_sym].sample if SSH_MESSAGES.key?(state.to_sym)) }

  # Add some random data
  SessionReport.new.attributes.keys.collect {|key| key =~ /_(rd|wr|sessions|accept|deny|close|fail|out|in|cancel|reject)$/ ? key : nil}.compact.each do |key|
    r = Random.rand(50)
    values[key] = (r%13 > 9) ? nil : r
  end

  SessionReport.create(values)
end