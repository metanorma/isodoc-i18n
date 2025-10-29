require "yaml"
require "metanorma-utils"

module IsoDoc
  class I18n
    Hash.include Metanorma::Utils::Hash

    def load_yaml(lang, script, i18nyaml = nil, i18nhash = nil)
      ret = load_yaml1(lang, script)
      if i18nyaml
        Array(i18nyaml).compact.each do |y|
          ret = ret.deep_merge(YAML.load_file(y))
        end
        return postprocess(ret)
      end
      i18nhash and return postprocess(ret.deep_merge(i18nhash))
      postprocess(ret)
    end

    def postprocess(labels)
      self_reference_resolve(normalise_hash(labels))
    end

    def self_reference_resolve(labels)
      resolve_references(labels, labels)
    end

    def resolve_references(obj, labels)
      case obj
      when Hash
        obj.transform_values { |v| resolve_references(v, labels) }
      when Array
        obj.map { |item| resolve_references(item, labels) }
      when String
        resolve_string_references(obj, labels)
      else
        obj
      end
    end

    def resolve_string_references(str, labels)
      # Match patterns like #{self["key"]["subkey"]} or #{self.key.subkey}
      # Allow spaces around the self expression
      str.gsub(/\#\{\s*self([^}]+?)\s*\}/) do |match|
        path_expr = Regexp.last_match(1)
        resolve_path(path_expr, labels, match)
      end
    end

    def resolve_path(path_expr, labels, original_expr)
      segments = parse_path(path_expr)
      current = labels

      segments.each do |segment|
        case current
        when Hash
          current.key?(segment) or
            raise "Self-reference error: Path '#{original_expr}' not found - key '#{segment}' does not exist"
          current = current[segment]
        when Array
          index = segment.to_i
          segment =~ /^\d+$/ && index >= 0 && index < current.length or
            raise "Self-reference error: Path '#{original_expr}' not found - invalid array index '#{segment}'"
          current = current[index]
        else
          raise "Self-reference error: Path '#{original_expr}' not found - cannot navigate through non-collection type"
        end
      end

      current.to_s
    end

    def parse_path(path_expr)
      # Split by dots and brackets while preserving the content
      parts = path_expr.sub(/^\./, "").scan(/\.?([\w-]+)|\[([^\]]+)\]/)
      parts.each_with_object([]) do |(dot_part, bracket_part), segments|
        if dot_part
          segments << dot_part
        elsif bracket_part
          segment = bracket_part.strip.gsub(/^["']|["']$/, "")
          segments << segment
        end
      end
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
        if script then load_yaml2("zh-#{script}")
        else load_yaml2("zh-Hans")
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
