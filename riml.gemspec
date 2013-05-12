require File.expand_path("../version", __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'riml'
  s.version     = Riml::VERSION.join('.')
  s.summary     = 'Riml is a language that compiles into Vimscript'
  s.description = <<-desc
  Riml is a subset of VimL with some added features, and it compiles to plain
  Vimscript. Some of the added features include classes, string interpolation,
  heredocs, default case-sensitive string comparison and default arguments in
  functions. Give it a try!
  desc

  s.required_ruby_version  = '>= 1.9.2'
  s.license = 'MIT'

  s.author = 'Luke Gruber'
  s.email = 'luke.gru@gmail.com'
  s.homepage = 'https://github.com/luke-gru/riml'
  s.bindir = 'bin'
  s.require_path = 'lib'
  s.executables = ['riml']
  s.files = Dir['README.md', 'LICENSE', 'version.rb', 'lib/**/*', 'Rakefile',
                'CONTRIBUTING', 'Gemfile', 'Gemfile.lock']

  s.add_development_dependency('racc')
end
