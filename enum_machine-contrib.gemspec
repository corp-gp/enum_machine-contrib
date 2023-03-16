# frozen_string_literal: true

require_relative 'lib/enum_machine_contrib/version'

Gem::Specification.new do |spec|
  spec.name = 'enum_machine-contrib'
  spec.version = EnumMachineContrib::VERSION
  spec.authors = ['Sergei Malykh']
  spec.email = ['xronos.i.am@gmail.com']

  spec.summary = 'extensions and tools for enum_machine'
  spec.homepage = 'https://github.com/corp-gp/enum_machine-contrib'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.6.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/corp-gp/enum_machine-contrib'
  spec.metadata['changelog_uri'] = 'https://github.com/corp-gp/enum_machine-contrib/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0").reject do |f|
        (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
      end
    end
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport'
  spec.add_dependency 'enum_machine'
  spec.add_dependency 'ruby-graphviz'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
