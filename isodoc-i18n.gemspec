lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "isodoc/version"

Gem::Specification.new do |spec|
  spec.name          = "isodoc-i18n"
  spec.version       = IsoDoc::I18n::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "isodoc-i18n "
  spec.description   = <<~DESCRIPTION
    Internationalisation for Metanorma rendering
  DESCRIPTION

  spec.homepage      = "https://github.com/metanorma/isodoc-i18n"
  spec.license       = "BSD-2-Clause"

  spec.bindir        = "bin"
  spec.require_paths = ["lib"]
  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {spec}/*`.split("\n")
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.add_dependency "htmlentities", "~> 4.3.4"
  spec.add_dependency "metanorma-utils", "~> 1.4.0"
  spec.add_dependency "twitter_cldr"

  spec.add_development_dependency "debug"
  spec.add_development_dependency "equivalent-xml", "~> 0.6"
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-rspec", "~> 4.7"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.6"
  spec.add_development_dependency "rubocop", "~> 1.5.2"
  spec.add_development_dependency "simplecov", "~> 0.15"
  spec.add_development_dependency "timecop", "~> 0.9"
  spec.add_development_dependency "webmock"
  #spec.metadata["rubygems_mfa_required"] = "true"
end
