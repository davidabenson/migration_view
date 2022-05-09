$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "migration_view/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "migration_view"
  s.version     = MigrationView::VERSION
  s.authors     = ["davidabenson"]
  s.email       = ["david.benson@nrel.gov"]
  s.homepage    = ""
  s.summary     = "Adds view migration management"
  s.description = "Allows views to be stored in a seperate file and recreataed when changed."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  # s.required_ruby_version = '>= 2.5.4'
  s.add_dependency "rails", "~> 6.1.5.1"
  s.add_dependency "nokogiri", ">= 1.5.9"

end
