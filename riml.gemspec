require File.expand_path("../version", __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'riml'
  s.version     = Riml::VERSION.join('.')
  s.summary     = 'Riml is a language that compiles into VimL'
  s.description = <<-desc
  Riml is ruby-like version of VimL with some added features, and it compiles to plain
  Vimscript. Some of the added features include classes, string interpolation,
  heredocs, default case-sensitive string comparison and default arguments in
  functions.
  desc

  s.required_ruby_version  = '>= 2.0.0'
  s.license = 'MIT'

  s.author = 'Luke Gruber'
  s.email = 'luke.gru@gmail.com'
  s.homepage = 'https://github.com/luke-gru/riml'
  s.bindir = 'bin'
  s.require_path = 'lib'
  s.executables = ['riml']
  s.files = Dir['README.md', 'LICENSE', 'version.rb', 'lib/**/*', 'Rakefile',
                'CONTRIBUTING', 'CHANGELOG' 'Gemfile']

  s.add_development_dependency('racc')
  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')
  s.add_development_dependency('minitest')
  s.add_development_dependency('mocha')
  s.add_development_dependency('ostruct')
  s.add_development_dependency('debug')
end
