source 'https://rubygems.org'

plugin 'bundler-inject', '~> 1.1'
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

gem "activesupport", '~> 5.2.5'
gem "clowder-common-ruby", '~> 0.2.3'

gem "concurrent-ruby"
gem "faraday", "~> 1.0"
gem "manageiq-loggers",      "~> 0.5.0"
gem "insights-loggers-ruby", "~> 0.1.12"
gem "manageiq-messaging", "~> 1.0.0"
gem "more_core_extensions"
gem "optimist"
gem "prometheus_exporter", "~> 0.4.5"
gem "rake", ">= 12.3.3"
gem "rdkafka", "~> 0.8.1"
gem "receptor_controller-client", "~> 0.0.10"
gem "rest-client", "~>2.0"
gem "sources-api-client", "~> 3.0"
gem "topological_inventory-providers-common", "~> 3.0.2"

group :development, :test do
  gem "rspec"
  gem "rubocop",             "~> 1.0.0", :require => false
  gem "rubocop-performance", "~> 1.8",   :require => false
  gem "rubocop-rails",       "~> 2.8",   :require => false
  gem "simplecov",           "~>0.17.1"
  gem "webmock"
end
