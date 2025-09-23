require "metanorma-utils"

module IsoDoc
  class I18n
    # Use comprehensive CJK definition from metanorma-utils
    # This includes Han, Katakana, Hiragana, Hangul, Bopomofo and all CJK extensions
    ZH_CHAR = "(#{Metanorma::Utils::CJK})".freeze
    LATIN_PUNCT = /[:,.()\[\];?!-]/.freeze
    
    # Condition for converting punctuation to double width:
    # 1. (Strict condition) CJK before, CJK after, modulo ignorable characters:
    # 1a. CJK character, or start of string. Latin spaces optional.
    ZH1_PUNCT = /(#{ZH_CHAR}|^)(\s*)$/xo.freeze 
    # 1b. Latin spaces optional, Latin punct which will also convert to CJK, 
    # CJK character, or end of string.
    ZH2_PUNCT = /^\s*#{LATIN_PUNCT}*(#{ZH_CHAR}|$)/xo.freeze
    # 2. CJK before, space after:
    # 2a.  CJK char, followed by optional Latin punct which will also convert to CJK
    ZH1_NO_SPACE = /#{ZH_CHAR}#{LATIN_PUNCT}*$/xo.freeze
    # 2b. optional Latin punct which wil also convert to CJK, then space
    OPT_PUNCT_SPACE = /^($|#{LATIN_PUNCT}*\s)/xo.freeze

    # Contexts for converting en-dashes to full-width
    # Before: CJK or start of string, optional digits
    ZH1_DASH = /(#{ZH_CHAR}|^)(\d*)$/xo.freeze
    # After: optional digits, CJK or end of string
    ZH2_DASH = /^\d*(#{ZH_CHAR}|$)/xo.freeze
    
    # Pre-defined punctuation mappings for efficiency
    ZH_PUNCT_MAP = [
      [":：", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      [",，", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      [".。", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      [")）", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      ["]］", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      [";；", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      ["?？", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      ["!！", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      ["(（", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]],
      ["[［", [[ZH1_PUNCT, ZH2_PUNCT], [ZH1_NO_SPACE, OPT_PUNCT_SPACE], [/(\s|^)$/, /^#{ZH_CHAR}/o]]]
    ].freeze

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
      t = xml.xpath(".//text()")
      # Cache text content once per method call to avoid repeated .text calls
      text_cache = t.map(&:text)
      t.each_with_index do |n, i|
        prev, foll = l10n_context_cached(text_cache, i)
        text = cleanup_entities(n.text, is_xml: false)
        n.replace(l10_zh1(text, prev, foll, script))
      end
      # Combine multiple gsub operations for better performance
      to_xml(xml).gsub(/<b>|<\/b>|<\?[^>]+>/, "")
    end

    # previous, following context of current text node:
    # do not use just the immediately adjoining text tokens for context
    # deal with spaces and empty text by just concatenating entire context
    # Optimized to avoid O(n²) complexity by using pre-cached text content
    def l10n_context_cached(text_cache, idx)
      prev = text_cache[0...idx].join
      foll = text_cache[(idx + 1)...text_cache.size].join
      [prev, foll]
    end

    # Fallback method for backward compatibility
    def l10n_context(nodes, idx)
      prev = nodes[0...idx].map(&:text).join
      foll = nodes[(idx + 1)...(nodes.size)].map(&:text).join
      [prev, foll]
    end

    def l10n_fr(text, locale)
      xml = Nokogiri::XML::DocumentFragment.parse(text)
      t = xml.xpath(".//text()")
      # Cache text content once per method call to avoid repeated .text calls
      text_cache = t.map(&:text)
      t.each_with_index do |n, i|
        prev, foll = l10n_context_cached(text_cache, i)
        text = cleanup_entities(n.text, is_xml: false)
        n.replace(l10n_fr1(text, prev, foll, locale))
      end
      to_xml(xml)
    end

    # note: we can't differentiate comma from enumeration comma 、
    # def l10_zh1(text, _script)
    def l10_zh1(text, prev, foll, _script)
      r = l10n_zh_punct(text, prev, foll)
      r = l10n_zh_remove_space(r, prev, foll)
      l10n_zh_dash(r, prev, foll)
    end

    def l10n_zh_punct(text, prev, foll)
      # Use pre-defined mapping for better performance
      ZH_PUNCT_MAP.each do |mapping|
        punct_pair, regexes = mapping
        text = l10n_gsub(text, prev, foll, [punct_pair[0], punct_pair[1]], regexes)
      end
      text
    end

    def l10n_zh_dash(text, prev, foll)
      l10n_gsub(text, prev, foll, %w(– ～), [[ZH1_DASH, ZH2_DASH]])
    end

    # text: string we are scanning for instances of delim[0] to replace
    # prev: string preceding text, as additional token of context
    # foll: string following text, as additional token of context
    # delim: delim[0] is the symbol we want to replace, delim[1] its replacement
    # regexes: a list of regex pairs: the context before the found token,
    # and the context after the found token, under which replacing it
    # with delim[1] is permitted
    def l10n_gsub(text, prev, foll, delim, regexes)
      context = l10n_gsub_context(text, prev, foll, delim) or return text
      (1...(context.size - 1)).each do |i|
        l10_context_valid?(context, i, delim, regexes) and
          context[i] = delim[1].gsub("\\0", context[i]) # Full-width equivalent
      end
      context[1...(context.size - 1)].join
    end

    # split string being scanned, and its contextual tokens before and after,
    # into array of tokens determining whether to replace instances of delim[0]
    def l10n_gsub_context(text, prev, foll, delim)
      d = delim[0].is_a?(Regexp) ? delim[0] : Regexp.quote(delim[0])
      context = text.split(/(#{d})/) # delim to replace
      context.size == 1 and return
      [prev, context, foll].flatten
    end

    def l10_context_valid?(context, idx, delim, regex)
      l10n_context_found_delimiter?(context[idx], delim) or return false
      regex.detect do |r|
        r[0].match?(context[0...idx].join) && # preceding context
          r[1].match?(context[(idx + 1)..-1].join) # foll context
      end
    end

    def l10n_context_found_delimiter?(token, delim)
      if delim[0].is_a?(Regexp) # punct to convert
        delim[0].match?(token)
      else
        token == delim[0]
      end
    end

    def l10n_zh_remove_space(text, prev, foll)
      text = l10n_gsub(text, prev, foll, [" ", ""],
                       [[/(#{ZH_CHAR}|\d)$/o, /^#{ZH_CHAR}/o]])
      l10n_gsub(text, prev, foll, [" ", ""],
                [[/#{ZH_CHAR}$/o, /^(\d|[A-Za-z](#{ZH_CHAR}|$))/o]])
    end

    def l10n_fr1(text, prev, foll, locale)
      text = l10n_gsub(text, prev, foll, [/[»›;?!]/, "\u202f\\0"],
                       [[/\p{Alnum}$/, /^(\s|$)/]])
      text = l10n_gsub(text, prev, foll, [/[«‹]/, "\\0\u202f"],
                       [[/$/, /^(?!\p{Zs})./]])
      colonsp = locale == "CH" ? "\u202f" : "\u00a0"
      l10n_gsub(text, prev, foll, [":", "#{colonsp}\\0"],
                [[/\p{Alnum}$/, /^(\s|$)/]])
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

    def to_xml(node)
      node&.to_xml(encoding: "UTF-8", indent: 0,
                   save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end
  end
end
