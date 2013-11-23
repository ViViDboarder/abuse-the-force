$:.push File.expand_path('../lib', __FILE__)
require 'rake/testtask'
require 'abusetheforce/version'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

task :default => :build

desc "Build the gem"
task :build do
    system "gem build abusetheforce.gemspec"
end

task :install => [:build] do
    system "gem install abusetheforce-#{AbuseTheForce::VERSION}.gem"
end