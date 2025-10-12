require "metanorma-utils"
require_relative "l10n_cjk"

module IsoDoc
  class I18n
    def self.l10n(text, lang = @lang, script = @script, options = {})
      l10n(text, lang, script, options)
    end

    # function localising spaces and punctuation
    # options[:prev] and options[:foll] are optional context strings
    # options[:proportional_mixed_cjk] allows contextual full-width vs
    # half-width punctuation
    def l10n(text, lang = @lang, script = @script, options = {})
      locale = options[:locale] || @locale
      %w(zh ja ko).include?(lang) and
        text = l10n_zh(text, script, options)
      lang == "fr" and
        text = l10n_fr(text, locale || "FR", options)
      text&.gsub!(/<esc>|<\/esc>/, "") # Strip esc tags
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

    def l10n_prep(text, options)
      xml = Nokogiri::XML::DocumentFragment.parse(text)
      t = xml.xpath(".//text()").reject { |node| node.text.empty? }
      text_cache = build_text_cache(t, options[:prev], options[:foll])

      # Identify which text nodes are within <esc> tags
      esc_indices = Set.new
      t.each_with_index do |node, i|
        esc_indices.add(i) if node.ancestors("esc").any?
      end

      [t, text_cache, xml, options[:prev], options[:foll], esc_indices]
    end

    # Cache text content once per method call to avoid repeated .text calls
    # Build text cache with optional prepended/appended context
    # Also, reduce multiple spaces to single, to avoid miscrecognition of space
    def build_text_cache(text_nodes, prev_context = nil, foll_context = nil)
      text_cache = text_nodes.map(&:text).map { |x| x.gsub("/\s+/", " ") }
      text_cache.unshift(prev_context) if prev_context
      text_cache.push(foll_context) if foll_context
      text_cache
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

    def l10n_fr(text, locale, options)
      t, text_cache, xml, prev, _foll, esc_indices = l10n_prep(text, options)
      t.each_with_index do |n, i|
        next if esc_indices.include?(i) # Skip escaped nodes

        prev_ctx, foll_ctx = l10n_context_cached(text_cache, prev ? i + 1 : i)
        text = cleanup_entities(n.text, is_xml: false)
        n.replace(l10n_fr1(text, prev_ctx, foll_ctx, locale))
      end
      to_xml(xml)
    end

    # text: string we are scanning for instances of delim[0] to replace
    # prev: string preceding text, as additional token of context
    # foll: string following text, as additional token of context
    # delim: delim[0] is the symbol we want to replace, delim[1] its replacement
    # regexes: a list of regex pairs: the context before the found token,
    # and the context after the found token, under which replacing it
    # with delim[1] is permitted. If regex is nil, always allow the replacement
    def l10n_gsub(text, prev, foll, delim, regexes)
      delim[1] or return text
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
      [prev, context.reject(&:empty?), foll].flatten
    end

    def l10_context_valid?(context, idx, delim, regex)
      l10n_context_found_delimiter?(context[idx], delim) or return false
      regex.nil? and return true
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

    def l10n_fr1(text, prev, foll, locale)
      text = l10n_gsub(text, prev, foll, [/[»›;?!]/, "\u202f\\0"],
                       [[/\p{Alnum}$/, /^(\s|$)/]])
      text = l10n_gsub(text, prev, foll, [/[«‹]/, "\\0\u202f"],
                       [[/$/, /^(?!\p{Zs})./]])
      colonsp = locale == "CH" ? "\u202f" : "\u00a0"
      l10n_gsub(text, prev, foll, [":", "#{colonsp}\\0"],
                [[/\p{Alnum}$/, /^(\s|$)/]])
    end

    def to_xml(node)
      node&.to_xml(encoding: "UTF-8", indent: 0,
                   save_with: Nokogiri::XML::Node::SaveOptions::AS_XML)
    end
  end
end
