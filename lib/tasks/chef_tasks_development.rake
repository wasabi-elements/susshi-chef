namespace :chef_dev do
  require "rake"

  if Rails.env.development?
    require "gem-licenses"
    Gem::GemLicenses.install_tasks
  end

  apib_complete_file = "#{Rails.root}/doc/api/config/complete.apib"
  apib_index_file = "#{Rails.root}/doc/api/config/index.apib"

  desc "Recreate Config API Manual and Postman Collection from Blueprint API documents"
  task create_manual_and_collection: [:create_api_manual, :create_postman_collection] do
  end

  desc "Cleanup API Blueprint temporary files"
  task :cleanup_api_blueprint_tmp_files do |t|
    system "rm -f #{apib_complete_file}"

    unless $?.exitstatus == 0
      raise "Recreation of Config API Manual from API Blueprint documents failed."
    end
  end

  desc "Recreate API Manual from API Blueprint documents"
  task :create_api_manual do |t|
    require 'mkmf'

    unless find_executable 'aglio'
      raise 'aglio not found (install with npm install -g aglio, npm can be install with brew install npm).'
    end

    system "aglio -n #{Rails.root}/doc/api/config -i #{Rails.root}/doc/api/config/index.apib -o #{Rails.root}/public/api_manual.html --theme-full-width --theme-template triple"

    unless $?.exitstatus == 0
      raise "Recreation of API Manual from API Blueprint documents failed."
    end
  end

  desc "Convert API Blueprint to JSON schema"
  task :convert_api_manual_to_json do |t|
    Rake::Task["chef_dev:merge_api_blueprint_files"].invoke
    system "docker run --platform linux/amd64 --rm -i slimapi/apib2json --pretty < #{apib_complete_file} > /tmp/schema.json"

    unless $?.exitstatus == 0
      raise "Converting API Blueprint to JSON schema failed."
    end

    Rake::Task["chef_dev:cleanup_api_blueprint_tmp_files"].invoke
  end

  desc "Merge API Blueprint files"
  task :merge_api_blueprint_files do
    unless File.exist? apib_index_file
      raise "#{apib_index_file} not found, creation of Postman Collection from API Blueprint documents failed."
    end

    s = File.open(apib_index_file, "r").read
    s.scan(/^<!--\sinclude\((.*)\)\s-->$/).flatten.each do |x|
      path = "#{Rails.root}/doc/api/config/#{x}"

      unless File.exist? path
        raise "#{path} (to include) not found, creation of Postman Collection from API Blueprint documents failed."
      end

      s.gsub!("<!-- include(#{x}) -->", File.open(path).read)
    end

    File.open(apib_complete_file, 'w') { |f| f.write s }
  end

  desc "Create Postman Collection from API Blueprint documents"
  task :create_postman_collection do
    Rake::Task["chef_dev:merge_api_blueprint_files"].invoke

    unless File.exist? apib_complete_file
      raise "#{apib_complete_file} not found, creation of Postman Collection from API Blueprint documents failed."
    end

    collection_file = "#{Rails.root}/public/pm_collection.json"
    vanadia_config_file = "#{Rails.root}/doc/api/config/vanadia.yml"

    unless File.exist? apib_index_file
      raise "#{apib_index_file} not found, creation of Postman Collection from API Blueprint documents failed."
    end

    system "docker run --rm --platform linux/amd64 -v #{Rails.root}:#{Rails.root} registry.intra.rnetx.com/rnx/docker-images/vanadia --input #{apib_complete_file} --output #{collection_file} --config #{vanadia_config_file}"

    unless $?.exitstatus == 0
      raise "vanadia cannot create collection, creation of Postman Collection from API Blueprint documents failed."
    end

    Rake::Task["chef_dev:cleanup_api_blueprint_tmp_files"].invoke
  end

  desc "Export Gems licenses as CSV"
  task :export_gem_licenses do
    csv_separator = ENV["CSV_SEPARATOR"] || ","

    static_licenses = {
      "bootstrap_form" => ["MIT"],
      "cancan" => ["MIT"],
      "country-select" => ["MIT"],
      "range_operators" => ["MIT"],
      "ruby-radius" => ["GNU Lesser General Public"],
      "susshi_helpers" => ["Nonstandard"]
    }

    Gem.loaded_specs.sort_by { |name, _| name }.each do |name, spec|
      licenses = spec.licenses.blank? ? static_licenses[name] : spec.licenses

      puts [
        name,
        spec.homepage || "https://rubygems.org",
        spec.version,
        "\"#{licenses.join(", ")}\""
      ].join(csv_separator)
    end
  end

  desc "Data Masking"
  task db_data_masking: :environment do
    puts "*** Data Masking ***"

    puts "=> Disable admin OTP"
    Preference.first.update(admin_auth_method: 'password')

    puts "=> Delete admin users"
    User.destroy_all

    puts "=> Create default admin user (#{ADMIN_USER_DEFAULTS[:username]} / #{ADMIN_USER_DEFAULTS[:password]})"
    User.create!(ADMIN_USER_DEFAULTS)
    User.update(partitions: Partition.all)

    puts "=> Mask SusshiUserLogins and reset TOTP attributes"
    SusshiUserLogin.where.not(username: ENV["USER"]).each do |user|
      user.update(
        fullname: Faker::Name.unique.name,
        name: Faker::Internet.unique.username(specifier: 8..16, separators: %w[. _ -]),
        email: Faker::Internet.unique.email,
        password: nil
      )

      user.deactivate_totp!
    end

    puts "=> Modify AccessProfiles having a static target password"
    Profile.where.not(TargetPassword: nil).update_all(TargetPassword: nil)

    puts "=> Modify PartitionHostKeys, PartitionAuthKeys and ProxyAuthKeys"
    [PartitionHostKey, PartitionAuthKey, ProxyAuthKey].each do |model|
      model.all.each do |key|
        key.destroy!
        model.create!(partition: key.partition, title: key.title, key_type: key.key_type, bits: key.bits)
      end
    end

    puts "=> Activate pending SwiftChanges"
    Partition.find(SusshiUserLogin.all.pluck(:partition_id).uniq).each do |partition|
      Access.activate(partition, "Rake Task",["Activated by Rake Task (System)"])
    end

    puts "=> Delete SwiftChanges and SessionReports"
    SwiftChange.destroy_all
    SessionReport.destroy_all
  end
end
