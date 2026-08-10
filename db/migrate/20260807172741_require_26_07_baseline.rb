class Require2607Baseline < ActiveRecord::Migration[8.1]
  # All migrations up to and including this version shipped in release 26.07
  # and have been removed from db/migrate (see db/schema.rb and the 26.07 tag
  # for the full history). 26.07 is therefore a mandatory intermediate
  # upgrade for any installation older than 26.08.
  CUTOFF_VERSION = "20260708063113"

  def up
    applied_versions = select_values("SELECT version FROM schema_migrations")

    unless applied_versions.include?(CUTOFF_VERSION)
      raise "suSSHi Chef 26.08 requires an installation already upgraded to 26.07 " \
            "(migration history before version #{CUTOFF_VERSION} has been removed). " \
            "Upgrade to 26.07 first, then upgrade to 26.08."
    end
  end

  def down
    fail ActiveRecord::IrreversibleMigration
  end
end
