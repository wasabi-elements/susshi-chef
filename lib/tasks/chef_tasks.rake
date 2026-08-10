namespace :chef do

  ADMIN_USER_DEFAULTS = {
    username: "admin",
    fullname: "Administrator",
    email: "admin@susshi.io",
    password: "ChangeMe&1234",
    password_confirmation: "ChangeMe&1234",
    password_changed_at: nil,
    role: "super"
  }

  DB_BACKUP_DIR = "#{Rails.root}/backups"

  task create_preference: :environment do
    if Preference.none?
      Preference.create!(installation_identifier: ENV["INSTALLATION_IDENTIFIER"].presence || SecureRandom.uuid)
    end
  end

  task create_certificates: :environment do
    if Preference.any?
      unless Preference.first.sic_ca_certificate
        SSL::Sic.create_sic_ca
      end

      unless Preference.first.sic_api_certificate
        SSL::Sic.create_sic_api_certificate
      end

      unless Preference.first.alt_server_certificate
        SSL::Server.create_alt_server_key_cert
      end

      Gateway.all.each do |gateway|
        if %w[sic_psk sic_certificate sic_ssh_private_key syslog_certificate].any? { |m| gateway.send(m).blank? }
          gateway.save
        end
      end
    end
  end

  task create_admin_user: :environment do
    if User.none?
      User.create!(ADMIN_USER_DEFAULTS)

      puts <<~EOM
        => Created an initial administrative user '#{ADMIN_USER_DEFAULTS[:username]}' with password '#{ADMIN_USER_DEFAULTS[:password]}'.
        =>   * Please change the password immediately.
      EOM
    end
  end

  task create_partition: :environment do
    Partition.create!(name: "The Partition", users: [User.first]) if Partition.none? && User.one?
  end

  desc "Reset Admin User"
  task reset_admin_user: :environment do |task|
    puts "=> *** #{task.comment} ***"

    if (admin = User.find_by_username(ADMIN_USER_DEFAULTS[:username])).blank?
      admin = User.new(ADMIN_USER_DEFAULTS)
      admin.save!(validate: false)

      puts <<~EOM
        => Created an initial administrative user '#{ADMIN_USER_DEFAULTS[:username]}' with password '#{ADMIN_USER_DEFAULTS[:password]}'.
        =>   * Please change the password immediately.
      EOM
    else
      admin.update(ADMIN_USER_DEFAULTS.slice(:password, :password_confirmation, :role, :password_changed_at))
      admin.save(validate: false)

      puts <<~EOM
        => Password for administrative user '#{ADMIN_USER_DEFAULTS[:username]}' has been restored to default '#{ADMIN_USER_DEFAULTS[:password]}'.
        =>   * Please change the password immediately.
        => Role for administrative user '#{ADMIN_USER_DEFAULTS[:username]}' has been restored to 'Super-Admin'.
      EOM
    end

    if Preference.first.otp_active?
      admin = User.find_by_username("admin")
      admin.enable_otp

      puts <<~EOM
        => Your setup is configured for OTP, so OTP secret for '#{ADMIN_USER_DEFAULTS[:username]}' has been reset, too.
        =>   * Please activate OTP with new OTP activation token: #{admin.otp_activation_token}.
      EOM
    end

  end

  desc "Disable SSL Client Certificate Verification"
  task ssl_client_cert_off: :environment do |task|
    if Preference.any?
      puts "=> *** #{task.comment} ***"

      Preference.first.update_columns(ui_ssl_client_cert_verify: false)

      puts <<~EOM
        => Successfully switched off SSL Client Certificate verification.
        =>   * Please restart suSSHi Chef to activate the change.
      EOM
    end
  end

  task export_certificates: :environment do
    NGINX.export_certificates
  end

  task export_ssl_cc_config: :environment do
    NGINX.export_ssl_cc_config
  end

  task startup_rsyslog: :environment do
    Rsyslog::Daemon.startup
  end

  desc "Purge Session Reports and System Events"
  task purge_logs_and_reports: :environment do
    LogRetention.purge_session_reports
    LogRetention.purge_system_events
  end

  desc "Setup Chef - Database Schema Only"
  task db_setup: :environment do |task|
    with_database_lock(task.name) do
      begin
        ActiveRecord::Base.connection
      rescue
        puts "=> suSSHi Chef database does not exist..."

        Rake::Task["db:create"].invoke
      end

      run_migrations
    end
  end

  desc "Setup Chef - Database and Content"
  task setup: [:db_setup, :create_preference, :create_certificates, :export_certificates, :export_ssl_cc_config, :startup_rsyslog, :create_admin_user, :create_partition] do
    # This will run after all those tasks have run
  end

  desc "Create a backup of the database and store it in #{DB_BACKUP_DIR}"
  task backup_db: :environment do |task|
    puts "=> *** #{task.comment} ***"

    create_db_backup
  end

  desc "Restores the database backup from #{DB_BACKUP_DIR}/<file> of running suSSHi Chef version"
  task restore_db: :environment do |task|
    puts "=> *** #{task.comment} ***"

    restore_db_backup
  end

  desc "List available database backups in #{DB_BACKUP_DIR}"
  task backup_db_list: :environment do |task|
    puts "=> *** #{task.comment} ***"

    files = Dir.entries(DB_BACKUP_DIR).select { |f| f =~ /#{db_backup_prefix}.*\.backup/ }
    if files.any?
      puts "=> Existing database backups for current version #{CHEF_CONFIG["version"]}:"

      files.sort { |x,y| x <=> y }.each { |f| puts "=>  * #{f}" }
    else
      puts "=> There are no database backups for current version #{CHEF_CONFIG["version"]}."
    end
  end

  desc "Garbage Collect Swift IP Caching and DOTP Tickets"
  task garbage_ip_caching: :environment do
    SwiftIpCaching.garbage_collect(ENV["CACHE_MAX_TIME"])
    SwiftDotpTicket.garbage_collect
  end

  desc "Clear usage statistics of Accesses"
  task clear_accesses_statistics: :environment do
    Access.clear_statistics
    Bastion.clear_statistics
  end

  desc "Clear usage statistics of Login Users"
  task clear_users_statistics: :environment do
    SusshiUserLogin.clear_statistics
  end

  desc "Clear usage statistics of Login Users and Accesses"
  task clear_all_statistics: :environment do
    SusshiUserLogin.clear_statistics
    Access.clear_statistics
    Bastion.clear_statistics
  end

  desc "Renew SIC Certificates"
  task renew_sic_certificates: :environment do |task|
    puts "=> *** #{task.comment} ***"

    with_database_lock(task.name, model: Gateway) do
      enforce = %[true 1].include?(ENV.fetch("enforce", false).to_s)
      Gateway.renew_sic_certificates(enforce:)
    end
  end

  private

  def db_backup_prefix
    "susshi-chef_backup_#{CHEF_CONFIG['version']}_"
  end

  def run_migrations
    connection = ActiveRecord::Base.connection

    if connection.data_sources.none?
      # Seems to be a new installation
      puts "=> Setting up a new database..."

      Rake::Task["db:schema:load"].invoke
      Rake::Task["db:schema:load"].reenable
    else
      # Seems to be an existing installation
      migration_context = connection.pool.migration_context

      pending_migrations = migration_context.migrations_status.each_with_object({}) do |migrations_status, hash|
        status, timestamp, description = migrations_status
        hash[timestamp] = description if status == "down"
      end

      if pending_migrations.any?
        # Seems to have pending migrations
        puts "=> Running #{pending_migrations.size} pending #{"migrations".pluralize(pending_migrations.size)}..."

        invoke_migrations(pending_migrations)
      end
    end
  end

  def invoke_migrations(pendings)
    return if pendings.blank?

    # create_db_backup
    successful = []

    begin
      pendings.each do |version, _|
        ENV["VERSION"] = version

        Rake::Task["db:migrate:up"].invoke
        Rake::Task["db:migrate:up"].reenable

        successful << version
      end
    rescue => e
      puts <<~EOM
        => #{"/\\" * 40}
        => An ERROR has occurred during database migration:
        => -------------------------------------------------------------------------------
        => #{e.message}
        => -------------------------------------------------------------------------------
        => Reverting all changes to the state before update...
        => #{"/\\" * 40}
      EOM

      successful.each do |version|
        ENV["VERSION"] = version

        Rake::Task["db:migrate:down"].invoke
        Rake::Task["db:migrate:down"].reenable
      end

      puts <<~EOM
        => #{"/\\" * 40}
        => -------------------------------------------------------------------------------
        => All changes have been reverted to the state before software update.
        => Please collect all output for a technical support case and continue using the 
        => version you have been using before.
        => -------------------------------------------------------------------------------
        => #{"/\\" * 40}
      EOM

      raise "Migration Error"
    end
  end

  def create_db_backup
    db_config = ActiveRecord::Base.connection_db_config.configuration_hash

    backup_basename = "#{db_backup_prefix}#{Time.now.strftime '%Y%m%d-%H%M%S'}"

    pg_dump_params = %w[--verbose --clean --no-owner --no-acl --format=c]
    pg_dump_params << "--host #{db_config[:host]}" unless db_config[:host].blank?
    pg_dump_params << "--port #{db_config[:port]}" unless db_config[:port].blank?
    pg_dump_params << "--username #{db_config[:username]}" unless db_config[:username].blank?
    pg_dump_params << %w[sessions].map { |t| "--exclude-table-data #{t}" }.join(" ")

    pg_dump = "pg_dump #{pg_dump_params.join(' ')} #{db_config[:database]} > #{DB_BACKUP_DIR}/#{backup_basename}.backup 2> #{DB_BACKUP_DIR}/#{backup_basename}.log"

    if system({"PGPASSWORD" => db_config[:password]}, pg_dump)
      puts "=> Backup completed successful."
    else
      File.delete "#{DB_BACKUP_DIR}/#{backup_basename}.backup" if File.exist? "#{DB_BACKUP_DIR}/#{backup_basename}.backup"
      puts File.read "#{DB_BACKUP_DIR}/#{backup_basename}.log" rescue nil
      puts "=> Backup failed."
      exit 1
    end
  end

  def restore_db_backup
    if ENV["file"].blank?
      puts "=> Please specify a filename by running 'rake chef:restore_db file=<backup_file_without_path>'"
      exit 1
    else
      backup_file = "#{DB_BACKUP_DIR}/#{ENV['file']}"

      if File.exist? backup_file
        if backup_file =~ /#{db_backup_prefix}.*/
          db_config = ActiveRecord::Base.connection_db_config.configuration_hash

          pg_dump_params = %w[--verbose --clean --no-owner --no-acl]
          pg_dump_params << "--host #{db_config[:host]}" unless db_config[:host].blank?
          pg_dump_params << "--port #{db_config[:port]}" unless db_config[:port].blank?
          pg_dump_params << "--username #{db_config[:username]}" unless db_config[:username].blank?
          pg_restore = "pg_restore #{pg_dump_params.join(' ')} --dbname #{db_config[:database]} #{backup_file} 2> #{backup_file.gsub(/\.backup$/, '_restore.log')}"

          if system({"PGPASSWORD" => db_config[:password]}, pg_restore)
            puts "=> Restored database backup successful."
          else
            puts File.read "#{backup_file.gsub(/\.backup$/, '_restore.log')}" rescue nil
            puts "=> Restore of database backup failed."
            exit 1
          end
        else
          puts "=> The database backup is not created with the current version of suSSHi Chef and therefore cannot be restored."
          exit 1
        end
      else
        puts "=> Could not find backup file."
        exit 1
      end
    end
  end

  def with_database_lock(lock_id, model: ActiveRecord::Base, &block)
    result = model.with_advisory_lock_result(lock_id, timeout_seconds: 0) do
      yield block
    end

    puts "=> Could not acquire lock, another process seems to be in progress." unless result.lock_was_acquired?

    result.lock_was_acquired?
  end

end
