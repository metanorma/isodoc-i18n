module IsoDoc
  class I18n
    # Use comprehensive CJK definition from metanorma-utils
    # This includes Han, Katakana, Hiragana, Hangul, Bopomofo
    # and all CJK extensions
    ZH_CHAR = "(#{Metanorma::Utils::CJK})".freeze
    LATIN_PUNCT = /[:,.()\[\];?!-]/.freeze
    # CJK character which is not punctuation
    ZH_NON_PUNCT = "(#{
      [
        Metanorma::Utils.singleton_class::HAN,
        Metanorma::Utils.singleton_class::HAN_IDC,
        Metanorma::Utils.singleton_class::KANBUN,
        Metanorma::Utils.singleton_class::CJK_COMPAT_IDEOGRAPHS,
        Metanorma::Utils.singleton_class::HAN_COMPAT_IDEOGRAPHS,
        Metanorma::Utils.singleton_class::HANGUL,
        Metanorma::Utils.singleton_class::HIRAGANA,
        Metanorma::Utils.singleton_class::KATAKANA,
        Metanorma::Utils.singleton_class::BOPOMOFO,
      ].join("|")})".freeze

    # Condition for converting punctuation to double width,
    # in case of options[:proportional_mixed_cjk]
    # 1. (Strict condition) CJK before, CJK after, modulo ignorable characters:
    # 1a. CJK character, or start of string. Latin spaces optional.
    ZH1_PUNCT = /(#{ZH_CHAR}|^)(\s*)$/xo.freeze
    # 1b. Latin spaces optional, Latin punct which will also convert to CJK,
    # CJK character, or end of string.
    ZH2_PUNCT = /^\s*#{LATIN_PUNCT}*(#{ZH_CHAR}|$)/xo.freeze
    # 2. CJK before, space after:
    # 2a. CJK char, followed by optional Latin punct which will also convert to CJK
    ZH1_NO_SPACE = /#{ZH_CHAR}#{LATIN_PUNCT}*$/xo.freeze
    # 2b. optional Latin punct which wil also convert to CJK, then space
    OPT_PUNCT_SPACE = /^($|#{LATIN_PUNCT}*\s)/xo.freeze

    # Chinese numerals (common + formal/financial forms)
    # Explicit characters needed because Chinese numeral ideographs
    # are not tagged with Unicode Number property
    # Using alternation instead of character class to properly include \p{N}
    ZH_NUMERALS = "(?:[零一二三四五六七八九十百千万亿壹贰叁肆伍陆柒捌玖拾佰仟萬億兆]|\\p{N})".freeze

    # Contexts for converting en-dashes to full-width
    # Before: CJK or start of string, no digits
    ZH1_DASH = /(#{ZH_CHAR}|^)(?<!=#{ZH_NUMERALS})$/xo.freeze
    # After: no optional digits, CJK or end of string
    ZH2_DASH = /^(?!#{ZH_NUMERALS})(#{ZH_CHAR}|$)/xo.freeze
    # Before: CJK or start of string, optional digits
    ZH1_NUM_DASH = /#{ZH_NUMERALS}$/xo.freeze
    # After: optional digits, CJK or end of string
    ZH2_NUM_DASH = /^#{ZH_NUMERALS}/xo.freeze

    ZH_PUNCT_CONTEXTS =
      [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE],
       [/(\s|^)$/, /^#{ZH_CHAR}/o]].freeze

    # map of YAML punct keys to auto-text Latin equivalents
    ZH_PUNCT_AUTOTEXT = {
      colon: ":",
      comma: ",",
      # "enum-comma": ",", # enum-comma is ambiguous with comma
      semicolon: ";",
      period: ".",
      "close-paren": ")",
      "open-paren": "(",
      "close-bracket": "]",
      "open-bracket": "[",
      "question-mark": "?",
      "exclamation-mark": "!",
      "em-dash": "—",
      "open-quote": "“",
      "close-quote": "”",
      "open-nested-quote": "’",
      "close-nested-quote": "’",
      ellipse: "…",
    }.freeze

    # Pre-defined punctuation mappings for efficiency
    def init_zh_punct_map
      ZH_PUNCT_AUTOTEXT.each_with_object([]) do |(k, v), m|
        @labels.dig("punct", k.to_s) or next
        m << [v, @labels["punct"][k.to_s], ZH_PUNCT_CONTEXTS]
      end
    end

    def l10n_zh(text, script, options)
      script ||= "Hans"
      t, text_cache, xml, prev, _foll, esc_indices = l10n_prep(text, options)
      t.each_with_index do |n, i|
        next if esc_indices.include?(i) # Skip escaped nodes

        # Adjust index if prev context prepended
        prev_ctx, foll_ctx = l10n_context_cached(text_cache, prev ? i + 1 : i)
        text = cleanup_entities(n.text, is_xml: false)
        n.content = l10_zh1(text, prev_ctx, foll_ctx, script, options)
      end
      to_xml(xml) #.gsub(/<\/?em>|<\/?strong>|<\/?i>|<\/?b>/, "")
    end

    # note: we can't differentiate comma from enumeration comma 、
    # def l10_zh1(text, _script)
    def l10_zh1(text, prev, foll, _script, options)
      r = l10n_zh_punct(text, prev, foll, options)
      r = l10n_zh_remove_space(r, prev, foll)
      l10n_zh_dash(r, prev, foll)
    end

    def l10n_zh_punct(text, prev, foll, options)
      # Use pre-defined mapping for better performance
      @zh_punct_map ||= init_zh_punct_map
      @zh_punct_map.each do |mapping|
        punct_from, punct_to, regexes = mapping
        options[:proportional_mixed_cjk] or regexes = nil
        text = l10n_gsub(text, prev, foll, [punct_from, punct_to],
                         regexes)
      end
      text
    end

    def l10n_zh_dash(text, prev, foll)
      text = l10n_gsub(text, prev, foll, ["–", @labels.dig("punct", "en-dash")],
                       [[ZH1_DASH, ZH2_DASH]])
      l10n_gsub(text, prev, foll, ["–", @labels.dig("punct", "number-en-dash")],
                [[ZH1_NUM_DASH, ZH2_NUM_DASH]])
    end

    def l10n_zh_remove_space(text, prev, foll)
      text = l10n_gsub(text, prev, foll, [/\s+/, ""],
                       [[/(#{ZH_CHAR})$/o, /^#{ZH_CHAR}/o]])
      if sep = @labels.dig("punct", "cjk-latin-separator")
        # Skip over punctuation to find Latin letters/numbers
        text = l10n_gsub(text, prev, foll, [/\s+/, sep],
                         [[/#{ZH_CHAR}$/o, /^\p{P}*[\p{Latin}\p{N}]/o]])
        l10n_gsub(text, prev, foll, [/\s+/, sep],
                  [[/[\p{Latin}\p{N}]\p{P}*$/o, /^#{ZH_NON_PUNCT}/o]])
      else
        l10n_gsub(text, prev, foll, [/\s+/, ""],
                  [[/#{ZH_CHAR}$/o, /^(\d|[A-Za-z](#{ZH_CHAR}|$))/o]])
      end
    end

    def self.cjk_extend(text)
      cjk_extend(text)
    end

    def cjk_extend(title)
      @c.decode(title).chars.map.with_index do |n, i|
        if i.zero? || !interleave_space_cjk?(title[i - 1] + title[i])
          n
        else "\u3000#{n}"
        end
      end.join
    end

    def interleave_space_cjk?(text)
      text.size == 2 or return
      ["\u2014\u2014", "\u2025\u2025", "\u2026\u2026",
       "\u22ef\u22ef"].include?(text) ||
        /\d\d|\p{Latin}\p{Latin}|[[:space:]]/.match?(text) ||
        /^[\u2018\u201c(\u3014\[{\u3008\u300a\u300c\u300e\u3010\u2985\u3018\u3016\u00ab\u301d]/.match?(text) ||
        /[\u2019\u201d)\u3015\]}\u3009\u300b\u300d\u300f\u3011\u2986\u3019\u3017\u00bb\u301f]$/.match?(text) ||
        /[\u3002.\u3001,\u30fb:;\u2010\u301c\u30a0\u2013!?\u203c\u2047\u2048\u2049]/.match?(text) and return false
      true
    end
  end
end
