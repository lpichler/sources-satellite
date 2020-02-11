source 'https://rubygems.org'

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "activesupport", "~> 5.2.2"
gem "cloudwatchlogger", "~> 0.2"
gem "concurrent-ruby"
gem "manageiq-loggers", "~> 0.4.0", ">= 0.4.2"
gem 'manageiq-messaging'
gem "more_core_extensions"
gem "optimist"
gem "prometheus_exporter", "~> 0.4.5"
gem "rake"
gem "rest-client", "~>2.0"
gem "sources-api-client", "~> 1.0"
gem "topological_inventory-ingress_api-client", "~> 1.0"
gem "topological_inventory-providers-common", "~> 0.1"
group :test, :development do
  gem "rspec"
  gem "simplecov"
  gem "webmock"
end
