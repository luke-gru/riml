require File.expand_path("../version", __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'riml'
  s.version     = Riml::VERSION.join('.')
  s.summary     = 'Relaxed Vimscript'
  s.description = <<-desc
  Riml is a superset of VimL that includes some nice features:
  classes, string interpolation, heredocs, default case-sensitive string
  comparison and other things most programmers take for granted.
  desc

  s.required_ruby_version  = '>= 1.9.2'
  s.license = 'MIT'

  s.author = 'Luke Gruber'
  s.email = 'luke.gru@gmail.com'
  s.bindir = 'bin'
  s.require_path = 'lib'
  s.executables = ['riml']
  s.files = Dir['README.md', 'LICENSE', 'version.rb', 'config/*', 'lib/**/*']

  s.add_development_dependency('racc')
end
