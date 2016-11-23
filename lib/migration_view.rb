require "active_record"
require "app/models/schema_migrations_views.rb"

module MigrationView

  def self.view_exists?(view)
    ActiveRecord::Base.connection.table_exists? view
  end

  def self.create_view(view, sql)
    Rails.logger.debug("MigrationView::create_view: #{view}")

    if (view_exists?(view))
      Rails.logger.info("MigrationView::create_view: View Exists: #{view}")
      return
    end

    Rails.logger.debug("MigrationView::create_view: creating #{view}")

    schema_view = SchemaMigrationsViews.find_by_name(view)

    Rails.logger.debug("MigrationView::create_view: schema_view #{schema_view}")

    sqlFile = "db/views/#{view}.sql"

    if schema_view.nil?
      schema_view = SchemaMigrationsViews.new
      schema_view.name = view

      fileExists = false

      Rails.logger.debug("MigrationView::create_view: sqlFile: #{sqlFile} ")

      if File.exist?(sqlFile)
        fileExists = true
        sqlFile = 'db/views/#{view}-create.sql'
      end
      Rails.logger.debug("MigrationView::create_view: sqlFile: #{sqlFile}")

      Rails.logger.debug("MigrationView::create_view: Create the view file: try(#{sqlFile})")
      open(sqlFile, 'w+') do |f|
        f.puts sql
      end

    end

    Rails.logger.debug("MigrationView:: Create the db view: #{Rails.root.join(sqlFile)}")
    sql = File.read(Rails.root.join(sqlFile))
    Rails.logger.trace("view_sql: #{sql}")
    execute sql

    Rails.logger.debug("MigrationView:: Update schema_migraion_view")
    schema_view.hash_key = Digest::MD5.hexdigest(File.read(sqlFile))
    schema_view.save

    File.delete(sqlFile) if fileExists && File.exist?(sqlFile)
  end

  def self.drop_view(view, cascade)
    Rails.logger.info("MigrationView::drop_view: #{view}")

    Rails.logger.info("MigrationView::drop_view: delete the view file")
    File.delete("db/views/#{view}.sql") if File.exist?("db/views/#{view}.sql")

    Rails.logger.info("MigrationView::drop_view: drop the view: #{view}")
    sql = "DROP VIEW #{view}"
    if cascade
      sql = sql + " CASCADE"
    end
    Rails.logger.debug("MigrationView::drop_view: sql: #{sql}")
    execute sql

    Rails.logger.info("MigrationView::drop_view: delete schema_migration_view entry: #{view}")
    view = SchemaMigrationsViews.find_by_name(view)
    view.destroy
  end

  def self.views_needupdate?()
    views = MigrationView::load_view_list()

    changed = false
    missing = false
    views.each do |view|
      changed = MigrationView::view_changed?(view)
      missing = MigrationView::view_missing?(view)
      if (changed || missing)
        break
      end
    end

    Rails.logger.info("MigrationView::views_needupdate? changed views: #{changed}")
    Rails.logger.info("MigrationView::views_needupdate? missing views: #{missing}")

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
    Rails.logger.info("MigrationView::update_views Update Views")
    views = MigrationView::load_view_list()

    views.each do |view|
      Rails.logger.info("MigrationView::update_view: view: #{view}")

      if view_exists?(view)
        Rails.logger.info("MigrationView::update_views Delete old views")
        drop_sql = "drop view #{view} cascade"
        Rails.logger.info("MigrationView::update_views: #{drop_sql}")
        ActiveRecord::Base.connection.execute(drop_sql)
      end
   end

   views.each do |view|
      Rails.logger.info("MigrationView::update_views: Create new views")
      MigrationView::update_view(view)
    end
  end

  def self.update_view(view)
    Rails.logger.info("MigrationView::update_view: #{view}")

    Rails.logger.info("MigrationView::update_views:Create the db view")
    sql = File.read(Rails.root.join("db/views/#{view}.sql"))
    Rails.logger.info("MigrationView::update_views: view_sql: #{sql}")
    ActiveRecord::Base.connection.execute(sql)

    migration_view = SchemaMigrationsViews.find_by_name(view)
    migration_view.hash_key = Digest::MD5.hexdigest(File.read("db/views/#{view}.sql"))
    migration_view.save
  end

  def self.load_view_list()
      stored_views = MigrationView::SchemaMigrationsViews.all.order('view_order')

      views = []
      stored_views.each_with_index do |view, i|
         views[i] = view.name
      end

      Rails.logger.info("MigrationView::managed view list: #{views}")
      views
  end

end
