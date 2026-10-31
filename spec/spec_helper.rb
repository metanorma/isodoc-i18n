require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "bundler/setup"
require "isodoc-i18n"
require "rspec/matchers"
require "canon"
require "canon/rspec_matchers"
require "nokogiri"

# metanorma-utils sits below isodoc in the stack, so isodoc's
# canon_html_input_guard cannot be required here. Mirror its XML
# fragment wrapping: canon's strict parser rejects multi-root
# fragments, so wrap both sides in a shared synthetic root.
module Metanorma
  module Utils
    module CanonXmlFragGuard
      ROOT = "canon-xml-frag-root"

      def compute_equivalent(target)
        if @format == :xml
          @expected = wrap(@expected)
          target = wrap(target)
        end
        super(target)
      end

      private

      def wrap(value)
        return value unless value.is_a?(String)
        return value if value.include?(ROOT)
        wrapped = "<#{ROOT}>#{value}</#{ROOT}>"
        begin
          Canon::XmlParsing.moxml_context.parse(wrapped, readonly: true, strict: true)
          wrapped
        rescue StandardError
          begin
            Nokogiri::XML(wrapped).to_xml
          rescue StandardError
            wrapped
          end
        end
      end
    end
  end
end
Canon::RSpecMatchers::SerializationMatcher
  .prepend(Metanorma::Utils::CanonXmlFragGuard)

Canon::Config.instance.profile = :metanorma

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

def metadata(hash)
  hash.sort.to_h.delete_if do |_k, v|
    v.nil? || (v.respond_to?(:empty?) && v.empty?)
  end
end
