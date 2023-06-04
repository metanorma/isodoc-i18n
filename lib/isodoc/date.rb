require "date"

module IsoDoc
  class I18n
    def date(value, format)
      date_i18n(DateTime.iso8601(value)
        .strftime(convert_date_format(format)))
    end

    def convert_date_format(fmt)
      fmt.gsub(/%_/, " ")
        .gsub(/%(\^?)([BbhPpAa])/, "%\u200c\\1\\2<%\\2>")
    end

    def date_i18n(val)
      day_i18n(month_i18n(am_pm_i18n(val)))
    end

    def am_pm_i18n(val)
      val.gsub(/%\u200cP<am>/, @cal.periods[:am].downcase)
        .gsub(/%\u200cP<pm>/, @cal.periods[:pm].downcase)
        .gsub(/%\u200cp<AM>/, @cal.periods[:am].upcase)
        .gsub(/%\u200cp<PM>/, @cal.periods[:pm].upcase)
    end

    def month_i18n(val)
      { B: :wide, b: :abbreviated, h: :abbreviated }.each do |f, t|
        @cal_en.calendar_data[:months][:format][t].each do |k, v|
          m = @cal.calendar_data[:months][:format][t][k]
          val.gsub!(/%\u200c#{f}<#{v}>/, m)
          val.gsub!(/%\u200c\^#{f}<#{v}>/, m.upcase)
        end
      end
      val
    end

    def day_i18n(val)
      { A: :wide, a: :abbreviated }.each do |f, t|
        @cal_en.calendar_data[:days][:format][t].each do |k, v|
          m = @cal.calendar_data[:days][:format][t][k]
          val.gsub!(/%\u200c#{f}<#{v}>/, m)
          val.gsub!(/%\u200c\^#{f}<#{v}>/, m.upcase)
        end
      end
      val
    end
  end
end

#   %B - The full month name (``January'')
#           %^B  uppercased (``JANUARY'')
#   %b - The abbreviated month name (``Jan'')
#           %^b  uppercased (``JAN'')
#   %h - Equivalent to %b
#   %P - Meridian indicator, lowercase (``am'' or ``pm'')
#   %p - Meridian indicator, uppercase (``AM'' or ``PM'')
#   %A - The full weekday name (``Sunday'')
#           %^A  uppercased (``SUNDAY'')
#   %a - The abbreviated name (``Sun'')
#           %^a  uppercased (``SUN'')
