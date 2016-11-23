Rake::Task["db:migrate"].enhance do
  Rails.logger = Logger.new(STDOUT)
  Rails.logger.info("MigrationView:: post migration action")

  if (MigrationView::views_needupdate?)
    MigrationView::update_views()
  end
end