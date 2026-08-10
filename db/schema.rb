# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_07_172741) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "hstore"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "accesses", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, null: false
    t.integer "debug_level", default: 0
    t.string "description"
    t.datetime "first_use_at", precision: nil
    t.datetime "last_use_at", precision: nil
    t.string "name"
    t.integer "partition_id"
    t.bigint "position"
    t.bigint "profile_id"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "use_count", default: 0
    t.index ["partition_id"], name: "index_accesses_on_partition_id"
    t.index ["profile_id"], name: "index_accesses_on_profile_id"
  end

  create_table "accesses_source_ips", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "source_ip_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["access_id", "source_ip_id"], name: "index_accesses_source_ips_on_access_id_and_source_ip_id", unique: true
  end

  create_table "accesses_susshi_users", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "susshi_user_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["access_id", "susshi_user_id"], name: "index_accesses_susshi_users_on_access_id_and_susshi_user_id", unique: true
  end

  create_table "accesses_target_fusions", force: :cascade do |t|
    t.bigint "access_id"
    t.bigint "target_fusion_id"
    t.index ["access_id", "target_fusion_id"], name: "index_accesses_target_fusions_on_access_id_and_target_fusion_id", unique: true
  end

  create_table "accesses_target_users", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "target_user_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["access_id", "target_user_id"], name: "index_accesses_target_users_on_access_id_and_target_user_id", unique: true
  end

  create_table "accesses_targets", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "target_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["access_id", "target_id"], name: "index_accesses_targets_on_access_id_and_target_id", unique: true
  end

  create_table "api_tokens", force: :cascade do |t|
    t.string "application"
    t.string "comment"
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.bigint "partition_id"
    t.jsonb "permissions", default: {}
    t.string "token_digest"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["application"], name: "index_api_tokens_on_application"
    t.index ["partition_id"], name: "index_api_tokens_on_partition_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest"
  end

  create_table "bastion_profiles", force: :cascade do |t|
    t.boolean "LogEncryption", default: true
    t.integer "LoggingMask", default: 17
    t.integer "MaxSessionIdleSeconds", default: 43200
    t.integer "MaxSessionSeconds", default: 86400
    t.string "SSHLocalForwards", default: ["*:*"], array: true
    t.string "SSHRemoteForwards", default: ["*:*"], array: true
    t.boolean "SSHTcpForwardSsh", default: true
    t.bigint "client_auth_set_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.bigint "partition_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["client_auth_set_id"], name: "index_bastion_profiles_on_client_auth_set_id"
    t.index ["name"], name: "index_bastion_profiles_on_name"
    t.index ["partition_id"], name: "index_bastion_profiles_on_partition_id"
  end

  create_table "bastions", force: :cascade do |t|
    t.boolean "active", default: true
    t.bigint "bastion_profile_id"
    t.datetime "created_at", precision: nil, null: false
    t.integer "debug_level", default: 0
    t.string "description"
    t.datetime "first_use_at", precision: nil
    t.datetime "last_use_at", precision: nil
    t.string "name"
    t.bigint "partition_id"
    t.integer "position"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "use_count", default: 0
    t.index ["bastion_profile_id"], name: "index_bastions_on_bastion_profile_id"
    t.index ["partition_id"], name: "index_bastions_on_partition_id"
  end

  create_table "bastions_proxies", force: :cascade do |t|
    t.bigint "bastion_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "proxy_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["bastion_id", "proxy_id"], name: "index_bastions_proxies_on_bastion_id_and_proxy_id", unique: true
  end

  create_table "bastions_source_ips", force: :cascade do |t|
    t.bigint "bastion_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "source_ip_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["bastion_id", "source_ip_id"], name: "index_bastions_source_ips_on_bastion_id_and_source_ip_id", unique: true
  end

  create_table "bastions_susshi_users", force: :cascade do |t|
    t.bigint "bastion_id"
    t.datetime "created_at", precision: nil, null: false
    t.bigint "susshi_user_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["bastion_id", "susshi_user_id"], name: "index_bastions_susshi_users_on_bastion_id_and_susshi_user_id", unique: true
  end

  create_table "binary_stores", force: :cascade do |t|
    t.bigint "attached_id"
    t.string "attached_type"
    t.datetime "created_at", precision: nil, null: false
    t.binary "data"
    t.string "format"
    t.string "kind"
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["attached_id"], name: "index_binary_stores_on_attached_id"
    t.index ["attached_type"], name: "index_binary_stores_on_attached_type"
    t.index ["kind"], name: "index_binary_stores_on_kind"
  end

  create_table "client_auth_sets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "name"
    t.integer "partition_id"
    t.jsonb "properties", default: {}
    t.boolean "system_int", default: false
    t.datetime "updated_at", null: false
  end

  create_table "client_auths", force: :cascade do |t|
    t.string "category"
    t.bigint "client_auth_set_id"
    t.datetime "created_at", null: false
    t.jsonb "properties", default: {}
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["client_auth_set_id"], name: "index_client_auths_on_client_auth_set_id"
  end

  create_table "gateways", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "listen_addresses", default: [], array: true
    t.string "name"
    t.integer "partition_id"
    t.string "sic_host"
    t.integer "sic_port"
    t.string "sic_psk"
    t.string "ssl_client_fingerprint"
    t.string "susshid_identifier"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["partition_id"], name: "index_gateways_on_partition_id"
    t.index ["susshid_identifier"], name: "index_gateways_on_susshid_identifier"
  end

  create_table "old_passwords", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "encrypted_password", null: false
    t.integer "password_archivable_id", null: false
    t.string "password_archivable_type", null: false
    t.string "password_salt"
    t.index ["password_archivable_id"], name: "index_old_passwords_on_password_archivable_id"
    t.index ["password_archivable_type"], name: "index_old_passwords_on_password_archivable_type"
  end

  create_table "partition_keys", id: :serial, force: :cascade do |t|
    t.boolean "active", default: true
    t.integer "bits"
    t.datetime "created_at", precision: nil, null: false
    t.string "fingerprint"
    t.string "key_type"
    t.integer "order"
    t.integer "partition_id"
    t.text "private_blob"
    t.integer "proxy_id"
    t.text "public_blob"
    t.string "source"
    t.string "title"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["partition_id"], name: "index_partition_keys_on_partition_id"
  end

  create_table "partition_settings", id: :serial, force: :cascade do |t|
    t.string "AddressFamily", default: "any"
    t.text "AllowedUserKeyTypes", default: ["ssh-rsa:1024", "ssh-rsa:2048", "ssh-rsa:3072", "ssh-rsa:4096", "ssh-ed25519:256", "ecdsa-sha2-nistp256:256", "ecdsa-sha2-nistp384:384", "ecdsa-sha2-nistp521:521"], array: true
    t.string "AuditLogFile", default: "/var/log/susshi/audit/%y/%m/%d/%t/%u-%s.%f"
    t.text "Banner", default: "Welcome to suSSHi2 Gateway"
    t.integer "BlockAuthSeconds", default: 900, null: false
    t.jsonb "ChefServerUrls", default: {}
    t.text "ClientCiphers", default: ["aes256-ctr", "aes256-cbc", "aes192-ctr", "aes192-cbc"], array: true
    t.boolean "ClientCompression", default: true
    t.text "ClientHmacs", default: ["hmac-sha2-512-etm@openssh.com", "hmac-sha2-256-etm@openssh.com", "hmac-sha1-etm@openssh.com", "hmac-sha2-512", "hmac-sha2-256", "hmac-sha1"], array: true
    t.boolean "ClientHostKeyUpdate", default: false
    t.text "ClientHostkeyAlgorithms", default: ["ssh-ed25519", "ecdsa-sha2-nistp521", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp256", "rsa-sha2-512", "rsa-sha2-256", "ssh-rsa"], array: true
    t.text "ClientKexAlgorithms", default: ["curve25519-sha256", "curve25519-sha256@libssh.org", "ecdh-sha2-nistp521", "ecdh-sha2-nistp384", "ecdh-sha2-nistp256", "diffie-hellman-group18-sha512", "diffie-hellman-group16-sha512", "diffie-hellman-group14-sha256", "diffie-hellman-group-exchange-sha256", "diffie-hellman-group14-sha1", "diffie-hellman-group1-sha1"], array: true
    t.boolean "ClientTcpKeepalive", default: true
    t.text "DenyTargetAddresses", default: ["127.0.0.0/8", "172.17.0.0/16", "::1", "fe80::/10"], array: true
    t.text "DnsSearchDomains", default: [], array: true
    t.integer "EmbryonicGraceTime", default: 10
    t.integer "ExecLogFileMaxsize"
    t.text "ExecLogStopPatterns", default: [], array: true
    t.text "GatewayAddresses", default: ["0.0.0.0/0", "::/0"], array: true
    t.text "ListenAddresses", default: [], array: true
    t.integer "ListenPorts", default: [22], array: true
    t.integer "LoginGraceTime", default: 120
    t.integer "MaxAuthFails", default: 5, null: false
    t.integer "MaxEmbryonics_max", default: 100
    t.integer "MaxEmbryonics_rate", default: 10
    t.integer "MaxEmbryonics_start", default: 30
    t.string "PasswordSplitString", default: "::@::"
    t.text "PreferredAuthentications", default: ["publickey", "keyboard-interactive", "password"], array: true
    t.boolean "PreserveClientBanner", default: false
    t.text "PublicKeyAlgorithms", default: ["ssh-ed25519", "ecdsa-sha2-nistp521", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp256", "rsa-sha2-512", "rsa-sha2-256", "ssh-rsa"], array: true
    t.integer "ReportPeriod", default: 900
    t.string "SessionLogFacility", default: "auth"
    t.string "SessionLogFile", default: "/var/log/susshi/sessions/%y/%m/%d/%t/%u-%s.log"
    t.string "SystemLogFacility", default: "auth"
    t.string "SystemLogFile", default: "/var/log/susshi/system/%y/%m/%d/system.log"
    t.text "TargetCiphers", default: ["aes256-ctr", "aes256-cbc", "aes192-ctr", "aes192-cbc", "aes128-ctr", "aes128-cbc", "blowfish-cbc"], array: true
    t.boolean "TargetCompression", default: true
    t.integer "TargetConnectionTimeout", default: 20
    t.text "TargetHmacs", default: ["hmac-sha2-512-etm@openssh.com", "hmac-sha2-256-etm@openssh.com", "hmac-sha1-etm@openssh.com", "hmac-sha2-512", "hmac-sha2-256", "hmac-sha1"], array: true
    t.text "TargetHostkeyAlgorithms", default: ["ssh-ed25519", "ecdsa-sha2-nistp521", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp256", "rsa-sha2-512", "rsa-sha2-256", "ssh-rsa"], array: true
    t.text "TargetKexAlgorithms", default: ["curve25519-sha256", "curve25519-sha256@libssh.org", "ecdh-sha2-nistp521", "ecdh-sha2-nistp384", "ecdh-sha2-nistp256", "diffie-hellman-group18-sha512", "diffie-hellman-group16-sha512", "diffie-hellman-group14-sha256", "diffie-hellman-group-exchange-sha256", "diffie-hellman-group14-sha1", "diffie-hellman-group1-sha1"], array: true
    t.boolean "TargetPassSusshiInformation", default: true
    t.string "TargetPreferredAddressFamily", default: "any"
    t.text "TargetPreferredAuthentications", default: ["publickey", "keyboard-interactive", "password"], array: true
    t.boolean "TargetTcpKeepAlive", default: true
    t.boolean "VerboseDisconnect", default: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "partition_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["partition_id"], name: "index_partition_settings_on_partition_id"
  end

  create_table "partitions", id: :serial, force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", precision: nil, null: false
    t.integer "current_swift_version", default: 1
    t.string "description"
    t.string "name"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_partitions_on_name"
  end

  create_table "partitions_users", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.integer "partition_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.index ["partition_id"], name: "index_partitions_users_on_partition_id"
    t.index ["user_id"], name: "index_partitions_users_on_user_id"
  end

  create_table "preferences", id: :serial, force: :cascade do |t|
    t.string "admin_auth_method", default: "password"
    t.string "admin_auth_realm", default: "suSSHi Chef"
    t.integer "certificate_index", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.integer "expire_password_after", default: 0
    t.boolean "flat_access_policies", default: false
    t.string "frontend_totp_issuer", default: "suSSHi"
    t.boolean "frontend_totp_show_on_ui", default: true
    t.string "installation_identifier"
    t.text "login_banner", default: "Login with your username and password."
    t.integer "max_idle_time", default: 3600
    t.integer "max_session_time", default: 28800
    t.integer "password_archiving_count", default: 0
    t.integer "password_length", default: 9
    t.integer "session_report_retention_days", default: 182
    t.text "smtp_settings"
    t.integer "syslog_port", default: 514
    t.string "syslog_proto", default: "udp"
    t.integer "syslog_retention_days", default: 30
    t.string "syslog_server1"
    t.string "syslog_server2"
    t.string "syslog_server3"
    t.string "syslog_server4"
    t.text "ui_ssl_client_cert_ca"
    t.string "ui_ssl_client_cert_cn_pattern", default: "^.*$"
    t.boolean "ui_ssl_client_cert_verify", default: false
    t.integer "ui_ssl_client_cert_verify_depth", default: 1
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "profiles", force: :cascade do |t|
    t.boolean "LogEncryption", default: true
    t.integer "LoggingMask", default: 65535
    t.integer "MaxSessionIdleSeconds", default: 43200
    t.integer "MaxSessionSeconds", default: 86400
    t.boolean "SSHAgentForward", default: true
    t.string "SSHCommandExecs", default: [".*"], array: true
    t.boolean "SSHInteractive", default: true
    t.string "SSHLocalForwards", default: ["localhost:*"], array: true
    t.string "SSHRemoteForwards", default: ["localhost:*"], array: true
    t.boolean "SSHSecureCopy", default: true
    t.boolean "SSHSecureFileTransfer", default: true
    t.string "SSHSessionSubsystems", default: [], array: true
    t.boolean "SSHSocketForward", default: true
    t.boolean "SSHTcpForwardSsh", default: true
    t.boolean "SSHX11Forward", default: true
    t.string "TargetHostKeyLearning", default: "never"
    t.string "TargetPassword"
    t.boolean "TargetPasswordCheckIdentity", default: false
    t.boolean "TargetPasswordContinue", default: false
    t.integer "TargetPasswordLength", default: 32
    t.string "TargetPasswordSource", default: "dialog"
    t.integer "TargetPasswordValidSeconds", default: 5
    t.text "TargetPreferredAuthentications", default: [], array: true
    t.string "TargetUser"
    t.bigint "client_auth_set_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.integer "partition_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["client_auth_set_id"], name: "index_profiles_on_client_auth_set_id"
    t.index ["name"], name: "index_profiles_on_name"
    t.index ["partition_id"], name: "index_profiles_on_partition_id"
  end

  create_table "proxies", force: :cascade do |t|
    t.text "comment"
    t.string "contact"
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "hostname"
    t.string "name"
    t.bigint "partition_id"
    t.integer "port", default: 22
    t.string "realm"
    t.datetime "updated_at", precision: nil, null: false
    t.boolean "use_individual_identities", default: true
    t.index ["partition_id"], name: "index_proxies_on_partition_id"
  end

  create_table "session_reports", force: :cascade do |t|
    t.integer "agent_accept"
    t.integer "agent_reject"
    t.integer "ch_accept"
    t.integer "ch_close"
    t.integer "ch_fail"
    t.integer "ch_reject"
    t.string "client_auth"
    t.boolean "client_comp"
    t.string "client_ip"
    t.integer "client_port"
    t.string "client_ssh"
    t.integer "cmd_accept"
    t.integer "cmd_reject"
    t.boolean "connect_used"
    t.boolean "crash", default: false
    t.datetime "created_at", precision: nil, null: false
    t.integer "int_accept"
    t.integer "int_reject"
    t.integer "lf_accept"
    t.integer "lf_reject"
    t.string "login_string"
    t.string "message"
    t.integer "operation_mode", default: 0
    t.integer "partition_id"
    t.string "profile_name"
    t.string "proxy_realm"
    t.integer "rf_accept"
    t.integer "rf_cancel"
    t.integer "rf_reject"
    t.bigint "rule_id"
    t.bigint "scp_bytes_rd"
    t.bigint "scp_bytes_wr"
    t.integer "scp_files_rd"
    t.integer "scp_files_wr"
    t.integer "scp_sessions"
    t.bigint "session_c_in"
    t.bigint "session_c_out"
    t.datetime "session_end", precision: nil
    t.datetime "session_start", precision: nil
    t.string "session_state"
    t.bigint "session_t_in"
    t.bigint "session_t_out"
    t.integer "session_time"
    t.bigint "sftp_bytes_rd"
    t.bigint "sftp_bytes_wr"
    t.integer "sftp_files_rd"
    t.integer "sftp_files_wr"
    t.integer "sftp_sessions"
    t.string "susshi_uniqid"
    t.string "susshi_user"
    t.string "target_auth"
    t.boolean "target_comp"
    t.string "target_host"
    t.string "target_ip"
    t.integer "target_port"
    t.string "target_ssh"
    t.string "target_user"
    t.integer "ti_reject"
    t.datetime "updated_at", precision: nil, null: false
    t.string "user_auth_fp"
    t.integer "usub_accept"
    t.integer "x11_accept"
    t.integer "x11_reject"
    t.index ["partition_id"], name: "index_session_reports_on_partition_id"
    t.index ["session_end"], name: "index_session_reports_on_session_end"
    t.index ["session_start"], name: "index_session_reports_on_session_start"
    t.index ["session_state"], name: "index_session_reports_on_session_state"
    t.index ["susshi_uniqid"], name: "index_session_reports_on_susshi_uniqid", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", precision: nil, null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "source_ip_memberships", force: :cascade do |t|
    t.bigint "source_ip_group_id"
    t.bigint "source_ip_net_id"
    t.index ["source_ip_net_id", "source_ip_group_id"], name: "index_source_ip_memberships_on_source_ip_net_and_group", unique: true
  end

  create_table "source_ips", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "ip_address"
    t.string "name"
    t.integer "partition_id"
    t.boolean "system_int", default: false
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version"
    t.index ["ip_address"], name: "index_source_ips_on_ip_address"
    t.index ["partition_id"], name: "index_source_ips_on_partition_id"
    t.index ["type"], name: "index_source_ips_on_type"
    t.index ["version"], name: "index_source_ips_on_version"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.datetime "activated_at", precision: nil
    t.datetime "created_at", null: false
    t.string "subscription_key"
    t.text "token"
    t.datetime "updated_at", null: false
  end

  create_table "susshi_user_keys", force: :cascade do |t|
    t.integer "bits"
    t.datetime "created_at", precision: nil, null: false
    t.string "fingerprint"
    t.string "key_type"
    t.text "public_blob"
    t.string "source"
    t.bigint "susshi_user_login_id"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["susshi_user_login_id"], name: "index_susshi_user_keys_on_susshi_user_login_id"
  end

  create_table "susshi_user_memberships", force: :cascade do |t|
    t.bigint "susshi_user_group_id"
    t.bigint "susshi_user_login_id"
    t.index ["susshi_user_group_id", "susshi_user_login_id"], name: "index_susshi_user_memberships_on_susshi_user_group_and_login", unique: true
  end

  create_table "susshi_users", force: :cascade do |t|
    t.boolean "ShellLogin", default: false
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, null: false
    t.string "email"
    t.datetime "first_use_at", precision: nil
    t.string "fullname"
    t.datetime "last_use_at", precision: nil
    t.string "name"
    t.integer "partition_id"
    t.string "password"
    t.jsonb "properties", default: {"totp_state" => "inactive"}
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.bigint "use_count", default: 0
    t.index ["name"], name: "index_susshi_users_on_name"
    t.index ["partition_id"], name: "index_susshi_users_on_partition_id"
  end

  create_table "swift_accesses", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "debug_level", default: 0
    t.integer "partition_id"
    t.integer "position"
    t.bigint "profile_id"
    t.bigint "source_ids", default: [], array: true
    t.index ["partition_id"], name: "index_swift_accesses_on_partition_id"
  end

  create_table "swift_auth_tickets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "issued_until", precision: nil
    t.jsonb "jwt", default: {}
    t.integer "partition_id", null: false
    t.string "secret"
    t.boolean "session_end_on_logout", default: false, null: false
    t.cidr "source_ip"
    t.integer "state", default: 0, null: false
    t.datetime "stored_until", precision: nil
    t.text "susshi_uniqids", default: [], array: true
    t.integer "susshi_user_id"
    t.string "ticket_match"
    t.datetime "updated_at", null: false
    t.index ["ticket_match"], name: "index_swift_auth_tickets_on_ticket_match", unique: true
  end

  create_table "swift_bastion_profiles", id: :serial, force: :cascade do |t|
    t.json "config", default: {}
    t.datetime "created_at", precision: nil
    t.integer "partition_id"
    t.index ["partition_id"], name: "index_swift_bastion_profiles_on_partition_id"
  end

  create_table "swift_bastions", id: :serial, force: :cascade do |t|
    t.integer "bastion_profile_id"
    t.datetime "created_at", precision: nil
    t.integer "debug_level", default: 0
    t.integer "partition_id"
    t.integer "position"
    t.integer "source_ids", default: [], array: true
    t.index ["partition_id"], name: "index_swift_bastions_on_partition_id"
  end

  create_table "swift_changes", force: :cascade do |t|
    t.text "change_trail", default: [], array: true
    t.datetime "created_at", precision: nil, null: false
    t.string "klass"
    t.integer "partition_id"
    t.bigint "swift_version"
    t.datetime "updated_at", precision: nil, null: false
    t.string "whodunit"
    t.index ["swift_version"], name: "index_swift_changes_on_swift_version"
    t.index ["whodunit"], name: "index_swift_changes_on_whodunit"
  end

  create_table "swift_client_auth_sets", force: :cascade do |t|
    t.jsonb "cache_properties", default: {}
    t.jsonb "interactive_auth_properties", default: {}
    t.bigint "partition_id"
    t.string "preferred_auths", default: [], array: true
    t.jsonb "publickey_auth_properties", default: {}
    t.string "required_auths", default: [], array: true
    t.string "required_auths_cached", default: [], array: true
    t.index ["partition_id"], name: "index_swift_client_auth_sets_on_partition_id"
  end

  create_table "swift_domain_hosts", primary_key: "target_id", force: :cascade do |t|
    t.string "name"
    t.integer "partition_id"
    t.string "proxy_realm"
    t.jsonb "user_keys", default: {}
    t.index ["name"], name: "index_swift_domain_hosts_on_name"
    t.index ["partition_id"], name: "index_swift_domain_hosts_on_partition_id"
  end

  create_table "swift_dotp_tickets", force: :cascade do |t|
    t.integer "partition_id"
    t.string "susshi_uniqid"
    t.string "target_identity"
    t.string "target_password"
    t.string "target_user"
    t.datetime "valid_until", precision: nil
    t.index ["partition_id"], name: "index_swift_dotp_tickets_on_partition_id"
  end

  create_table "swift_gateways", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.boolean "has_target_fusions", default: false
    t.string "identifier"
    t.string "installation_id"
    t.string "listen_addresses", default: [], array: true
    t.string "name"
    t.integer "partition_id"
    t.text "sic_certificate"
    t.string "sic_host"
    t.text "sic_key"
    t.integer "sic_port"
    t.string "sic_psk"
    t.text "sic_ssh_private_key"
    t.text "sic_ssh_public_key"
    t.string "ssl_client_fingerprint"
    t.text "syslog_certificate"
    t.text "syslog_key"
    t.index ["identifier"], name: "index_swift_gateways_on_identifier"
    t.index ["partition_id"], name: "index_swift_gateways_on_partition_id"
  end

  create_table "swift_ip_cachings", force: :cascade do |t|
    t.bigint "client_auth_set_id", default: 0
    t.datetime "created_at", precision: nil, null: false
    t.cidr "source_ip"
    t.bigint "swift_susshi_user_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["source_ip"], name: "index_swift_ip_cachings_on_source_ip", using: :gin
    t.index ["swift_susshi_user_id"], name: "index_swift_ip_cachings_on_swift_susshi_user_id"
  end

  create_table "swift_network_hosts", primary_key: "target_id", force: :cascade do |t|
    t.string "address"
    t.integer "partition_id"
    t.string "proxy_realm"
    t.jsonb "user_keys", default: {}
    t.index ["address"], name: "index_swift_network_hosts_on_address"
    t.index ["partition_id"], name: "index_swift_network_hosts_on_partition_id"
  end

  create_table "swift_partitions", id: :serial, force: :cascade do |t|
    t.jsonb "config", default: {}
    t.datetime "created_at", precision: nil
    t.integer "partition_id"
    t.integer "version"
  end

  create_table "swift_profiles", force: :cascade do |t|
    t.jsonb "config", default: {}
    t.datetime "created_at", precision: nil
    t.integer "partition_id"
    t.index ["partition_id"], name: "index_swift_profiles_on_partition_id"
  end

  create_table "swift_proxies", force: :cascade do |t|
    t.integer "bastion_ids", default: [], array: true
    t.string "hostname"
    t.jsonb "identities", default: {}
    t.integer "partition_id"
    t.integer "port"
    t.string "realm"
    t.index ["partition_id"], name: "index_swift_proxies_on_partition_id"
    t.index ["realm"], name: "index_swift_proxies_on_realm"
  end

  create_table "swift_sources", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.cidr "ip"
    t.integer "partition_id"
    t.index ["ip"], name: "index_swift_sources_on_ip", using: :gin
    t.index ["partition_id"], name: "index_swift_sources_on_partition_id"
  end

  create_table "swift_susshi_users", force: :cascade do |t|
    t.bigint "access_ids", default: [], array: true
    t.integer "bastion_ids", default: [], array: true
    t.datetime "created_at", precision: nil
    t.jsonb "keys", default: {}
    t.string "name"
    t.integer "partition_id"
    t.string "password"
    t.jsonb "properties", default: {}
    t.boolean "shell_login"
    t.index ["name"], name: "index_swift_susshi_users_on_name"
    t.index ["partition_id"], name: "index_swift_susshi_users_on_partition_id"
  end

  create_table "swift_target_fusions", force: :cascade do |t|
    t.integer "access_ids", default: [], array: true
    t.datetime "created_at", precision: nil
    t.bigint "partition_id"
    t.bigint "target_id"
    t.bigint "target_user_id"
    t.index ["partition_id"], name: "index_swift_target_fusions_on_partition_id"
  end

  create_table "swift_target_user_mappings", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil
    t.integer "partition_id"
    t.jsonb "translations", default: []
    t.index ["access_id"], name: "index_swift_target_user_mappings_on_access_id"
    t.index ["partition_id"], name: "index_swift_target_user_mappings_on_partition_id"
  end

  create_table "swift_target_user_regexes", force: :cascade do |t|
    t.bigint "access_id"
    t.datetime "created_at", precision: nil
    t.integer "partition_id"
    t.jsonb "regexes", default: []
    t.index ["access_id"], name: "index_swift_target_user_regexes_on_access_id"
    t.index ["partition_id"], name: "index_swift_target_user_regexes_on_partition_id"
  end

  create_table "swift_target_users", force: :cascade do |t|
    t.bigint "access_ids", default: [], array: true
    t.datetime "created_at", precision: nil
    t.string "name"
    t.integer "partition_id"
    t.index ["name"], name: "index_swift_target_users_on_name"
    t.index ["partition_id"], name: "index_swift_target_users_on_partition_id"
  end

  create_table "swift_targets", force: :cascade do |t|
    t.bigint "access_ids", default: [], array: true
    t.datetime "created_at", precision: nil
    t.jsonb "keys", default: {}
    t.string "kind"
    t.integer "partition_id"
    t.string "proxy_realm"
    t.bigint "target_id"
    t.cidr "target_ip"
    t.string "target_name"
    t.jsonb "user_keys", default: {}
    t.index ["partition_id"], name: "index_swift_targets_on_partition_id"
    t.index ["target_ip"], name: "index_swift_targets_on_target_ip", using: :gin
    t.index ["target_name"], name: "index_swift_targets_on_target_name"
  end

  create_table "systemevents", force: :cascade do |t|
    t.integer "currusage"
    t.bigint "customerid"
    t.datetime "devicereportedtime", precision: nil
    t.text "eventbinarydata"
    t.integer "eventcategory"
    t.integer "eventid"
    t.string "eventlogtype"
    t.string "eventsource"
    t.string "eventuser"
    t.integer "facility"
    t.string "fromhost"
    t.string "genericfilename"
    t.integer "importance"
    t.integer "infounitid"
    t.integer "maxavailable"
    t.integer "maxusage"
    t.text "message"
    t.integer "minusage"
    t.integer "ntseverity"
    t.integer "priority"
    t.datetime "receivedat", precision: nil
    t.string "syslogtag"
    t.integer "systemid"
    t.index ["devicereportedtime"], name: "index_systemevents_on_devicereportedtime"
    t.index ["fromhost"], name: "index_systemevents_on_fromhost"
    t.index ["message"], name: "index_systemevents_on_message", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "systemeventsproperties", force: :cascade do |t|
    t.string "paramname"
    t.text "paramvalue"
    t.integer "systemeventid"
  end

  create_table "target_auth_keys", force: :cascade do |t|
    t.integer "bits"
    t.datetime "created_at", precision: nil, null: false
    t.string "fingerprint"
    t.string "key_type"
    t.integer "partition_id"
    t.text "private_blob"
    t.text "public_blob"
    t.string "source"
    t.bigint "susshi_user_id"
    t.string "title"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["partition_id"], name: "index_target_auth_keys_on_partition_id"
    t.index ["susshi_user_id"], name: "index_target_auth_keys_on_susshi_user_id"
  end

  create_table "target_fusion_memberships", force: :cascade do |t|
    t.bigint "target_fusion_group_id"
    t.bigint "target_fusion_link_id"
    t.index ["target_fusion_link_id", "target_fusion_group_id"], name: "index_target_fusion_memberships_on_fusion_link_and_group", unique: true
  end

  create_table "target_fusions", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.bigint "partition_id"
    t.bigint "target_id"
    t.bigint "target_user_id"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_target_fusions_on_name"
    t.index ["partition_id"], name: "index_target_fusions_on_partition_id"
    t.index ["target_id"], name: "index_target_fusions_on_target_id"
    t.index ["target_user_id"], name: "index_target_fusions_on_target_user_id"
    t.index ["type"], name: "index_target_fusions_on_type"
  end

  create_table "target_host_keys", force: :cascade do |t|
    t.integer "bits"
    t.datetime "created_at", precision: nil, null: false
    t.string "fingerprint"
    t.string "key_type"
    t.text "public_blob"
    t.string "source"
    t.bigint "susshi_user_login_id"
    t.bigint "target_id"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["target_id"], name: "index_target_host_keys_on_target_id"
  end

  create_table "target_memberships", force: :cascade do |t|
    t.bigint "target_group_id"
    t.bigint "target_id"
    t.index ["target_id", "target_group_id"], name: "index_target_memberships_on_target_id_and_target_group_id", unique: true
  end

  create_table "target_sockets", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "ip_address"
    t.integer "port_max"
    t.integer "port_min"
    t.string "port_range"
    t.bigint "target_host_id"
    t.datetime "updated_at", precision: nil, null: false
    t.integer "version"
    t.index ["ip_address"], name: "index_target_sockets_on_ip_address"
    t.index ["port_max"], name: "index_target_sockets_on_port_max"
    t.index ["port_min"], name: "index_target_sockets_on_port_min"
    t.index ["target_host_id"], name: "index_target_sockets_on_target_host_id"
    t.index ["version"], name: "index_target_sockets_on_version"
  end

  create_table "target_user_memberships", force: :cascade do |t|
    t.bigint "target_user_group_id"
    t.bigint "target_user_id"
    t.index ["target_user_id", "target_user_group_id"], name: "index_target_user_memberships_on_target_user_and_group", unique: true
  end

  create_table "target_users", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.integer "partition_id"
    t.string "regex"
    t.string "regex_effective"
    t.string "regex_target_user"
    t.boolean "system_int", default: false
    t.string "translate"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_target_users_on_name"
    t.index ["partition_id"], name: "index_target_users_on_partition_id"
    t.index ["regex_effective"], name: "index_target_users_on_regex_effective"
    t.index ["type"], name: "index_target_users_on_type"
  end

  create_table "targets", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", precision: nil, null: false
    t.string "description"
    t.string "name"
    t.integer "partition_id"
    t.bigint "proxy_id"
    t.string "type"
    t.datetime "updated_at", precision: nil, null: false
    t.index ["name"], name: "index_targets_on_name"
    t.index ["partition_id"], name: "index_targets_on_partition_id"
    t.index ["proxy_id"], name: "index_targets_on_proxy_id"
    t.index ["type"], name: "index_targets_on_type"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.boolean "active"
    t.text "comment"
    t.datetime "confirmation_sent_at", precision: nil
    t.string "confirmation_token"
    t.datetime "confirmed_at", precision: nil
    t.integer "consumed_timestep"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.string "current_sign_in_ip"
    t.integer "default_partition_id"
    t.string "description"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "expired_at", precision: nil
    t.integer "failed_attempts", default: 0
    t.string "fullname"
    t.datetime "last_activity_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "last_sign_in_ip"
    t.boolean "lek_self_service", default: false
    t.datetime "locked_at", precision: nil
    t.string "log_encryption_key"
    t.string "otp_activation_token"
    t.boolean "otp_required_for_login"
    t.string "otp_secret"
    t.datetime "password_changed_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.string "role"
    t.integer "sign_in_count", default: 0
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", precision: nil, null: false
    t.string "username"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["id"], name: "index_users_on_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  create_table "versions", id: :serial, force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.string "meta_state"
    t.string "meta_susshid_ids", default: [], array: true
    t.text "object"
    t.string "object_changes"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "accesses", "partitions"
  add_foreign_key "accesses", "profiles"
  add_foreign_key "accesses_source_ips", "accesses"
  add_foreign_key "accesses_source_ips", "source_ips"
  add_foreign_key "accesses_susshi_users", "accesses"
  add_foreign_key "accesses_susshi_users", "susshi_users"
  add_foreign_key "accesses_target_fusions", "accesses"
  add_foreign_key "accesses_target_fusions", "target_fusions"
  add_foreign_key "accesses_target_users", "accesses"
  add_foreign_key "accesses_target_users", "target_users"
  add_foreign_key "accesses_targets", "accesses"
  add_foreign_key "accesses_targets", "targets"
  add_foreign_key "api_tokens", "partitions"
  add_foreign_key "bastion_profiles", "client_auth_sets"
  add_foreign_key "bastion_profiles", "partitions"
  add_foreign_key "bastions", "bastion_profiles"
  add_foreign_key "bastions", "partitions"
  add_foreign_key "bastions_proxies", "bastions"
  add_foreign_key "bastions_proxies", "proxies"
  add_foreign_key "bastions_source_ips", "bastions"
  add_foreign_key "bastions_source_ips", "source_ips"
  add_foreign_key "bastions_susshi_users", "bastions"
  add_foreign_key "bastions_susshi_users", "susshi_users"
  add_foreign_key "client_auths", "client_auth_sets"
  add_foreign_key "gateways", "partitions"
  add_foreign_key "partition_keys", "partitions"
  add_foreign_key "partition_settings", "partitions"
  add_foreign_key "partitions_users", "partitions"
  add_foreign_key "partitions_users", "users"
  add_foreign_key "profiles", "client_auth_sets"
  add_foreign_key "profiles", "partitions"
  add_foreign_key "proxies", "partitions"
  add_foreign_key "session_reports", "partitions"
  add_foreign_key "source_ip_memberships", "source_ips", column: "source_ip_group_id"
  add_foreign_key "source_ip_memberships", "source_ips", column: "source_ip_net_id"
  add_foreign_key "source_ips", "partitions"
  add_foreign_key "susshi_user_keys", "susshi_users", column: "susshi_user_login_id"
  add_foreign_key "susshi_user_memberships", "susshi_users", column: "susshi_user_group_id"
  add_foreign_key "susshi_user_memberships", "susshi_users", column: "susshi_user_login_id"
  add_foreign_key "susshi_users", "partitions"
  add_foreign_key "target_auth_keys", "partitions"
  add_foreign_key "target_auth_keys", "susshi_users"
  add_foreign_key "target_fusion_memberships", "target_fusions", column: "target_fusion_group_id"
  add_foreign_key "target_fusion_memberships", "target_fusions", column: "target_fusion_link_id"
  add_foreign_key "target_fusions", "partitions"
  add_foreign_key "target_fusions", "target_users"
  add_foreign_key "target_fusions", "targets"
  add_foreign_key "target_host_keys", "targets"
  add_foreign_key "target_memberships", "targets"
  add_foreign_key "target_memberships", "targets", column: "target_group_id"
  add_foreign_key "target_sockets", "targets", column: "target_host_id"
  add_foreign_key "target_user_memberships", "target_users"
  add_foreign_key "target_user_memberships", "target_users", column: "target_user_group_id"
  add_foreign_key "target_users", "partitions"
  add_foreign_key "targets", "partitions"
  add_foreign_key "targets", "proxies"
end
