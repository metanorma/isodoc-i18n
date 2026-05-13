require "date"
require "twitter_cldr"

module IsoDoc
  # Extended strftime-style date formatter on top of Ruby's +Date#strftime+.
  #
  # Adds three POSIX-flavoured surfaces:
  #
  #   %E[YyC]              - era year (calendar-aware)
  #   %O[mdYy]             - alternative numbering for date components
  #   %_                   - legacy alias for a literal space (kept for
  #                          backwards compatibility with IsoDoc::I18n#date)
  #
  # Optional square-bracket-delimited ARGS may follow the conversion letter
  # for %E* and %O* tokens (e.g. +%EY[numeric]+, +%Om[roman]+).
  # Square brackets rather than braces, so format strings remain safe to
  # inline inside Liquid +{{...}}+ templates.
  #
  # The localised name directives (%B, %b, %h, %A, %a, %P, %p) are also
  # routed through the formatter so they pick up CLDR locale data without
  # the previous ZWNJ-marker hack in IsoDoc::I18n.
  #
  # ARGS is a comma-separated list of either a positional numbering-system
  # name (numeric, spellout, hanidec, roman, roman-lower) or +key=value+
  # pairs. The only key currently honoured is +cal=+ (japanese|gregorian);
  # other CLDR calendar identifiers (roc, buddhist, persian, islamic,
  # indian, hebrew) are reserved as documented extension points and raise
  # NotImplementedError today.
  class ExtendedDateFormatter
    TOKEN_RX = /
      %_                                  |
      %\^?[BbhPpAa]                       |
      %E[YyC](?:\[[^\]]*\])?              |
      %O[mdYy](?:\[[^\]]*\])?
    /x.freeze

    DAY_KEYS = %i[sun mon tue wed thu fri sat].freeze
    HANIDEC_FROM = "0123456789".freeze
    HANIDEC_TO = "〇一二三四五六七八九".freeze

    SUPPORTED_CALENDARS = %i[gregorian japanese].freeze

    def self.format(value, fmt, **opts)
      new(**opts).format(value, fmt)
    end

    # Convenience wrapper for ISO 8601 date strings of variable arity
    # (year-only, year-month, or full date). Picks one of three format
    # strings keyed by the arity of the input. Each format string may be
    # nil, in which case the input is returned unchanged for that arity.
    # Used by metanorma-flavour metadata helpers to delegate their
    # arity-branching logic instead of duplicating it per gem.
    def self.format_iso_date(isodate, year: nil, year_month: nil, full: nil,
                             **opts)
      normalized, fmt = iso_normalize(isodate, [year, year_month, full])
      return isodate if fmt.nil?

      format(normalized, fmt, **opts)
    rescue StandardError
      isodate
    end

    def self.iso_normalize(isodate, fmts)
      return [isodate, nil] if isodate.nil? || isodate.to_s.empty?

      parts = isodate.to_s.split("-")
      fmt = fmts[parts.size - 1] or return [isodate, nil]
      [[parts[0], parts[1] || "01", parts[2] || "01"].join("-"), fmt]
    end

    attr_reader :lang, :script

    def initialize(lang:, script: nil, calendar: nil, calendar_en: nil)
      @lang = lang.to_s
      @script = script
      @cal = calendar || twitter_cldr_calendar
      @cal_en = calendar_en || TwitterCldr::Shared::Calendar.new(:en)
    end

    def format(value, fmt)
      time = coerce(value)
      tokenise(fmt).map { |kind, payload| render(time, kind, payload) }.join
    end

    private

    def coerce(value)
      case value
      when DateTime, Time then value
      when Date then value.to_datetime
      else DateTime.iso8601(value.to_s)
      end
    end

    def tokenise(fmt)
      out = []
      last = 0
      fmt.to_enum(:scan, TOKEN_RX).each do
        m = Regexp.last_match
        out << [:strftime, fmt[last...m.begin(0)]] if m.begin(0) > last
        out << [:token, m[0]]
        last = m.end(0)
      end
      out << [:strftime, fmt[last..-1]] if last < fmt.length
      out
    end

    def render(time, kind, payload)
      case kind
      when :strftime then payload.empty? ? "" : time.strftime(payload)
      when :token then render_token(time, payload)
      end
    end

    def render_token(time, tok)
      return " " if tok == "%_"

      case tok
      when /\A%(\^?)([BbhPpAa])\z/
        render_localised_name(time, Regexp.last_match(1) == "^",
                              Regexp.last_match(2))
      when /\A%E([YyC])(?:\[([^\]]*)\])?\z/
        render_era(time, Regexp.last_match(1),
                   parse_args(Regexp.last_match(2)))
      when /\A%O([mdYy])(?:\[([^\]]*)\])?\z/
        render_alt_num(time, Regexp.last_match(1),
                       parse_args(Regexp.last_match(2)))
      end
    end

    def render_localised_name(time, upcase, letter)
      day = DAY_KEYS[time.wday]
      raw = case letter
            when "B" then @cal.calendar_data[:months][:format][:wide][time.month]
            when "b", "h"
              @cal.calendar_data[:months][:format][:abbreviated][time.month]
            when "A" then @cal.calendar_data[:days][:format][:wide][day]
            when "a" then @cal.calendar_data[:days][:format][:abbreviated][day]
            when "P" then @cal.periods[am_pm(time)].downcase
            when "p" then @cal.periods[am_pm(time)].upcase
            end
      upcase ? raw.upcase : raw
    end

    def am_pm(time)
      time.respond_to?(:hour) && time.hour >= 12 ? :pm : :am
    end

    def render_era(time, letter, args)
      cal = (args[:cal] || default_calendar).to_sym
      case cal
      when :japanese then render_japanese_era(time, letter, args)
      when :gregorian then render_gregorian_era(time, letter, args)
      else
        raise NotImplementedError,
              "ExtendedDateFormatter: calendar #{cal.inspect} is a " \
              "documented extension point but is not yet wired up. " \
              "Supported: #{SUPPORTED_CALENDARS.inspect}."
      end
    end

    def render_japanese_era(time, letter, args)
      require "japanese_calendar"
      d = time.is_a?(Date) ? time : Date.new(time.year, time.month, time.day)
      year = format_number(d.era_year, args)
      case letter
      when "Y" then "#{d.strftime('%JN')}#{year}"
      when "y" then year
      when "C" then d.strftime("%JN")
      end
    rescue StandardError
      case letter
      when "Y", "y" then format_number(time.year, args)
      when "C" then ""
      end
    end

    def render_gregorian_era(time, letter, args)
      case letter
      when "Y" then format_number(time.year, args)
      when "y" then format_number(time.year % 100, args)
      when "C" then ""
      end
    end

    def render_alt_num(time, letter, args)
      n = case letter
          when "m" then time.month
          when "d" then time.day
          when "Y" then time.year
          when "y" then time.year % 100
          end
      format_number(n, args)
    end

    def format_number(num, args)
      sys = args[:_positional] || args[:numbering] || "numeric"
      case sys
      when "numeric", "latn" then num.to_s
      when "spellout" then spellout(num)
      when "hanidec" then num.to_s.tr(HANIDEC_FROM, HANIDEC_TO)
      when "roman" then roman(num)
      when "roman-lower" then roman(num).downcase
      else
        raise ArgumentError,
              "ExtendedDateFormatter: numbering system #{sys.inspect} not " \
              "supported. Use one of: numeric, spellout, hanidec, roman, " \
              "roman-lower."
      end
    end

    def spellout(num)
      num.to_i.localize(twitter_cldr_lang)
        .to_rbnf_s("SpelloutRules", "spellout-cardinal")
    end

    def roman(num)
      require "roman-numerals"
      RomanNumerals.to_roman(num.to_i)
    end

    def parse_args(str)
      out = {}
      return out if str.nil? || str.empty?

      str.split(",").each do |arg|
        arg = arg.strip
        if arg.include?("=")
          k, v = arg.split("=", 2)
          out[k.strip.to_sym] = v.strip
        else
          out[:_positional] ||= arg
        end
      end
      out
    end

    def default_calendar
      @lang == "ja" ? :japanese : :gregorian
    end

    def twitter_cldr_lang
      case [@lang, @script]
      when ["zh", "Hans"] then :"zh-cn"
      when ["zh", "Hant"] then :"zh-tw"
      else @lang.to_sym
      end
    end

    def twitter_cldr_calendar
      TwitterCldr::Shared::Calendar.new(twitter_cldr_lang)
    rescue StandardError
      TwitterCldr::Shared::Calendar.new(:en)
    end
  end
end
