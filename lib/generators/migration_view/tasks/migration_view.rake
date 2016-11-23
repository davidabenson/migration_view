namespace :db do
  namespace :reload do

    task :view  => :environment do
      Rails.logger = Logger.new(STDOUT)
      Rails.logger.info("MigrationView:: reload views")

      MigrationView::update_views()
    end
  end
end