require "yaml"
require "htmlentities"
require "metanorma-utils"
require "twitter_cldr"

module IsoDoc
  class I18n
    def load_yaml(lang, script, i18nyaml = nil)
      ret = load_yaml1(lang, script)
      return normalise_hash(ret.merge(YAML.load_file(i18nyaml))) if i18nyaml

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

    def initialize(lang, script, i18nyaml = nil)
      @lang = lang
      @script = script
      y = load_yaml(lang, script, i18nyaml)
      @labels = y
      @labels["language"] = @lang
      @labels["script"] = @script
      @labels.each do |k, _v|
        self.class.send(:define_method, k.downcase) { get[k] }
      end
    end

    def self.l10n(text, lang = @lang, script = @script)
      l10n(text, lang, script)
    end

    # TODO: move to localization file
    # function localising spaces and punctuation.
    # Not clear if period needs to be localised for zh
    def l10n(text, lang = @lang, script = @script)
      if lang == "zh" && script == "Hans" then l10n_zh(text)
      else bidiwrap(text, lang, script)
      end
    end

    def bidiwrap(text, lang, script)
      my_script, my_rtl, outer_rtl = bidiwrap_vars(lang, script)
      if my_rtl && !outer_rtl
        mark = %w(Arab Aran).include?(my_script) ? "&#x61c;" : "&#x200f;"
        "#{mark}#{text}#{mark}"
      elsif !my_rtl && outer_rtl then "&#x200e;#{text}&#x200e;"
      else text
      end
    end

    def bidiwrap_vars(lang, script)
      my_script = script || Metanorma::Utils.default_script(lang)
      [my_script,
       Metanorma::Utils.rtl_script?(my_script),
       Metanorma::Utils.rtl_script?(@script || Metanorma::Utils
         .default_script(@lang))]
    end

    def l10n_zh(text)
      xml = Nokogiri::HTML::DocumentFragment.parse(text)
      xml.traverse do |n|
        next unless n.text?

        n.replace(cleanup_entities(l10_zh1(n.text), is_xml: false))
      end
      xml.to_xml.gsub(/<b>/, "").gsub("</b>", "").gsub(/<\?[^>]+>/, "")
    end

    ZH_CHAR = "\\p{Han}|\\p{In CJK Symbols And Punctuation}|"\
              "\\p{In Halfwidth And Fullwidth Forms}".freeze

    # note: we can't differentiate comma from enumeration comma 、
    def l10_zh1(text)
      [":：", ",，", ".。", ")）", "]】", ":：", ";；", "?？", "!！"].each do |m|
        text = text.gsub(/(?<=#{ZH_CHAR})#{Regexp.quote m[0]}/, m[1])
      end
      ["(（", "[【"].each do |m|
        text = text.gsub(/#{Regexp.quote m[0]}(?=#{ZH_CHAR})/, m[1])
      end
      text.gsub(/(?<=#{ZH_CHAR}) (?=#{ZH_CHAR})/o, "")
        .gsub(/(?<=\d) (?=#{ZH_CHAR})/o, "")
        .gsub(/(?<=#{ZH_CHAR}) (?=\d)/o, "")
        .gsub(/(?<=#{ZH_CHAR}) (?=[A-Za-z](#{ZH_CHAR}|$))/o, "")
    end

    def boolean_conj(list, conn)
      case list.size
      when 0 then ""
      when 1 then list.first
      when 2 then @labels["binary_#{conn}"].sub(/%1/, list[0])
        .sub(/%2/, list[1])
      else
        @labels["multiple_#{conn}"]
          .sub(/%1/, l10n(list[0..-2].join(", "), @lang, @script))
          .sub(/%2/, list[-1])
      end
    end

    def cleanup_entities(text, is_xml: true)
      c = HTMLEntities.new
      if is_xml
        text.split(/([<>])/).each_slice(4).map do |a|
          a[0] = c.encode(c.decode(a[0]), :hexadecimal)
          a
        end.join
      else
        c.encode(c.decode(text), :hexadecimal)
      end
    end

    # ord class is either SpelloutRules or OrdinalRules
    def inflect_ordinal(num, term, ord_class)
      if @labels["ordinal_keys"].nil? || @labels["ordinal_keys"].empty?
        tw_cldr_localize(num).to_rbnf_s(ord_class, @labels[ord_class])
      else
        tw_cldr_localize(num)
          .to_rbnf_s(ord_class, @labels[ord_class][ordinal_key(term)])
      end
    end

    def tw_cldr_localize(num)
      num.localize(tw_cldr_lang)
    rescue StandardError
      num.localize(:en)
    end

    def ordinal_key(term)
      @labels["ordinal_keys"].each_with_object([]) do |k, m|
        m << case k
             when "gender" then term["gender"]
             when "number" then term["number"] || "sg"
             when "case" then term["case"] || "nom"
             end
      end.join(".")
    end

    def tw_cldr_lang
      if @lang == "zh" && @script == "Hans" then :"zh-cn"
      elsif @lang == "zh" && @script == "Hant" then :"zh-tw"
      else @lang.to_sym
      end
    end
  end
end
