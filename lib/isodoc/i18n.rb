require "htmlentities"
require "twitter_cldr"
require_relative "i18n-yaml"
require_relative "date"
require_relative "l10n"
require_relative "liquid/liquid"
require "liquid"
require_relative "i18n/version"
require "base64"

module IsoDoc
  class I18n
    attr_accessor :labels

    def initialize(lang, script, locale: nil, i18nyaml: nil, i18nhash: nil)
      @lang = lang
      @script = script
      @locale = locale
      @cal = calendar_data
      @cal_en = TwitterCldr::Shared::Calendar.new(:en)
      @c = HTMLEntities.new
      init_labels(i18nyaml, i18nhash)
      liquid_init
      self
    end

    def liquid_init
      ::IsoDoc::I18n::Liquid.set(self)
      ::Liquid::Environment.default.register_filter(::IsoDoc::I18n::Liquid)
    end

    def calendar_data
      TwitterCldr::Shared::Calendar.new(tw_cldr_lang)
    rescue StandardError
      TwitterCldr::Shared::Calendar.new(:en)
    end

    def init_labels(i18nyaml, i18nhash)
      @labels = load_yaml(@lang, @script, i18nyaml, i18nhash)
      @labels["language"] = @lang
      @labels["script"] = @script
      @labels.each_key do |k|
        methods.include?(k.downcase.to_sym) ||
          self.class.methods.include?(k.downcase.to_sym) and next
        self.class.send(:define_method, k.downcase) { get[k] }
      end
    end

    # populate with variables, Liquid, inflections, ordinals/spellout
    def populate(keys, vars = {})
      ::Liquid::Template.parse(@labels.dig(*Array(keys)))
        .render(vars.merge("labels" => @labels))
    end

    def boolean_conj(list, conn)
      case list.size
      when 0 then ""
      when 1 then list.first
      when 2 then @labels["binary_#{conn}"].sub(/%1/, list[0])
        .sub(/%2/, list[1])
      else
        @labels["multiple_#{conn}"]
          .sub(/%1/, l10n(list[0..-2].join(enum_comma), @lang, @script))
          .sub(/%2/, list[-1])
      end
    end

    def enum_comma
      %w(Hans Hant).include?(@script) and return "<enum-comma>、</enum-comma>"
      "<enum-comma>,</enum-comma> "
    end

    def cleanup_entities(text, is_xml: true)
      if is_xml
        text.split(/([<>])/).each_slice(4).map do |a|
          a[0] = @c.decode(a[0])
          a
        end.join
      else
        @c.decode(text)
      end
    end

    # ord class is either SpelloutRules or OrdinalRules
    def inflect_ordinal(num, term, ord_class)
      lbl = if @labels["ordinal_keys"].nil? || @labels["ordinal_keys"].empty?
              @labels[ord_class]
            else @labels[ord_class][ordinal_key(term)]
            end
      tw_cldr_localize(num).to_rbnf_s(ord_class, lbl)
    rescue StandardError
      num.localize(@lang.to_sym).to_rbnf_s(ord_class, lbl)
    end

    def tw_cldr_localize(num)
      num.localize(tw_cldr_lang)
    rescue StandardError
      num.localize(:en)
    end

    INFLECTIONS = {
      number: "sg",
      case: "nom",
      gender: "m",
      person: "3rd",
      voice: "act",
      mood: "ind",
      tense: "pres",
    }.freeze

    INFLECTION_ORDER = %i(voice mood tense number case gender person).freeze

    def ordinal_key(term)
      @labels["ordinal_keys"].each_with_object([]) do |k, m|
        m << (term[k.to_s] || INFLECTIONS[k.to_sym])
      end.join(".")
    end

    def tw_cldr_lang
      if @lang == "zh" && @script == "Hans" then :"zh-cn"
      elsif @lang == "zh" && @script == "Hant" then :"zh-tw"
      else @lang.to_sym
      end
    end

    # can skip category if not present
    def inflect(word, options)
      i = @labels.dig("inflection", word) or return word
      i.is_a? String and return i
      INFLECTION_ORDER.each do |x|
        infl = options[x] || INFLECTIONS[x]
        i = i[infl] if i[infl]
        i.is_a? String and return i
      end
      word
    end
  end
end
