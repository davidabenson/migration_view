module MigrationView
  class SchemaMigrationsViews < ActiveRecord::Base

    self.table_name = "schema_migrations_views"

    #self.primary_key = :version

  end
end
