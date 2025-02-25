source "https://rubygems.org"

ruby "3.4.2"
gem "rails", "~> 8.0.1"

gem "bootsnap", require: false
gem "jbuilder"
gem "kamal", require: false
gem "minitest-rails", "~> 8.0.0"
gem "pg", "~> 1.1"
gem "propshaft"
gem "puma", ">= 5.0"
gem "sentry-rails"
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"
gem "thruster", require: false
gem "vite_rails", "~> 3.0", ">= 3.0.19"

group :development, :test do
  gem "brakeman", require: false
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "pry-nav", "~> 1.0.0"
  gem "pry-rails", "~> 0.3.9"
  gem "rubocop", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
