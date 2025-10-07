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
    expect(c.labels["text"]).to eq("text2")
    expect(c.at).to eq "at"
    expect(c.hashx).to be_equivalent_to({ "key1" => "val1", "key2" => "val2" })
    expect(c.arrx).to eq(["arr1", "arr2"])
    expect(c.labels["arrx"]).to eq(["arr1", "arr2"])
    expect(c.get).not_to eq("text2")
    expect(c.labels["get"]).to eq("ABC")
  end

  it "loads language hash overrides" do
    c = IsoDoc::I18n.new("en", "Latn",
                         i18nhash: YAML.load_file("spec/assets/new.yaml"))
    expect(c.text).to eq "text2"
    expect(c.at).to eq "at"
    expect(c.hashx).to be_equivalent_to({ "key1" => "val1", "key2" => "val2" })
    expect(c.arrx).to eq ["arr1", "arr2"]
  end

  it "does English localisation" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("<a>Code (he<b>l</b>lo, world.)</a>"))
      .to be_equivalent_to "<a>Code (he<b>l</b>lo, world.)</a>"
  end

  it "does Traditional Chinese localisation" do
    c = IsoDoc::I18n.new("zh", "Hant", i18nyaml: "spec/assets/zh-Hans.yaml")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code （hello， world。）"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界。）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> （你好， 世界。）"
    expect(c.l10n("3–9a, 算3–9, 壹–贰,  三–三"))
      .to be_equivalent_to "3〜9a，算3〜9，壹〜贰，  三〜三"
    expect(c.l10n("Paris–New York, 巴黎–纽约"))
      .to be_equivalent_to "Paris–New York，巴黎–纽约"
    expect(c.l10n("3<span>)</span>算<span>)</span>3)<span>算)</span>3"))
      .to be_equivalent_to "3<span>）</span>算<span>）</span>3）<span>算）</span>3"
    expect(c.l10n("<span>)</span>算<span>)</span>)<span>算)</span>"))
      .to be_equivalent_to "<span>）</span>算<span>）</span>）<span>算）</span>"
  end

  it "does Simplified Chinese localisation" do
    c = IsoDoc::I18n.new("zh", "Hans", i18nyaml: "spec/assets/zh-Hans.yaml")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code （hello， world。）"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界。）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> （你好， 世界。）"
  end

  it "does Japanese localisation" do
    c = IsoDoc::I18n.new("ja", "Jpan", i18nyaml: "spec/assets/zh-Hans.yaml")
    expect(c.l10n("Code (hello, world.)"))
      .to be_equivalent_to "Code （hello， world。）"
    expect(c.l10n("计算机代码 (你好, 世界.)"))
      .to be_equivalent_to " 计算机代码（你好，世界。）"
    expect(c.l10n("<a>计算机代码</a> (<b>你好,</b> 世界.)"))
      .to be_equivalent_to "<a>计算机代码</a> （你好， 世界。）"
  end

  it "does Chinese localisation with esc tags" do
    c = IsoDoc::I18n.new("zh", "Hans", i18nyaml: "spec/assets/zh-Hans.yaml")
    
    # Text inside <esc> should not be processed, and <esc> tags should be stripped
    # Without cjk-latin-separator (commented out in zh-Hans.yaml), spaces are preserved
    # because the complex regex requires Latin to be directly followed by CJK
    expect(c.l10n("你好 <esc>a<em>b</em>c</esc> 世界"))
      .to be_equivalent_to "你好 a<em>b</em>c 世界"
    # Input without spaces - output should also have no spaces
    expect(c.l10n("计算机代码<esc>(hello, world.)</esc>你好"))
      .to be_equivalent_to "计算机代码(hello, world.)你好"
    
    # With cjk-latin-separator set to "", simpler regex patterns are used
    # and spaces between CJK and Latin are removed correctly
    punct = c.get["punct"]
    punct["cjk-latin-separator"] = ""
    c.set("punct", punct)
    
    expect(c.l10n("你好 <esc>a<em>b</em>c</esc> 世界"))
      .to be_equivalent_to "你好a<em>b</em>c世界"
    # Input with spaces - with cjk-latin-separator="", spaces are removed
    # because the regex skips punctuation to find Latin context
    expect(c.l10n("计算机代码 <esc>(hello, world.)</esc> 你好"))
      .to be_equivalent_to "计算机代码(hello, world.)你好"
    expect(c.l10n("你好, <esc>world</esc> 世界."))
      .to be_equivalent_to "你好，world世界。"
  end

  it "does CJK script mixing localisation" do
    c = IsoDoc::I18n.new("ja", "Jpan", i18nyaml: "spec/assets/zh-Hans.yaml")
    expect(c.l10n("计算机代码： Japan"))
      .to be_equivalent_to "计算机代码： Japan"
    expect(c.l10n("Japan：计算机代码"))
      .to be_equivalent_to "Japan：计算机代码"
    expect(c.l10n("(Japan), 计算机代码"))
      .to be_equivalent_to "（Japan），计算机代码"
    expect(c.l10n("(计算机代码), Japan"))
      .to be_equivalent_to "（计算机代码）， Japan"
    expect(c.l10n("Japan, (计算机代码)"))
      .to be_equivalent_to "Japan，（计算机代码）"
    expect(c.l10n("计算机代码, (Japan)"))
      .to be_equivalent_to "计算机代码，（Japan）"
    expect(c.l10n("计算机代码 123"))
      .to be_equivalent_to "计算机代码123"
    expect(c.l10n("123 计算机代码"))
      .to be_equivalent_to "123 计算机代码"
    expect(c.l10n("版本 2.0 发布"))
      .to be_equivalent_to "版本2。0 发布"

    expect(c.l10n("Code (hello, world.)", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "Code (hello, world.)"
    expect(c.l10n("计算机代码: Japan", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "计算机代码： Japan"
    expect(c.l10n("Japan: 计算机代码", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "Japan: 计算机代码"
    expect(c.l10n("(Japan), 计算机代码", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "(Japan), 计算机代码"
    expect(c.l10n("(计算机代码), Japan", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "（计算机代码）， Japan"
    expect(c.l10n("Japan, (计算机代码)", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "Japan, （计算机代码）"
    expect(c.l10n("计算机代码, (Japan)", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "计算机代码， (Japan)"
    expect(c.l10n("计算机代码 123", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "计算机代码123"
    expect(c.l10n("123 计算机代码", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "123 计算机代码"
    expect(c.l10n("版本 2.0 发布", "ja", "Jpan",
                  { proportional_mixed_cjk: true }))
      .to be_equivalent_to "版本2.0 发布"

    c = IsoDoc::I18n.new("ja", "Jpan", i18nyaml: "spec/assets/zh-Hans.yaml")
    punct = c.get["punct"]
    punct["cjk-latin-separator"] = "$"
    c.set("punct", punct)
    expect(c.l10n("计算机代码: Japan"))
      .to be_equivalent_to "计算机代码：$Japan"
    expect(c.l10n("Japan：计算机代码"))
      .to be_equivalent_to "Japan：计算机代码"
    expect(c.l10n("(Japan), 计算机代码"))
      .to be_equivalent_to "（Japan），计算机代码"
    expect(c.l10n("(计算机代码), Japan"))
      .to be_equivalent_to "（计算机代码），$Japan"
    expect(c.l10n("Japan, (计算机代码)"))
      .to be_equivalent_to "Japan，（计算机代码）"
    expect(c.l10n("计算机代码, (Japan)"))
      .to be_equivalent_to "计算机代码，（Japan）"
    expect(c.l10n("计算机代码 123"))
      .to be_equivalent_to "计算机代码$123"
    expect(c.l10n("123 计算机代码"))
      .to be_equivalent_to "123$计算机代码"
    expect(c.l10n("版本 2.0 发布"))
      .to be_equivalent_to "版本$2。0$发布"
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
    expect(e.encode(c.l10n("Code; « code&#x202f;» and: code !"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab; code&#x202f;&#xbb; " \
                           "and&#xa0;: code !"
    c = IsoDoc::I18n.new("fr", "Latn", locale: "FR")
    expect(e.encode(c.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#xa0;: code&#x202f;!"
    expect(c.l10n("<a>Code</a>;<a> </a><a>«</a><a>c</a>ode» and: code!"))
      .to be_equivalent_to "<a>Code</a>&#x202f;;<a> </a><a>«&#x202f;</a><a>c</a>ode&#x202f;» and&#xa0;: code&#x202f;!"
    c = IsoDoc::I18n.new("fr", "Latn", locale: "CH")
    expect(e.encode(c.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#x202f;: code&#x202f;!"
    expect(c.l10n("<a>Code</a>;<a> </a><a>«</a><a>c</a>ode» and: code!"))
      .to be_equivalent_to "<a>Code</a>&#x202f;;<a> </a><a>«&#x202f;</a><a>c</a>ode&#x202f;» and&#x202f;: code&#x202f;!"
    expect(e.encode(c.l10n("http://xyz a;b"), :hexadecimal))
      .to be_equivalent_to "http://xyz a;b"
  end

  it "does French localisation with esc tags" do
    e = HTMLEntities.new
    c = IsoDoc::I18n.new("fr", "Latn")
    # Text inside <esc> should not be processed, and <esc> tags should be stripped
    expect(c.l10n("hello <esc>a<em>b</em>c</esc> d"))
      .to be_equivalent_to "hello a<em>b</em>c d"
    expect(e.encode(c.l10n("Code; <esc>«code»</esc> and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;code&#xbb; and&#xa0;: code&#x202f;!"
    expect(e.encode(c.l10n("Text: <esc>word</esc> more!"), :hexadecimal))
      .to be_equivalent_to "Text&#xa0;: word more&#x202f;!"
  end

  it "does French localisation with options hash" do
    e = HTMLEntities.new
    c = IsoDoc::I18n.new("fr", "Latn")
    # Test that passing locale in options hash works the same as setting it in constructor
    expect(e.encode(
             c.l10n("Code; «code» and: code!", "fr", "Latn",
                    { locale: "CH" }), :hexadecimal
           ))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#x202f;: code&#x202f;!"
    # Compare with constructor-set locale
    c_ch = IsoDoc::I18n.new("fr", "Latn", locale: "CH")
    expect(e.encode(c_ch.l10n("Code; «code» and: code!"), :hexadecimal))
      .to be_equivalent_to "Code&#x202f;; &#xab;&#x202f;code&#x202f;&#xbb; " \
                           "and&#x202f;: code&#x202f;!"
  end

  it "does boolean conjunctions in English" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.boolean_conj([], "and")).to eq ""
    expect(c.boolean_conj(%w(a), "and")).to eq "a"
    expect(c.boolean_conj(%w(a b), "and")).to eq "a <conn>and</conn> b"
    expect(c.boolean_conj(%w(a b c),
                          "and")).to eq "a<enum-comma>,</enum-comma> b<conn>, and</conn> c"
    expect(c.boolean_conj(%w(a b c d),
                          "and")).to eq "a<enum-comma>,</enum-comma> b<enum-comma>,</enum-comma> c<conn>, and</conn> d"
  end

  it "does boolean conjunctions in Traditional Chinese" do
    c = IsoDoc::I18n.new("zh", "Hant",
                         i18nhash: YAML.load_file("spec/assets/zh-Hans.yaml"))
    expect(c.boolean_conj([], "and")).to eq ""
    expect(c.boolean_conj(%w(a), "and")).to eq "a"
    expect(c.boolean_conj(%w(a b), "and")).to eq "a <conn>and</conn> b"
    expect(c.boolean_conj(%w(a b c),
                          "and")).to eq "a<enum-comma>、</enum-comma>b<conn>與</conn>c"
    expect(c.boolean_conj(%w(a b c d),
                          "and")).to eq "a<enum-comma>、</enum-comma>b<enum-comma>、</enum-comma>c<conn>與</conn>d"
  end

  it "does German ordinals" do
    c = IsoDoc::I18n.new("de", "Latn", i18nyaml: "spec/assets/de.yaml")
    term = c.inflection[c.edition]["grammar"]
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
    expect(c.inflect("Good", number: "pl", case: "gen", gender: "f"))
      .to eq "bonarum"
    expect(c.inflect("Walk", person: "2nd")).to eq "ambulas"
    expect(c.inflect("Walk", person: "2nd", number: "pl", mood: "subj"))
      .to eq "ambuletis"
  end

  it "interleaves space in CJK" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.cjk_extend("解題")).to eq "解　題"
    expect(c.cjk_extend("解——題")).to eq "解　——　題"
    expect(c.cjk_extend("解　題")).to eq "解　題"
    expect(c.cjk_extend("解題ific解題")).to eq "解　題　ific　解　題"
    expect(c.cjk_extend("解題29")).to eq "解　題　29"
    expect(c.cjk_extend("(解(題)解題)")).to eq "(解　(題)　解　題)"
    expect(c.cjk_extend("解!題")).to eq "解!題"
  end

  it "uses prev and foll context parameters" do
    c = IsoDoc::I18n.new("zh", "Hans",
                         i18nyaml: "spec/assets/zh-Hans.yaml")

    # Test that context parameters are properly extracted and used
    # The comma should be converted when surrounded by CJK context
    expect(c.l10n(",", "zh", "Hans", { prev: "计算机代码", foll: "计算机代码" }))
      .to eq "，"

    # Test with only prev context
    expect(c.l10n(",", "zh", "Hans", { prev: "计算机代码" }))
      .to eq "，"

    # Test with only foll context
    expect(c.l10n(",", "zh", "Hans", { foll: "计算机代码" }))
      .to eq "，"

    # Test without context using English - should not convert
    c_en = IsoDoc::I18n.new("en", "Latn")
    expect(c_en.l10n(",")).to eq ","

    # Test French with context parameters (should still work)
    c_fr = IsoDoc::I18n.new("fr", "Latn")
    result = c_fr.l10n(":", "fr", "Latn", { prev: "Code", foll: "end" })
    expect(result).to include(":") # Should still apply French spacing rules
  end

  it "parses dates" do
    c = IsoDoc::I18n.new("en", "Latn")
    expect(c.date("2011-02-03", "%F")).to eq "2011-02-03"
    expect(c.date("2011-02-03", "%-m%_%Y")).to eq "2 2011"
    expect(c.date("2011-02-03T09:04:05", "%F%_%T")).to eq "2011-02-03 09:04:05"
    expect(c.date("2011-02-03T09:04:05", "%F%_%l%_%p")).to eq "2011-02-03  9 AM"
    expect(c.date("2011-02-03T21:04:05", "%F%_%l%_%p")).to eq "2011-02-03  9 PM"
    expect(c.date("2011-02-03T09:04:05", "%F%_%l%_%P")).to eq "2011-02-03  9 am"
    expect(c.date("2011-02-03T21:04:05", "%F%_%l%_%P")).to eq "2011-02-03  9 pm"
    expect(c.date("2011-02-03", "%A%_%B")).to eq "Thursday February"
    expect(c.date("2011-02-03", "%^A%_%^B")).to eq "THURSDAY FEBRUARY"
    expect(c.date("2011-02-03", "%a%_%b")).to eq "Thu Feb"
    expect(c.date("2011-02-03", "%^a%_%^b")).to eq "THU FEB"
    expect(c.date("2011-02-03", "%a%_%h")).to eq "Thu Feb"
    expect(c.date("2011-02-03", "%^a%_%^h")).to eq "THU FEB"
  end

  it "parses dates in Irish" do
    c = IsoDoc::I18n.new("ga", "Latn")
    expect(c.date("2011-02-03", "%F")).to eq "2011-02-03"
    expect(c.date("2011-02-03", "%-m%_%Y")).to eq "2 2011"
    expect(c.date("2011-02-03T09:04:05", "%F%_%T")).to eq "2011-02-03 09:04:05"
    expect(c.date("2011-02-03T09:04:05",
                  "%F%_%l%_%p")).to eq "2011-02-03  9 R.N."
    expect(c.date("2011-02-03T21:04:05",
                  "%F%_%l%_%p")).to eq "2011-02-03  9 I.N."
    expect(c.date("2011-02-03T09:04:05",
                  "%F%_%l%_%P")).to eq "2011-02-03  9 r.n."
    expect(c.date("2011-02-03T21:04:05",
                  "%F%_%l%_%P")).to eq "2011-02-03  9 i.n."
    expect(c.date("2011-02-03", "%A%_%B")).to eq "Déardaoin Feabhra"
    expect(c.date("2011-02-03", "%^A%_%^B")).to eq "DÉARDAOIN FEABHRA"
    expect(c.date("2011-02-03", "%a%_%b")).to eq "Déar Feabh"
    expect(c.date("2011-02-03", "%^a%_%^b")).to eq "DÉAR FEABH"
    expect(c.date("2011-02-03", "%a%_%h")).to eq "Déar Feabh"
    expect(c.date("2011-02-03", "%^a%_%^h")).to eq "DÉAR FEABH"
  end

  it "populates variables through Liquid" do
    c = IsoDoc::I18n.new("en", "Latn", i18nyaml: "spec/assets/new.yaml")
    expect(c.populate("text_liquid", { "var2" => "44", "var3" => "55" }))
      .to eq "C 44 D 55 E"
    expect(c.populate("text_liquid", { "var1" => "33" }))
      .to eq "C  D  E"
    expect(c.populate(["hash_liquid", "key1"], { "var1" => "33" }))
      .to eq "A 33 B"
    expect(c.populate(["hash_liquid", "key1"], { "var2" => "44" }))
      .to eq "A  B"
  end

  it "uses Liquid inflect filter" do
    c = IsoDoc::I18n.new("en", "Latn", i18nyaml: "spec/assets/new.yaml")
    # man_liquid: "{{ 'Man' | inflect: 'case:acc' }}"
    # women_liquid: "{{ 'Woman' | inflect: 'number:pl, case:gen' }}"
    # woman_liquid: "{{ labels['woman'] | inflect: 'case:gen' }}"
    # woman2_liquid: "{{ labels['woman'] | inflect: 'case:abl' }}"
    expect(c.populate("man_liquid"))
      .to eq "virem"
    expect(c.populate("women_liquid"))
      .to eq "mulierum"
    expect(c.populate("woman_liquid"))
      .to eq "mulieris"
    expect(c.populate("woman2_liquid"))
      .to eq "Woman"
  end

  it "uses Liquid ordinal filters" do
    c = IsoDoc::I18n.new("fr", "Latn", i18nyaml: "spec/assets/new.yaml")
    # ordinal_num_blank_blank: "{{ var1 | ordinal_num: '', '' }}"
    # ordinal_word_blank_blank: "{{ var1 | ordinal_word: '', '' }}"
    # ordinal_num_man_blank: "{{ var1 | ordinal_num: 'man', '' }}"
    # ordinal_word_man_blank: "{{ var1 | ordinal_word: 'man', '' }}"
    # ordinal_num_woman_blank: "{{ var1 | ordinal_num: 'woman', '' }}"
    # ordinal_word_woman_blank: "{{ var1 | ordinal_word: 'woman', '' }}"
    # ordinal_num_blank_nsg: "{{ var1 | ordinal_num: '', 'gender:f,number:pl' }}"
    # ordinal_word_blank_nsg: "{{ var1 | ordinal_word: '', 'gender:f,number:pl' }}"
    # ordinal_num_masc_pl: "{{ var1 | ordinal_num: 'man', 'number:pl' }}"
    # ordinal_word_masc_pl: "{{ var1 | ordinal_word: 'man', 'number:pl' }}"
    expect(c.populate("ordinal_num_blank_blank", { "var1" => 31 }))
      .to eq "31e"
    expect(c.populate("ordinal_word_blank_blank", { "var1" => 31 }))
      .to eq "trente-et-unième"
    expect(c.populate("ordinal_num_man_blank", { "var1" => 1 }))
      .to eq "1er"
    expect(c.populate("ordinal_word_man_blank", { "var1" => 1 }))
      .to eq "premier"
    expect(c.populate("ordinal_num_woman_blank", { "var1" => 1 }))
      .to eq "1re"
    expect(c.populate("ordinal_word_woman_blank", { "var1" => 1 }))
      .to eq "première"
    expect(c.populate("ordinal_num_blank_nsg", { "var1" => 31 }))
      .to eq "31es"
    expect(c.populate("ordinal_word_blank_nsg", { "var1" => 31 }))
      .to eq "trente-et-unièmes"
    expect(c.populate("ordinal_num_masc_pl", { "var1" => 1 }))
      .to eq "1ers"
    expect(c.populate("ordinal_word_masc_pl", { "var1" => 1 }))
      .to eq "premiers"
  end

  it "resolves self-references with bracket notation" do
    labels = {
      "punct" => { "enum-comma" => "," },
      "msg" => 'hello #{ self["punct"]["enum-comma"] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello ,"
    labels = {
      "punct" => { "enum-comma" => "," },
      "msg" => "hello \#{ self['punct']['enum-comma'] }",
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello ,"
  end

  it "resolves self-references with dot notation" do
    labels = {
      "punct" => { "comma" => "," },
      "msg" => 'hello #{ self.punct.comma }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello ,"
  end

  it "resolves self-references with mixed notation" do
    labels = {
      "punct" => { "enum-comma" => "," },
      "msg" => 'hello #{ self.punct["enum-comma"] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello ,"
  end

  it "resolves multiple self-references in one string" do
    labels = {
      "punct" => { "comma" => ",", "period" => "." },
      "msg" => 'hello #{ self["punct"]["comma"] } world #{ self["punct"]["period"] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello , world ."
  end

  it "resolves self-references in arrays" do
    labels = {
      "punct" => { "enum-comma" => "," },
      "msg" => ['hello #{ self["punct"]["enum-comma"] }', "world"],
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"][0]).to eq "hello ,"
    expect(result["msg"][1]).to eq "world"
  end

  it "resolves self-references with array indices" do
    labels = {
      "items" => ["first", "second", "third"],
      "msg" => 'The item is: #{ self["items"][1] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "The item is: second"
  end

  it "resolves nested self-references" do
    labels = {
      "level1" => {
        "level2" => {
          "level3" => { "value" => "deep" },
        },
      },
      "msg" => 'Value: #{ self["level1"]["level2"]["level3"]["value"] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "Value: deep"
  end

  it "handles self-references without spaces" do
    labels = {
      "punct" => { "comma" => "," },
      "msg" => 'hello #{self["punct"]["comma"]}',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq "hello ,"
  end

  it "raises error for non-existent path" do
    labels = {
      "punct" => { "comma" => "," },
      "msg" => 'hello #{ self["punct"]["nonexistent"] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    expect { c.send(:self_reference_resolve, labels) }
      .to raise_error(/Self-reference error/)
  end

  it "raises error for invalid array index" do
    labels = {
      "items" => ["first", "second"],
      "msg" => 'Item: #{ self["items"][5] }',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    expect { c.send(:self_reference_resolve, labels) }
      .to raise_error(/Self-reference error/)
  end

  it "preserves non-self-reference content" do
    labels = {
      "punct" => { "comma" => "," },
      "msg" => 'This #{variable} is not a self-reference',
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["msg"]).to eq 'This #{variable} is not a self-reference'
  end

  it "resolves self-references in deeply nested structures" do
    labels = {
      "punct" => { "comma" => "," },
      "nested" => {
        "array" => [
          { "key" => 'value #{ self["punct"]["comma"] } here' },
        ],
      },
    }
    c = IsoDoc::I18n.new("en", "Latn")
    result = c.send(:self_reference_resolve, labels)
    expect(result["nested"]["array"][0]["key"]).to eq "value , here"
  end
end
