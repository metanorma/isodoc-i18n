require "yaml"
require "metanorma-utils"

module IsoDoc
  class I18n
    Hash.include Metanorma::Utils::Hash

    def load_yaml(lang, script, i18nyaml = nil, i18nhash = nil)
      ret = load_yaml1(lang, script)
      i18nyaml and
        return normalise_hash(ret.deep_merge(YAML.load_file(i18nyaml)))
      i18nhash and return normalise_hash(ret.deep_merge(i18nhash))

      normalise_hash(ret)
    end

    def normalise_hash(ret)
      case ret
      when Hash
        ret.each do |k, v|
          ret[k] = normalise_hash(v)
        end
        ret
      when Array then ret.map { |n| normalise_hash(n) }
      when String then cleanup_entities(ret.unicode_normalize(:nfc))
      else ret
      end
    end

    def load_yaml1(lang, script)
      case lang
      when "zh"
        if script == "Hans" then load_yaml2("zh-Hans")
        else load_yaml2("en")
        end
      else
        load_yaml2(lang)
      end
    end

    # locally defined in calling class
    def load_yaml2(lang)
      YAML.load_file(File.join(File.dirname(__FILE__),
                               "../isodoc-yaml/i18n-#{lang}.yaml"))
    rescue StandardError
      YAML.load_file(File.join(File.dirname(__FILE__),
                               "../isodoc-yaml/i18n-en.yaml"))
    end

    def get
      @labels
    end

    def set(key, val)
      @labels[key] = val
    end
  end
end
