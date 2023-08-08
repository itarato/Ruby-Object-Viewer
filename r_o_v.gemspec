Gem::Specification.new do |s|
  s.name = 'r_o_v'
  s.summary = 'Tree style Ruby object viewer (for the terminal)'
  s.version = '0.0.1'
  s.required_ruby_version = '>= 3.0.0'
  s.date = '2023-08-08'
  s.files = Dir.glob('lib/**/*.rb')
  s.require_paths = ['lib']
  s.authors = ['itarato']
  s.email = 'it.arato@gmail.com'
  s.license = 'GPL-3.0-or-later'
  s.homepage = 'https://github.com/itarato/Ruby-Object-Viewer/'
  s.add_development_dependency 'minitest'
end
