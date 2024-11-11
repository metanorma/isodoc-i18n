require_relative "lib/isodoc/i18n/version"

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
  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|bin|.github)/}) \
    || f.match(%r{Rakefile|bin/rspec})
  end
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.add_dependency "htmlentities", "~> 4.3.4"
  spec.add_dependency "liquid", "~> 5"
  spec.add_dependency "metanorma-utils", ">= 1.7.0"
  spec.add_dependency "twitter_cldr"
  spec.add_dependency "base64"

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
  spec.add_development_dependency "xml-c14n"
  # spec.metadata["rubygems_mfa_required"] = "true"
end
