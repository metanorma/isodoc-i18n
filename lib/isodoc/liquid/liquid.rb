module IsoDoc
  class I18n
    module Liquid
      def self.set(i18n)
        @@i18n = i18n
      end

      def parse_hash(str, symbol: true)
        str.split(/,\s*/).each_with_object({}) do |e, m|
          k, v = e.split(/:/, 2)
          m[symbol ? k.to_sym : k.to_s] = v
        end
      end

      # word | inflect: nom,sg,neut
      def inflect(word, options)
        @@i18n.inflect(word, parse_hash(options))
      end

      # num | ordinal_num: label, inflection
      # e.g. "3" | ordinal: "edition", "case:acc"
      # combines inflection information from label and inflection
      def ordinal_num(num, label = "", infl = "")
        l = @@i18n.labels[label]
        h = @@i18n.labels["inflection"]&.dig(l, "grammar") || {}
        grammar = h.merge(parse_hash(infl, symbol: false))
        @@i18n.inflect_ordinal(num.to_i, grammar, "OrdinalRules")
      end

      def ordinal_word(num, label = "", infl = "")
        l = @@i18n.labels[label]
        h = @@i18n.labels["inflection"]&.dig(l, "grammar") || {}
        grammar = h.merge(parse_hash(infl, symbol: false))
        @@i18n.inflect_ordinal(num.to_i, grammar, "SpelloutRules")
      end
    end
  end
end
