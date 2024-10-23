module IsoDoc
  class I18n
    def self.l10n(text, lang = @lang, script = @script, locale = @locale)
      l10n(text, lang, script, locale)
    end

    # function localising spaces and punctuation.
    def l10n(text, lang = @lang, script = @script, locale = @locale)
      %w(zh ja ko).include?(lang) and text = l10n_zh(text, script)
      lang == "fr" && text = l10n_fr(text, locale || "FR")
      bidiwrap(text, lang, script)
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

    # CJK
    def l10n_zh(text, script = "Hans")
      xml = Nokogiri::XML::DocumentFragment.parse(text)
      xml.traverse do |n|
        n.text? or next
        n.replace(l10_zh1(cleanup_entities(n.text, is_xml: false), script))
      end
      xml.to_xml(encoding: "UTF-8").gsub(/<b>/, "").gsub("</b>", "")
        .gsub(/<\?[^>]+>/, "")
    end

    def l10n_fr(text, locale)
      xml = Nokogiri::XML::DocumentFragment.parse(text)
      xml.traverse do |n|
        next unless n.text?

        n.replace(l10n_fr1(cleanup_entities(n.text, is_xml: false), locale))
      end
      xml.to_xml(encoding: "UTF-8")
    end

    ZH_CHAR = "\\p{Han}|\\p{In CJK Symbols And Punctuation}|" \
              "\\p{In Halfwidth And Fullwidth Forms}".freeze

    # note: we can't differentiate comma from enumeration comma 、
    def l10_zh1(text, _script)
      l10n_zh_dash(l10n_zh_remove_space(l10n_zh_punct(text)))
    end

    # CJK punct if (^|CJK).($|CJK)
    def l10n_zh_punct(text)
      [":：", ",，", ".．", ")）", "]］", ";；", "?？", "!！", "(（", "[［"].each do |m|
        text = text.gsub(/(?<=#{ZH_CHAR}|^) # CJK character, or start of string
    (\s*)                  # Latin spaces optional
    #{Regexp.quote(m[0])}  # Latin punctuation we want to convert to CJK
    (?=   \s*              # followed (lookahead) by ignorable Latin spaces
      [:,.()\[\];?!-]*     # Latin punctuation which we will also convert to CJK
      (#{ZH_CHAR}|$)       # CJK character, or end of string
    ) /x, "\\1#{m[1]}")
      end
      text
    end

    def l10n_zh_dash(text)
      text.gsub(/(?<=#{ZH_CHAR}|^) # CJK character, or start of string
                (\d*)              # optional digits
                –                  # en-dash
                (\d*)              # optional digits
                (#{ZH_CHAR}|$)     # CJK character, or end of string
                /xo, "\\1～\\2\\3")
    end

    def l10n_zh_remove_space(text)
      text.gsub(/(?<=#{ZH_CHAR}) (?=#{ZH_CHAR})/o, "")
        .gsub(/(?<=\d) (?=#{ZH_CHAR})/o, "")
        .gsub(/(?<=#{ZH_CHAR}) (?=\d)/o, "")
        .gsub(/(?<=#{ZH_CHAR}) (?=[A-Za-z](#{ZH_CHAR}|$))/o, "")
    end

    def l10n_fr1(text, locale)
      text = text.gsub(/(?<=\p{Alnum})([»›;?!])(?=\s)/, "\u202f\\1")
      text = text.gsub(/(?<=\p{Alnum})([»›;?!])$/, "\u202f\\1")
      text = text.gsub(/^([»›;?!])/, "\u202f\\1")
      text = text.gsub(/([«‹])/, "\\1\u202f")
      colonsp = locale == "CH" ? "\u202f" : "\u00a0"
      text = text.gsub(/(?<=\p{Alnum})(:)(?=\s)/, "#{colonsp}\\1")
      text = text.gsub(/(?<=\p{Alnum})(:)$/, "#{colonsp}\\1")
      text.gsub(/^(:\s)/, "#{colonsp}\\1")
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
