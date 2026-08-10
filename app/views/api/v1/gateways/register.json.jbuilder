json.Configuration do

  json.Version(@params.config_version)
  json.ChefVersion(CHEF_CONFIG['version'].to_s)

  # Syslog communication
  json.SyslogGatewayName(@params.gateway.name || 'gateway')
  json.SyslogTlsCertificate(@params.gateway.syslog_certificate)
  json.SyslogTlsKey(@params.gateway.syslog_key)

  # Partition configuration
  json.(@params.partition_config, *(PartitionSetting.configuration_keys.select{|x| @params.partition_config[x.to_s].class == FalseClass || @params.partition_config[x.to_s].present?}))

  # Listen addresses
  listen_addresses = @params.gateway.listen_addresses.reject{|a| a.blank? }
  json.ListenAddresses(listen_addresses) unless listen_addresses.blank?

  # SIC SSH public key for remote-commands
  unless (key = @params.gateway.sic_ssh_public_key).blank?
    json.RemoteControlKey(key.split(' ')[0..1].join(' '))
  end

  # Proxies configuration
  unless @params.proxies.blank?
    json.TargetProxies(@params.proxies.collect{|p| { realm: p.realm, hostname: p.hostname, port: p.port }})
  end

  # If gateway must renew SIC certificate (and ca.pem), we send this as a request with PSK
  json.RenewSic(true) if @renew_sic

  json.partial! "ee/api/v1/gateways/register_ee" if lookup_context.exists?("ee/api/v1/gateways/register_ee", [], true)
end