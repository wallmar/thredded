# frozen_string_literal: true

source 'https://rubygems.org'

gem 'rails', '~> 6.0.0.beta3'
gem 'rails-i18n', '~> 6.0.0.beta1'

# https://github.com/rails/rails/blob/v6.0.0.beta3/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L12
gem 'sqlite3', '~> 1.3', '>= 1.3.6'

group :test do
  gem 'rails-controller-testing'

  # https://github.com/rspec/rspec-rails/issues/2103
  gem 'rspec-rails', git: 'https://github.com/rspec/rspec-rails', branch: '4-0-dev'
  gem 'rspec-core', git: 'https://github.com/rspec/rspec-core'
  gem 'rspec-mocks', git: 'https://github.com/rspec/rspec-mocks'
  gem 'rspec-support', git: 'https://github.com/rspec/rspec-support'
  gem 'rspec-expectations', git: 'https://github.com/rspec/rspec-expectations'
end

gemspec

eval_gemfile File.expand_path('shared.gemfile', __dir__)
eval_gemfile File.expand_path('rubocop.gemfile', __dir__)
