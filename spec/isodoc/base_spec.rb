require "spec_helper"

RSpec.describe IsoDoc::I18n do
  it "has a version number" do
    expect(IsoDoc::I18n::VERSION).not_to be nil
  end

  it "loads language files" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.text).to eq "text"
    expect(c.at).to eq "at"
    expect(c.language).to eq "en"
    expect(c.script).to eq "Latn"
  end

  it "manipulates i18n class" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.get["text"]).to eq "text"
    expect(c.get["fred"]).to be_nil
    c.set("fred", "frederic")
    expect(c.get["fred"]).to eq "frederic"
  end

  it "loads default for missing language files" do
    c = IsoDoc::I18n.new("tlh", "Klin")
    expect(c.text).to eq "text"
    expect(c.at).to eq "at"
    expect(c.language).to eq "tlh"
    expect(c.script).to eq "Klin"
  end

  it "loads language file overrides" do
    c = IsoDoc::I18n.new("en", "Latn", i18nyaml: "spec/assets/new.yaml")
    expect(c.text).to eq "text2"
    expect(c.at).to eq "at"
    expect(c.hash.to_s).to be_equivalent_to '{"key1"=>"val1", "key2"=>"val2"}'
    expect(c.arr.to_s).to eq '["arr1", "arr2"]'
  end

  it "loads language hash overrides" do
    c = IsoDoc::I18n.new("en", "Latn",
                         i18nhash: YAML.load_file("spec/assets/new.yaml"))
    expect(c.text).to eq "text2"
    expect(c.at).to eq "at"
    expect(c.hash.to_s).to be_equivalent_to '{"key1"=>"val1", "key2"=>"val2"}'
    expect(c.arr.to_s).to eq '["arr1", "arr2"]'
  end

  it "does English localisation" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("<a>Code (he<b>l</b>lo, world.)</a>"))
      .to be_equivalent_to "<a>Code (he<b>l</b>lo, world.)</a>"
  end

  it "does Traditional Chinese localisation" do
    c = IsoDoc::I18n.new("zh", "Hant")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code （hello， world．）"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界．）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> （你好， 世界．）"
  end

  it "does Simplified Chinese localisation" do
    c = IsoDoc::I18n.new("zh", "Hans")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code （hello， world．）"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界．）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> （你好， 世界．）"
  end

  it "does Hebrew RTL localisation" do
    c = IsoDoc::I18n.new("en", "Hebr")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("Code (hello, world.)", "en", "Latn"))
      .to be_equivalent_to "&#x200e;Code (hello, world.)&#x200e;"
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.l10n("Code (hello, world.)", "en", "Hebr"))
      .to be_equivalent_to "&#x200f;Code (hello, world.)&#x200f;"
  end

  it "does Arabic RTL localisation" do
    c = IsoDoc::I18n.new("en", "Arab")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("Code (hello, world.)", "en", "Latn"))
      .to be_equivalent_to "&#x200e;Code (hello, world.)&#x200e;"
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.l10n("Code (hello, world.)", "en", "Arab"))
      .to be_equivalent_to "&#x61c;Code (hello, world.)&#x61c;"
  end

  it "does French localisation" do
    e = HTMLEntities.new
    c = IsoDoc::I18n.new("fr", "Latn")
    expect(e.encode(c.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#xa0;: code&#x202f;!"
    expect(e.encode(c.l10n("Code; &#xab;code&#xbb; and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#xa0;: code&#x202f;!"
    c = IsoDoc::I18n.new("fr", "Latn", locale: "FR")
    expect(e.encode(c.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#xa0;: code&#x202f;!"
    c = IsoDoc::I18n.new("fr", "Latn", locale: "CH")
    expect(e.encode(c.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#x202f;: code&#x202f;!"
    expect(e.encode(c.l10n("http://xyz a;b"), :hexadecimal))
      .to be_equivalent_to "http://xyz a;b"
  end

  it "does boolean conjunctions in English" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.boolean_conj([], "and")).to eq ""
    expect(c.boolean_conj(%w(a), "and")).to eq "a"
    expect(c.boolean_conj(%w(a b), "and")).to eq "a and b"
    expect(c.boolean_conj(%w(a b c), "and")).to eq "a, b, and c"
    expect(c.boolean_conj(%w(a b c d), "and")).to eq "a, b, c, and d"
  end

  it "does boolean conjunctions in Traditional Chinese" do
    c = IsoDoc::I18n.new("zh", "Hant",
                         i18nhash: YAML.load_file("spec/assets/new.yaml"))
    expect(c.boolean_conj([], "and")).to eq ""
    expect(c.boolean_conj(%w(a), "and")).to eq "a"
    expect(c.boolean_conj(%w(a b), "and")).to eq "a and b"
    expect(c.boolean_conj(%w(a b c), "and")).to eq "a、b與c"
    expect(c.boolean_conj(%w(a b c d), "and")).to eq "a、b、c與d"
  end

  it "does German ordinals" do
    c = IsoDoc::I18n.new("de", "Latn", i18nyaml: "spec/assets/de.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "fünfte"
  end

  it "does Chinese ordinals" do
    c = IsoDoc::I18n.new("zh", "Hans", i18nyaml: "spec/assets/zh-Hans.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "第五"
    c = IsoDoc::I18n.new("zh", "Hant", i18nyaml: "spec/assets/zh-Hans.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "第五"
  end

  it "does Klingon ordinals" do
    c = IsoDoc::I18n.new("tlh", "Hans", i18nyaml: "spec/assets/zh-Hans.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "fifth"
  end

  it "does inflections" do
    c = IsoDoc::I18n.new("en", "Latn", i18nyaml: "spec/assets/new.yaml")
    expect(c.inflect("John", number: "sg")).to eq "John"
    expect(c.inflect("Fred", number: "sg")).to eq "Fred"
    expect(c.inflect("Fred", number: "pl")).to eq "Freds"
    expect(c.inflect("Fred", number: "du")).to eq "Fred"
    expect(c.inflect("Fred", tense: "pres")).to eq "Fred"
    expect(c.inflect("Man", case: "dat")).to eq "viri"
    expect(c.inflect("Man", number: "sg", case: "dat")).to eq "viri"
    expect(c.inflect("Man", number: "pl", case: "acc")).to eq "virem"
    expect(c.inflect("Woman", number: "pl", case: "gen")).to eq "mulierum"
    expect(c.inflect("Good", number: "pl", case: "gen")).to eq "bonorum"
    expect(c.inflect("Good", number: "pl", case: "gen", gender: "fem"))
      .to eq "bonarum"
    expect(c.inflect("Walk", person: "2nd")).to eq "ambulas"
    expect(c.inflect("Walk", person: "2nd", number: "pl", mood: "subj"))
      .to eq "ambuletis"
  end
end
