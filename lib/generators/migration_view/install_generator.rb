module MigrationView
  module Generators
    class InstallGenerator < Rails::Generators::Base

      source_root File.expand_path("../", __FILE__)

      puts "#{source_root}"
      desc "Adds need migration"



      def create_tasks
        puts "Extend db:migrate"


        template "#{self.class.source_root}/tasks/migration_view_change_handler.rake", "lib/tasks/migration_view_change_handler.rake"
        template "#{self.class.source_root}/tasks/migration_view.rake", "lib/tasks/migration_view.rake"
      end

      def create_migrations
        puts "Add migration"

        exec "rails g migration create_schema_migrations_views name:string hash_key:string view_order:integer"
        exec "rails g migration create_schema_migrations_procs name:string hash_key:string proc_order:integer"
      end

     end
  end
end