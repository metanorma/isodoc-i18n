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
    c = IsoDoc::I18n.new("en", "Latn", "spec/assets/new.yaml")
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

  it "does Chinese localisation" do
    c = IsoDoc::I18n.new("zh", "Hans")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界。）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> (你好， 世界。）"
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

  it "does boolean conjunctions" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.boolean_conj([], "and")).to eq ""
    expect(c.boolean_conj(%w(a), "and")).to eq "a"
    expect(c.boolean_conj(%w(a b), "and")).to eq "a and b"
    expect(c.boolean_conj(%w(a b c), "and")).to eq "a, b, and c"
    expect(c.boolean_conj(%w(a b c d), "and")).to eq "a, b, c, and d"
  end

  it "does German ordinals" do
    c = IsoDoc::I18n.new("de", "Latn", "spec/assets/de.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "fünfte"
  end

  it "does Chinese ordinals" do
    c = IsoDoc::I18n.new("zh", "Hans", "spec/assets/zh-Hans.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "第五"
  end

  it "does Klingon ordinals" do
    c = IsoDoc::I18n.new("tlh", "Hans", "spec/assets/zh-Hans.yaml")
    term = c.inflection[c.edition]
    expect(c.inflect_ordinal(5, term, "SpelloutRules"))
      .to eq "fifth"
  end
end
