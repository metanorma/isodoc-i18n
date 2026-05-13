require "date"
require_relative "extended_date"

module IsoDoc
  class I18n
    def date(value, format)
      ExtendedDateFormatter.new(
        lang: @lang, script: @script,
        calendar: @cal, calendar_en: @cal_en
      ).format(value, format)
    end
  end
end
