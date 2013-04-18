# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'abusetheforce/version'

Gem::Specification.new do |s|
  s.name        = 'abusetheforce'
  s.version     = AbuseTheForce::VERSION
  s.authors     = ['Ian']
  s.email       = ['ViViDboarder@gmail.com']
  s.homepage    = 'https://github.com/ViViDboarder/abusetheforce'
  s.summary     = %q{A Ruby gem for configuring and interacting with Metaforce}
  s.description = %q{A Ruby gem for configuring and interacting with Metaforce}

  #s.rubyforge_project = 'abusetheforce'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_dependency 'thor', '~> 0.16.0'
  s.add_dependency 'listen', '~> 0.6.0'
  s.add_dependency 'metaforce', '~> 1.0.7'
  s.add_dependency 'highline'

  s.add_development_dependency 'rake'
end
