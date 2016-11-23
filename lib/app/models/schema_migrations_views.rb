module MigrationView
  class SchemaMigrationsViews < ActiveRecord::Base
    #attr_accessor :run_always

    self.table_name = "schema_migrations_views"

    self.primary_key = :version

  end
end
