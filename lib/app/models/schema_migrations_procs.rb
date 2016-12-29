module MigrationView
  class SchemaMigrationsProcs < ActiveRecord::Base

    self.table_name = "schema_migrations_procs"

    #self.primary_key = :version


    def self.get_single_value(sql)
      value = nil
      type = MigrationView.database_type()
      case type
        when 'MYSQL'
          value = SchemaMigrationsProcs.connection.execute(sql).first[0]
        when 'PSQL'
          value = SchemaMigrationsProcs.connection.execute(sql).getvalue(0,0)
      end
      value

    end

    def self.proc_exists?(proc)
      sql = MigrationView::get_sql('proc_exists')
      Rails.logger.debug("SchemaMigrationsProcs::proc_exists: sql: #{sql}")

      query = sanitize_sql([sql, proc])

      exists = get_single_value(query)
      exists
    end

    def self.drop_proc(proc)
      sql = MigrationView::get_sql('drop_proc').squish + " #{proc}"
      Rails.logger.debug("SchemaMigrationsProcs::proc_exists: sql: #{sql}")

      SchemaMigrationsProcs.connection.execute(sql)
    end

  end
end
