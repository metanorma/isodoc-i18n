require "isodoc-i18n"

RSpec.describe IsoDoc::ExtendedDateFormatter do
  describe "byte-identical fallback for legacy strftime tokens" do
    it "passes plain Ruby strftime directives through unchanged" do
      f = described_class.new(lang: "en", script: "Latn")
      expect(f.format("2011-02-03", "%F")).to eq "2011-02-03"
      expect(f.format("2011-02-03T09:04:05", "%F %T"))
        .to eq "2011-02-03 09:04:05"
      expect(f.format("2011-02-03", "%-m %Y")).to eq "2 2011"
    end

    it "treats %_ as a literal space (legacy alias)" do
      f = described_class.new(lang: "en", script: "Latn")
      expect(f.format("2011-02-03", "%-m%_%Y")).to eq "2 2011"
      expect(f.format("2011-02-03T09:04:05", "%F%_%T"))
        .to eq "2011-02-03 09:04:05"
    end

    it "localises %B/%b/%h month names via twitter_cldr" do
      en = described_class.new(lang: "en", script: "Latn")
      ga = described_class.new(lang: "ga", script: "Latn")
      expect(en.format("2011-02-03", "%B")).to eq "February"
      expect(en.format("2011-02-03", "%b")).to eq "Feb"
      expect(en.format("2011-02-03", "%h")).to eq "Feb"
      expect(ga.format("2011-02-03", "%B")).to eq "Feabhra"
      expect(ga.format("2011-02-03", "%b")).to eq "Feabh"
    end

    it "localises %A/%a day names via twitter_cldr" do
      en = described_class.new(lang: "en", script: "Latn")
      ga = described_class.new(lang: "ga", script: "Latn")
      expect(en.format("2011-02-03", "%A")).to eq "Thursday"
      expect(en.format("2011-02-03", "%a")).to eq "Thu"
      expect(ga.format("2011-02-03", "%A")).to eq "Déardaoin"
      expect(ga.format("2011-02-03", "%a")).to eq "Déar"
    end

    it "upcases %^B / %^A etc." do
      ga = described_class.new(lang: "ga", script: "Latn")
      expect(ga.format("2011-02-03", "%^A%_%^B")).to eq "DÉARDAOIN FEABHRA"
    end

    it "localises %P/%p periods" do
      en = described_class.new(lang: "en", script: "Latn")
      ga = described_class.new(lang: "ga", script: "Latn")
      expect(en.format("2011-02-03T09:04:05", "%p")).to eq "AM"
      expect(en.format("2011-02-03T21:04:05", "%P")).to eq "pm"
      expect(ga.format("2011-02-03T09:04:05", "%p")).to eq "R.N."
      expect(ga.format("2011-02-03T21:04:05", "%P")).to eq "i.n."
    end
  end

  describe "Japanese era (%EY / %Ey / %EC)" do
    let(:f) { described_class.new(lang: "ja", script: "Jpan") }

    it "renders %EY as era name + Arabic-numeric era year by default" do
      # The metanorma-plateau#138 acceptance target.
      expect(f.format("2024-09-30", "%EY年%-m月%-d日")).to eq "令和6年9月30日"
    end

    it "renders %EY[spellout] with kanji era year (legacy JIS shape)" do
      # Positional kanji throughout (六, 九, 三十) — matches the legacy JIS
      # `gsub(/(\d+)/) { |n| n.to_rbnf_s(SpelloutRules, spellout-cardinal) }`
      # post-processor.
      expect(f.format("2024-09-30",
                      "%EY[spellout]年%Om[spellout]月%Od[spellout]日"))
        .to eq "令和六年九月三十日"
    end

    it "renders %Ey alone as the era year only" do
      expect(f.format("2024-09-30", "%Ey")).to eq "6"
      expect(f.format("2024-09-30", "%Ey[spellout]")).to eq "六"
    end

    it "renders %EC as the era name only" do
      expect(f.format("2024-09-30", "%EC")).to eq "令和"
    end

    it "falls back to plain year for pre-Meiji dates" do
      # japanese_calendar.era_year raises before 1868
      expect(f.format("1800-01-01", "%EY")).to eq "1800"
    end
  end

  describe "alternative numbering (%Om / %Od / %OY / %Oy)" do
    it "renders Roman months for Continental bibliographic style" do
      f = described_class.new(lang: "en", script: "Latn")
      expect(f.format("2024-09-30", "%-d.%Om[roman].%Y")).to eq "30.IX.2024"
      expect(f.format("2024-09-30",
                      "%-d.%Om[roman-lower].%Y")).to eq "30.ix.2024"
    end

    it "renders hanidec digits for ja month/day" do
      f = described_class.new(lang: "ja", script: "Jpan")
      expect(f.format("2024-09-30", "%Om[hanidec]月%Od[hanidec]日"))
        .to eq "九月三〇日"
    end

    it "renders spellout numbering for ja year-of-era" do
      f = described_class.new(lang: "ja", script: "Jpan")
      expect(f.format("2024-09-30", "%Oy[spellout]")).to eq "二十四"
    end

    it "rejects unknown numbering systems with a clear message" do
      f = described_class.new(lang: "en", script: "Latn")
      expect { f.format("2024-09-30", "%Om[klingon]") }
        .to raise_error(ArgumentError, /numbering system/)
    end
  end

  describe "calendar dispatch" do
    it "raises NotImplementedError for documented-but-unwired calendars" do
      f = described_class.new(lang: "en", script: "Latn")
      expect { f.format("2024-09-30", "%EY[cal=roc]") }
        .to raise_error(NotImplementedError, /calendar :roc/)
      expect { f.format("2024-09-30", "%EY[cal=buddhist]") }
        .to raise_error(NotImplementedError, /:buddhist/)
    end

    it "treats gregorian as the default for non-Japanese locales" do
      f = described_class.new(lang: "en", script: "Latn")
      expect(f.format("2024-09-30", "%EY")).to eq "2024"
      expect(f.format("2024-09-30", "%Ey")).to eq "24"
      expect(f.format("2024-09-30", "%EC")).to eq ""
    end
  end

  describe "format_iso_date convenience wrapper" do
    let(:fmts) { { year: "%Y", year_month: "%B %Y", full: "%d %B %Y" } }

    it "picks the year-only format for a four-digit input" do
      expect(described_class.format_iso_date("2024", lang: "en", **fmts))
        .to eq "2024"
    end

    it "picks the year-month format for a YYYY-MM input" do
      expect(described_class.format_iso_date("2024-09", lang: "en", **fmts))
        .to eq "September 2024"
    end

    it "picks the full format for a YYYY-MM-DD input" do
      expect(described_class.format_iso_date("2024-09-30", lang: "en", **fmts))
        .to eq "30 September 2024"
    end

    it "returns the input unchanged for nil and empty strings" do
      expect(described_class.format_iso_date(nil, lang: "en", **fmts))
        .to be_nil
      expect(described_class.format_iso_date("", lang: "en", **fmts))
        .to eq ""
    end

    it "returns the input unchanged when the matching format is nil" do
      out = described_class.format_iso_date(
        "2024",
        lang: "en",
        year: nil,
        year_month: "%B %Y",
        full: "%d %B %Y",
      )
      expect(out).to eq "2024"
    end

    it "passes through script and calendar options to the formatter" do
      out = described_class.format_iso_date(
        "2024-09-30",
        lang: "ja",
        calendar: "japanese",
        year: nil,
        year_month: nil,
        full: "%EY[numeric]年%-m月%-d日",
      )
      expect(out).to eq "令和6年9月30日"
    end
  end
end
