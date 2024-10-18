require "active_record"

require "app/models/schema_migrations_views.rb"
require "app/models/schema_migrations_procs.rb"

module MigrationView

  def self.database_type()
    adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
    # Rails.logger.debug("MigrationView::create_view: adapter_name: #{adapter_name}")

    type = 'unsupported'
    case
    when adapter_name.starts_with?('mysql')
      type = 'MYSQL'
    when adapter_name.starts_with?('postgresql')
      type = 'PSQL'
    end
  end

  VIEW_EXISTS_PSQL = <<-END_OF_SQL_CODE
      select count(*) from pg_catalog.pg_class c
      inner join pg_catalog.pg_namespace n
      on c.relnamespace=n.oid where n.nspname = 'public' and c.relname=?
  END_OF_SQL_CODE

  VIEW_EXISTS_MYSQL = <<-END_OF_SQL_CODE
      SELECT  TABLE_NAME  FROM information_schema.tables  WHERE TABLE_TYPE LIKE 'VIEW' AND TABLE_NAME=?
  END_OF_SQL_CODE

  PROC_EXISTS_MYSQL = <<-END_OF_SQL_CODE
      SELECT IF( COUNT(*) = 0, FALSE , TRUE ) AS ProcedureExists
        FROM INFORMATION_SCHEMA.ROUTINES
        WHERE ROUTINE_TYPE = 'PROCEDURE'
        AND UCASE(ROUTINE_NAME) = UCASE(?);
  END_OF_SQL_CODE

  DROP_PROC_MYSQL = <<-END_OF_SQL_CODE
      DROP PROCEDURE IF EXISTS
  END_OF_SQL_CODE

  PROC_EXISTS_PSQL = <<-END_OF_SQL_CODE
      SELECT EXISTS (
        SELECT *
        FROM pg_catalog.pg_proc
        JOIN pg_namespace ON pg_catalog.pg_proc.pronamespace = pg_namespace.oid
        WHERE proname = ?
            AND pg_namespace.nspname = 'schema_name'
        )
  END_OF_SQL_CODE

  def self.get_sql(kind)
    property = "MigrationView::#{kind.upcase}_#{database_type}"
    MigrationView.const_get(property)
  end

  def self.view_exists?(view)
    ActiveRecord::Base.connection.view_exists? view
  end

  def self.create_view(view, sql)
    # Rails.logger.debug("MigrationView::create_view: #{view}")

    if (view_exists?(view))
      # Rails.logger.info("MigrationView::create_view: View Exists: #{view}")
      return
    end

    # Rails.logger.debug("MigrationView::create_view: creating #{view}")

    schema_view = MigrationView::SchemaMigrationsViews.find_by_name(view)

    # Rails.logger.debug("MigrationView::create_view: schema_view #{schema_view}")

    Dir.mkdir("db/views") unless File.exist?("db/views")
    sqlFile = "db/views/#{view}.sql"

    if schema_view.nil?
      schema_view = MigrationView::SchemaMigrationsViews.new
      schema_view.name = view

      fileExists = false

      # Rails.logger.debug("MigrationView::create_view: sqlFile: #{sqlFile} ")

      if File.exist?(sqlFile)
        fileExists = true
        sqlFile = 'db/views/#{view}-create.sql'
      end
      # Rails.logger.debug("MigrationView::create_view: sqlFile: #{sqlFile}")

      # Rails.logger.debug("MigrationView::create_view: Create the view file: try(#{sqlFile})")
      open(sqlFile, 'w+') do |f|
        f.puts sql
      end
    end

    # Rails.logger.debug("MigrationView:: Create the db view: #{Rails.root.join(sqlFile)}")
    sql = File.read(Rails.root.join(sqlFile))
    # Rails.logger.debug("view_sql: #{sql}")
    ActiveRecord::Base.connection.execute sql

    # Rails.logger.debug("MigrationView:: Update schema_migraion_view")
    # view_order = MigrationView::SchemaMigrationsViews.maximum(:id)
    # view_order ||= 1

    schema_view.hash_key = Digest::MD5.hexdigest(File.read(sqlFile))
    # schema_view.view_order = view_order
    schema_view.save

    File.delete(sqlFile) if fileExists && File.exist?(sqlFile)
  end

  def self.recreate_view(view)
    schema_view = MigrationView::SchemaMigrationsViews.find_by_name(view)
    sqlFile = "db/views/#{view}.sql"

    # Rails.logger.debug("MigrationView:: Create the db view: #{Rails.root.join(sqlFile)}")
    sql = File.read(Rails.root.join(sqlFile))
    # Rails.logger.debug("view_sql: #{sql}")
    ActiveRecord::Base.connection.execute sql

    # Rails.logger.debug("MigrationView:: Update schema_migraion_view")
    schema_view.hash_key = Digest::MD5.hexdigest(File.read(sqlFile))
    schema_view.save
  end

  def self.drop_view(view, cascade = true)
    # Rails.logger.info("MigrationView::drop_view: #{view}")

    # Rails.logger.info("MigrationView::drop_view: delete the view file")
    File.delete("db/views/#{view}.sql") if File.exist?("db/views/#{view}.sql")

    Rails.logger.info("MigrationView::drop_view: drop the view: #{view}")
    sql = "DROP VIEW #{view}"
    if cascade
      sql = sql + " CASCADE"
    end
    # Rails.logger.debug("MigrationView::drop_view: sql: #{sql}")
    ActiveRecord::Base.connection.execute sql

    # Rails.logger.info("MigrationView::drop_view: delete schema_migration_view entry: #{view}")
    view = SchemaMigrationsViews.find_by_name(view)
    if (view)
      view.destroy
    end

  end

  def self.views_needupdate?()
    views = MigrationView::load_view_list()

    changed = false
    missing = false
    views.each do |view|
      changed = MigrationView::view_changed?(view)
      # Rails.logger.info("MigrationView::views_needupdate? changed views: #{view}") if changed

      missing = MigrationView::view_missing?(view)
      # Rails.logger.info("MigrationView::views_needupdate? missing views: #{view}") if missing

      if (changed || missing)
        break
      end
    end

    # Rails.logger.info("MigrationView::views_needupdate? changed views: #{changed}")
    # Rails.logger.info("MigrationView::views_needupdate? missing views: #{missing}")

    if (changed || missing)
      true
    else
      false
    end
  end

  def self.view_changed?(view)
    changed = false
    saved_view = SchemaMigrationsViews.find_by_name(view)
    current_hash = Digest::MD5.hexdigest(File.read("db/views/#{view}.sql"))
    if saved_view.hash_key != current_hash
      changed = true
    end

    changed
  end

  def self.view_missing?(view)
    !MigrationView::view_exists?(view)
  end

  def self.update_views()
    # Rails.logger.info("MigrationView::update_views Update Views")
    views = MigrationView::load_view_list()

    views.each do |view|
      # Rails.logger.info("MigrationView::update_view: view: #{view}")

      exists = view_exists?(view)
      # Rails.logger.info("MigrationView::update_view: view: exists: #{exists}")

      if exists
        # Rails.logger.info("MigrationView::update_views Delete old views")
        drop_sql = "drop view #{view} cascade"
        # Rails.logger.info("MigrationView::update_views: #{drop_sql}")
        ActiveRecord::Base.connection.execute(drop_sql)
      end
    end

    views.each do |view|
      # Rails.logger.info("MigrationView::update_views: Create new views")
      MigrationView::update_view(view)
    end
  end

  def self.update_view(view, sql = nil)
    # Rails.logger.info("MigrationView::update_view: #{view}")
    sqlFile = "db/views/#{view}.sql"
    # Rails.logger.debug("MigrationView::update_view: sqlFile: #{sqlFile} ")

    if sql
      # Write out new sql to file
      # Rails.logger.debug("MigrationView::update_view: Write the view: #{view} file: #{sql}")
      open(sqlFile, 'w+') do |f|
        f.puts sql
      end
    end

    sql = File.read(Rails.root.join(sqlFile))
    # Rails.logger.debug("MigrationView::update_view: execute: #{view} file: #{sql}")
    ActiveRecord::Base.connection.execute(sql)

    # Rails.logger.debug("MigrationView::update_view: save: #{view}")
    migration_view = SchemaMigrationsViews.find_by_name(view)
    migration_view.hash_key = Digest::MD5.hexdigest(File.read("db/views/#{view}.sql"))
    migration_view.save
  end

  def self.load_view_list()
    stored_views = MigrationView::SchemaMigrationsViews.all.order(:id)

    views = []
    stored_views.each_with_index do |view, i|
      views[i] = view.name
    end

    # Rails.logger.info("MigrationView::managed view list: #{views}")
    views
  end

  def self.create_procedure(proc, sql, drop_if_exists = true)
    # Rails.logger.info("MigrationView::create_procedure: #{proc}")

    if (MigrationView::SchemaMigrationsProcs::proc_exists?(proc))
      # Rails.logger.debug("MigrationView::create_procedure: Proc Exists: #{proc}")
      if (drop_if_exists)
        MigrationView::SchemaMigrationsProcs::drop_proc(proc)
      else
        return
      end
    end

    # Rails.logger.debug("MigrationView::create_procedure: creating #{proc}")

    schema_proc = MigrationView::SchemaMigrationsProcs.find_by_name(proc)

    # Rails.logger.debug("MigrationView::create_procedure: schema_view #{schema_proc}")

    Dir.mkdir("db/procs") unless File.exist?("db/procs")
    sqlFile = "db/procs/#{proc}.sql"

    if schema_proc.nil?
      schema_proc = MigrationView::SchemaMigrationsProcs.new
      schema_proc.name = proc

      fileExists = false

      # Rails.logger.debug("MigrationView::create_procedure: sqlFile: #{sqlFile} ")

      if File.exist?(sqlFile)
        fileExists = true
        sqlFile = 'db/procs/#{proc}-create.sql'
      end
      # Rails.logger.debug("MigrationView::create_procedure: sqlFile: #{sqlFile}")

      # Rails.logger.debug("MigrationView::create_procedure: Create the proc file: try(#{sqlFile})")
      open(sqlFile, 'w+') do |f|
        f.puts sql
      end

    end

    # Rails.logger.debug("MigrationView::create_procedure Create the db proc: #{Rails.root.join(sqlFile)}")
    sql = File.read(Rails.root.join(sqlFile))
    # Rails.logger.debug("proc_sql: #{sql}")
    ActiveRecord::Base.connection.execute sql

    # Rails.logger.debug("MigrationView::create_procedure Update schema_migraion_proc")
    schema_proc.hash_key = Digest::MD5.hexdigest(File.read(sqlFile))
    schema_proc.save

    File.delete(sqlFile) if fileExists && File.exist?(sqlFile)
  end

  def self.update_procs()
    # Rails.logger.debug("MigrationView::update_procs Update Procs")
    procs = MigrationView::load_proc_list()

    procs.each do |proc|
      # Rails.logger.debug("MigrationView::update_proc: proc: #{proc}")

      if MigrationView::SchemaMigrationsProcs::proc_exists?(proc)
        # Rails.logger.debug("MigrationView::update_procs Delete old procs")

        MigrationView::SchemaMigrationsProcs::drop_proc(proc)
      end
    end

    procs.each do |proc|
      # Rails.logger.debug("MigrationView::update_proc: Create new procs")
      MigrationView::update_proc(proc)
    end
  end

  def self.update_proc(proc)
    # Rails.logger.info("MigrationView::update_view: #{proc}")

    # Rails.logger.debug("MigrationView::update_procs:Create the db proc")
    sql = File.read(Rails.root.join("db/procs/#{proc}.sql"))
    # Rails.logger.debug("MigrationView::update_procs: proc_sql: #{sql}")
    ActiveRecord::Base.connection.execute(sql)

    migration_proc = SchemaMigrationsProcs.find_by_name(proc)
    migration_proc.hash_key = Digest::MD5.hexdigest(File.read("db/procs/#{proc}.sql"))
    migration_proc.save
  end

  def self.load_proc_list()
    stored_procs = MigrationView::SchemaMigrationsProcs.all.order('id')

    procs = []
    stored_procs.each_with_index do |proc, i|
      procs[i] = proc.name
    end

    # Rails.logger.info("MigrationView::managed proc list: #{procs}")
    procs
  end

  def self.procs_needupdate?()
    procs = MigrationView::load_proc_list()

    changed = false
    missing = false
    procs.each do |proc|
      changed = MigrationView::proc_changed?(proc)
      missing = MigrationView::proc_missing?(proc)
      if (changed || missing)
        break
      end
    end

    # Rails.logger.info("MigrationView::procs_needupdate? changed procs: #{changed}")
    # Rails.logger.info("MigrationView::procs_needupdate? missing procs: #{missing}")

    if (changed || missing)
      true
    else
      false
    end
  end

  def self.proc_changed?(proc)
    changed = false
    saved_proc = SchemaMigrationsProcs.find_by_name(proc)
    current_hash = Digest::MD5.hexdigest(File.read("db/procs/#{proc}.sql"))
    if saved_proc.hash_key != current_hash
      changed = true
    end

    changed
  end

  def self.proc_missing?(proc)
    !MigrationView::SchemaMigrationsProcs::proc_exists?(proc)
  end

end
