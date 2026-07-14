import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/string
import intldate/internal/icu/icudata/cache
import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/icudata/resource
import intldate/internal/icu/locale/loclikelysubtags
import intldate/internal/icu/locale/uloc_keytype

pub type UEnumeration {
  UEnumeration(
    items: List(String),
    by_index: Dict(Int, String),
    length: Int,
    index: Int,
  )
}

pub type BaseNameSubtags {
  BaseNameSubtags(
    language: String,
    script: String,
    region: String,
    variant: String,
  )
}

pub type UenumAdvanceResult {
  UenumAdvanceResult(value: Option(String), en: UEnumeration)
}

pub type KeywordEntry {
  KeywordEntry(key: String, value: String)
}

const bcp47_to_legacy_key = [
  #("ca", "calendar"),
  #("co", "collation"),
  #("cu", "currency"),
  #("hc", "hours"),
  #("nu", "numbers"),
  #("tz", "timezone"),
  #("va", "va"),
  #("fw", "fw"),
]

const lang3to2 = [
  #("aar", "aa"),
  #("abk", "ab"),
  #("ace", "ace"),
  #("ach", "ach"),
  #("ada", "ada"),
  #("ady", "ady"),
  #("ave", "ae"),
  #("aeb", "aeb"),
  #("afr", "af"),
  #("afh", "afh"),
  #("agq", "agq"),
  #("ain", "ain"),
  #("aka", "ak"),
  #("akk", "akk"),
  #("akz", "akz"),
  #("ale", "ale"),
  #("aln", "aln"),
  #("alt", "alt"),
  #("amh", "am"),
  #("arg", "an"),
  #("ang", "ang"),
  #("anp", "anp"),
  #("ara", "ar"),
  #("arc", "arc"),
  #("arn", "arn"),
  #("aro", "aro"),
  #("arp", "arp"),
  #("arq", "arq"),
  #("ars", "ars"),
  #("arw", "arw"),
  #("ary", "ary"),
  #("arz", "arz"),
  #("asm", "as"),
  #("asa", "asa"),
  #("ase", "ase"),
  #("ast", "ast"),
  #("ava", "av"),
  #("avk", "avk"),
  #("awa", "awa"),
  #("aym", "ay"),
  #("aze", "az"),
  #("bak", "ba"),
  #("bal", "bal"),
  #("ban", "ban"),
  #("bar", "bar"),
  #("bas", "bas"),
  #("bax", "bax"),
  #("bbc", "bbc"),
  #("bbj", "bbj"),
  #("bel", "be"),
  #("bej", "bej"),
  #("bem", "bem"),
  #("bew", "bew"),
  #("bez", "bez"),
  #("bfd", "bfd"),
  #("bfq", "bfq"),
  #("bul", "bg"),
  #("bgc", "bgc"),
  #("bgn", "bgn"),
  #("bho", "bho"),
  #("bis", "bi"),
  #("bik", "bik"),
  #("bin", "bin"),
  #("bjn", "bjn"),
  #("bkm", "bkm"),
  #("bla", "bla"),
  #("blo", "blo"),
  #("bam", "bm"),
  #("ben", "bn"),
  #("bod", "bo"),
  #("bpy", "bpy"),
  #("bqi", "bqi"),
  #("bre", "br"),
  #("bra", "bra"),
  #("brh", "brh"),
  #("brx", "brx"),
  #("bos", "bs"),
  #("bss", "bss"),
  #("bua", "bua"),
  #("bug", "bug"),
  #("bum", "bum"),
  #("byn", "byn"),
  #("byv", "byv"),
  #("cat", "ca"),
  #("cad", "cad"),
  #("car", "car"),
  #("cay", "cay"),
  #("cch", "cch"),
  #("ccp", "ccp"),
  #("che", "ce"),
  #("ceb", "ceb"),
  #("cgg", "cgg"),
  #("cha", "ch"),
  #("chb", "chb"),
  #("chg", "chg"),
  #("chk", "chk"),
  #("chm", "chm"),
  #("chn", "chn"),
  #("cho", "cho"),
  #("chp", "chp"),
  #("chr", "chr"),
  #("chy", "chy"),
  #("ckb", "ckb"),
  #("cos", "co"),
  #("cop", "cop"),
  #("cps", "cps"),
  #("cre", "cr"),
  #("crh", "crh"),
  #("ces", "cs"),
  #("csb", "csb"),
  #("csw", "csw"),
  #("chu", "cu"),
  #("chv", "cv"),
  #("cym", "cy"),
  #("dan", "da"),
  #("dak", "dak"),
  #("dar", "dar"),
  #("dav", "dav"),
  #("deu", "de"),
  #("del", "del"),
  #("den", "den"),
  #("dgr", "dgr"),
  #("din", "din"),
  #("dje", "dje"),
  #("doi", "doi"),
  #("dsb", "dsb"),
  #("dtp", "dtp"),
  #("dua", "dua"),
  #("dum", "dum"),
  #("div", "dv"),
  #("dyo", "dyo"),
  #("dyu", "dyu"),
  #("dzo", "dz"),
  #("dzg", "dzg"),
  #("ebu", "ebu"),
  #("ewe", "ee"),
  #("efi", "efi"),
  #("egl", "egl"),
  #("egy", "egy"),
  #("eka", "eka"),
  #("ell", "el"),
  #("elx", "elx"),
  #("eng", "en"),
  #("enm", "enm"),
  #("epo", "eo"),
  #("spa", "es"),
  #("esu", "esu"),
  #("est", "et"),
  #("eus", "eu"),
  #("ewo", "ewo"),
  #("ext", "ext"),
  #("fas", "fa"),
  #("fan", "fan"),
  #("fat", "fat"),
  #("ful", "ff"),
  #("fin", "fi"),
  #("fil", "fil"),
  #("fit", "fit"),
  #("fij", "fj"),
  #("fao", "fo"),
  #("fon", "fon"),
  #("fra", "fr"),
  #("frc", "frc"),
  #("frm", "frm"),
  #("fro", "fro"),
  #("frp", "frp"),
  #("frr", "frr"),
  #("frs", "frs"),
  #("fur", "fur"),
  #("fry", "fy"),
  #("gle", "ga"),
  #("gaa", "gaa"),
  #("gag", "gag"),
  #("gan", "gan"),
  #("gay", "gay"),
  #("gba", "gba"),
  #("gbz", "gbz"),
  #("gla", "gd"),
  #("gez", "gez"),
  #("gil", "gil"),
  #("glg", "gl"),
  #("glk", "glk"),
  #("gmh", "gmh"),
  #("grn", "gn"),
  #("goh", "goh"),
  #("gom", "gom"),
  #("gon", "gon"),
  #("gor", "gor"),
  #("got", "got"),
  #("grb", "grb"),
  #("grc", "grc"),
  #("gsw", "gsw"),
  #("guj", "gu"),
  #("guc", "guc"),
  #("gur", "gur"),
  #("guz", "guz"),
  #("glv", "gv"),
  #("gwi", "gwi"),
  #("hau", "ha"),
  #("hai", "hai"),
  #("hak", "hak"),
  #("haw", "haw"),
  #("heb", "he"),
  #("hin", "hi"),
  #("hif", "hif"),
  #("hil", "hil"),
  #("hit", "hit"),
  #("hmn", "hmn"),
  #("hmo", "ho"),
  #("hrv", "hr"),
  #("hsb", "hsb"),
  #("hsn", "hsn"),
  #("hat", "ht"),
  #("hun", "hu"),
  #("hup", "hup"),
  #("hye", "hy"),
  #("her", "hz"),
  #("ina", "ia"),
  #("iba", "iba"),
  #("ibb", "ibb"),
  #("ind", "id"),
  #("ile", "ie"),
  #("ibo", "ig"),
  #("iii", "ii"),
  #("ipk", "ik"),
  #("ilo", "ilo"),
  #("inh", "inh"),
  #("ido", "io"),
  #("isl", "is"),
  #("ita", "it"),
  #("iku", "iu"),
  #("izh", "izh"),
  #("jpn", "ja"),
  #("jam", "jam"),
  #("jbo", "jbo"),
  #("jgo", "jgo"),
  #("jmc", "jmc"),
  #("jpr", "jpr"),
  #("jrb", "jrb"),
  #("jut", "jut"),
  #("jav", "jv"),
  #("kat", "ka"),
  #("kaa", "kaa"),
  #("kab", "kab"),
  #("kac", "kac"),
  #("kaj", "kaj"),
  #("kam", "kam"),
  #("kaw", "kaw"),
  #("kbd", "kbd"),
  #("kbl", "kbl"),
  #("kcg", "kcg"),
  #("kde", "kde"),
  #("kea", "kea"),
  #("ken", "ken"),
  #("kfo", "kfo"),
  #("kon", "kg"),
  #("kgp", "kgp"),
  #("kha", "kha"),
  #("kho", "kho"),
  #("khq", "khq"),
  #("khw", "khw"),
  #("kik", "ki"),
  #("kiu", "kiu"),
  #("kua", "kj"),
  #("kaz", "kk"),
  #("kkj", "kkj"),
  #("kal", "kl"),
  #("kln", "kln"),
  #("khm", "km"),
  #("kmb", "kmb"),
  #("kan", "kn"),
  #("kor", "ko"),
  #("koi", "koi"),
  #("kok", "kok"),
  #("kos", "kos"),
  #("kpe", "kpe"),
  #("kau", "kr"),
  #("krc", "krc"),
  #("kri", "kri"),
  #("krj", "krj"),
  #("krl", "krl"),
  #("kru", "kru"),
  #("kas", "ks"),
  #("ksb", "ksb"),
  #("ksf", "ksf"),
  #("ksh", "ksh"),
  #("kur", "ku"),
  #("kum", "kum"),
  #("kut", "kut"),
  #("kom", "kv"),
  #("cor", "kw"),
  #("kxv", "kxv"),
  #("kir", "ky"),
  #("lat", "la"),
  #("lad", "lad"),
  #("lag", "lag"),
  #("lah", "lah"),
  #("lam", "lam"),
  #("ltz", "lb"),
  #("lez", "lez"),
  #("lfn", "lfn"),
  #("lug", "lg"),
  #("lim", "li"),
  #("lij", "lij"),
  #("liv", "liv"),
  #("lkt", "lkt"),
  #("lmo", "lmo"),
  #("lin", "ln"),
  #("lao", "lo"),
  #("lol", "lol"),
  #("loz", "loz"),
  #("lrc", "lrc"),
  #("lit", "lt"),
  #("ltg", "ltg"),
  #("lub", "lu"),
  #("lua", "lua"),
  #("lui", "lui"),
  #("lun", "lun"),
  #("luo", "luo"),
  #("lus", "lus"),
  #("luy", "luy"),
  #("lav", "lv"),
  #("lzh", "lzh"),
  #("lzz", "lzz"),
  #("mad", "mad"),
  #("maf", "maf"),
  #("mag", "mag"),
  #("mai", "mai"),
  #("mak", "mak"),
  #("man", "man"),
  #("mas", "mas"),
  #("mde", "mde"),
  #("mdf", "mdf"),
  #("mdh", "mdh"),
  #("mdr", "mdr"),
  #("men", "men"),
  #("mer", "mer"),
  #("mfe", "mfe"),
  #("mlg", "mg"),
  #("mga", "mga"),
  #("mgh", "mgh"),
  #("mgo", "mgo"),
  #("mah", "mh"),
  #("mri", "mi"),
  #("mic", "mic"),
  #("min", "min"),
  #("mis", "mis"),
  #("mkd", "mk"),
  #("mal", "ml"),
  #("mon", "mn"),
  #("mnc", "mnc"),
  #("mni", "mni"),
  #("moh", "moh"),
  #("mos", "mos"),
  #("mar", "mr"),
  #("mrj", "mrj"),
  #("msa", "ms"),
  #("mlt", "mt"),
  #("mua", "mua"),
  #("mul", "mul"),
  #("mus", "mus"),
  #("mwl", "mwl"),
  #("mwr", "mwr"),
  #("mwv", "mwv"),
  #("mya", "my"),
  #("mye", "mye"),
  #("myv", "myv"),
  #("mzn", "mzn"),
  #("nau", "na"),
  #("nan", "nan"),
  #("nap", "nap"),
  #("naq", "naq"),
  #("nob", "nb"),
  #("nde", "nd"),
  #("nds", "nds"),
  #("nep", "ne"),
  #("new", "new"),
  #("ndo", "ng"),
  #("nia", "nia"),
  #("niu", "niu"),
  #("njo", "njo"),
  #("nld", "nl"),
  #("nmg", "nmg"),
  #("nno", "nn"),
  #("nnh", "nnh"),
  #("nor", "no"),
  #("nog", "nog"),
  #("non", "non"),
  #("nov", "nov"),
  #("nqo", "nqo"),
  #("nbl", "nr"),
  #("nso", "nso"),
  #("nus", "nus"),
  #("nav", "nv"),
  #("nwc", "nwc"),
  #("nya", "ny"),
  #("nym", "nym"),
  #("nyn", "nyn"),
  #("nyo", "nyo"),
  #("nzi", "nzi"),
  #("oci", "oc"),
  #("oji", "oj"),
  #("orm", "om"),
  #("ori", "or"),
  #("oss", "os"),
  #("osa", "osa"),
  #("ota", "ota"),
  #("pan", "pa"),
  #("pag", "pag"),
  #("pal", "pal"),
  #("pam", "pam"),
  #("pap", "pap"),
  #("pau", "pau"),
  #("pcd", "pcd"),
  #("pcm", "pcm"),
  #("pdc", "pdc"),
  #("pdt", "pdt"),
  #("peo", "peo"),
  #("pfl", "pfl"),
  #("phn", "phn"),
  #("pli", "pi"),
  #("pol", "pl"),
  #("pms", "pms"),
  #("pnt", "pnt"),
  #("pon", "pon"),
  #("prg", "prg"),
  #("pro", "pro"),
  #("pus", "ps"),
  #("por", "pt"),
  #("que", "qu"),
  #("quc", "quc"),
  #("qug", "qug"),
  #("raj", "raj"),
  #("rap", "rap"),
  #("rar", "rar"),
  #("rgn", "rgn"),
  #("rif", "rif"),
  #("roh", "rm"),
  #("run", "rn"),
  #("ron", "ro"),
  #("rof", "rof"),
  #("rom", "rom"),
  #("rtm", "rtm"),
  #("rus", "ru"),
  #("rue", "rue"),
  #("rug", "rug"),
  #("rup", "rup"),
  #("kin", "rw"),
  #("rwk", "rwk"),
  #("san", "sa"),
  #("sad", "sad"),
  #("sah", "sah"),
  #("sam", "sam"),
  #("saq", "saq"),
  #("sas", "sas"),
  #("sat", "sat"),
  #("saz", "saz"),
  #("sba", "sba"),
  #("sbp", "sbp"),
  #("srd", "sc"),
  #("scn", "scn"),
  #("sco", "sco"),
  #("snd", "sd"),
  #("sdc", "sdc"),
  #("sdh", "sdh"),
  #("sme", "se"),
  #("see", "see"),
  #("seh", "seh"),
  #("sei", "sei"),
  #("sel", "sel"),
  #("ses", "ses"),
  #("sag", "sg"),
  #("sga", "sga"),
  #("sgs", "sgs"),
  #("shi", "shi"),
  #("shn", "shn"),
  #("shu", "shu"),
  #("sin", "si"),
  #("sid", "sid"),
  #("slk", "sk"),
  #("slv", "sl"),
  #("sli", "sli"),
  #("sly", "sly"),
  #("smo", "sm"),
  #("sma", "sma"),
  #("smj", "smj"),
  #("smn", "smn"),
  #("sms", "sms"),
  #("sna", "sn"),
  #("snk", "snk"),
  #("som", "so"),
  #("sog", "sog"),
  #("sqi", "sq"),
  #("srp", "sr"),
  #("srn", "srn"),
  #("srr", "srr"),
  #("ssw", "ss"),
  #("ssy", "ssy"),
  #("sot", "st"),
  #("stq", "stq"),
  #("sun", "su"),
  #("suk", "suk"),
  #("sus", "sus"),
  #("sux", "sux"),
  #("swe", "sv"),
  #("swa", "sw"),
  #("swb", "swb"),
  #("syc", "syc"),
  #("syr", "syr"),
  #("szl", "szl"),
  #("tam", "ta"),
  #("tcy", "tcy"),
  #("tel", "te"),
  #("tem", "tem"),
  #("teo", "teo"),
  #("ter", "ter"),
  #("tet", "tet"),
  #("tgk", "tg"),
  #("tha", "th"),
  #("tir", "ti"),
  #("tig", "tig"),
  #("tiv", "tiv"),
  #("tuk", "tk"),
  #("tkl", "tkl"),
  #("tkr", "tkr"),
  #("tlh", "tlh"),
  #("tli", "tli"),
  #("tly", "tly"),
  #("tmh", "tmh"),
  #("tsn", "tn"),
  #("ton", "to"),
  #("tog", "tog"),
  #("tok", "tok"),
  #("tpi", "tpi"),
  #("tur", "tr"),
  #("tru", "tru"),
  #("trv", "trv"),
  #("tso", "ts"),
  #("tsd", "tsd"),
  #("tsi", "tsi"),
  #("tat", "tt"),
  #("ttt", "ttt"),
  #("tum", "tum"),
  #("tvl", "tvl"),
  #("twi", "tw"),
  #("twq", "twq"),
  #("tah", "ty"),
  #("tyv", "tyv"),
  #("tzm", "tzm"),
  #("udm", "udm"),
  #("uig", "ug"),
  #("uga", "uga"),
  #("ukr", "uk"),
  #("umb", "umb"),
  #("und", "und"),
  #("urd", "ur"),
  #("uzb", "uz"),
  #("vai", "vai"),
  #("ven", "ve"),
  #("vec", "vec"),
  #("vep", "vep"),
  #("vie", "vi"),
  #("vls", "vls"),
  #("vmf", "vmf"),
  #("vmw", "vmw"),
  #("vol", "vo"),
  #("vot", "vot"),
  #("vro", "vro"),
  #("vun", "vun"),
  #("wln", "wa"),
  #("wae", "wae"),
  #("wal", "wal"),
  #("war", "war"),
  #("was", "was"),
  #("wbp", "wbp"),
  #("wol", "wo"),
  #("wuu", "wuu"),
  #("xal", "xal"),
  #("xho", "xh"),
  #("xmf", "xmf"),
  #("xnr", "xnr"),
  #("xog", "xog"),
  #("yao", "yao"),
  #("yap", "yap"),
  #("yav", "yav"),
  #("ybb", "ybb"),
  #("yid", "yi"),
  #("yor", "yo"),
  #("yrl", "yrl"),
  #("yue", "yue"),
  #("zha", "za"),
  #("zap", "zap"),
  #("zbl", "zbl"),
  #("zea", "zea"),
  #("zen", "zen"),
  #("zgh", "zgh"),
  #("zho", "zh"),
  #("zul", "zu"),
  #("zun", "zun"),
  #("zxx", "zxx"),
  #("zza", "zza"),
  #("jaw", "jw"),
  #("mol", "mo"),
  #("swc", "swc"),
  #("tgl", "tl"),
]

const country3to2 = [
  #("AND", "AD"),
  #("ARE", "AE"),
  #("AFG", "AF"),
  #("ATG", "AG"),
  #("AIA", "AI"),
  #("ALB", "AL"),
  #("ARM", "AM"),
  #("AGO", "AO"),
  #("ATA", "AQ"),
  #("ARG", "AR"),
  #("ASM", "AS"),
  #("AUT", "AT"),
  #("AUS", "AU"),
  #("ABW", "AW"),
  #("ALA", "AX"),
  #("AZE", "AZ"),
  #("BIH", "BA"),
  #("BRB", "BB"),
  #("BGD", "BD"),
  #("BEL", "BE"),
  #("BFA", "BF"),
  #("BGR", "BG"),
  #("BHR", "BH"),
  #("BDI", "BI"),
  #("BEN", "BJ"),
  #("BLM", "BL"),
  #("BMU", "BM"),
  #("BRN", "BN"),
  #("BOL", "BO"),
  #("BES", "BQ"),
  #("BRA", "BR"),
  #("BHS", "BS"),
  #("BTN", "BT"),
  #("BVT", "BV"),
  #("BWA", "BW"),
  #("BLR", "BY"),
  #("BLZ", "BZ"),
  #("CAN", "CA"),
  #("CCK", "CC"),
  #("COD", "CD"),
  #("CAF", "CF"),
  #("COG", "CG"),
  #("CHE", "CH"),
  #("CIV", "CI"),
  #("COK", "CK"),
  #("CHL", "CL"),
  #("CMR", "CM"),
  #("CHN", "CN"),
  #("COL", "CO"),
  #("CRQ", "CQ"),
  #("CRI", "CR"),
  #("CUB", "CU"),
  #("CPV", "CV"),
  #("CUW", "CW"),
  #("CXR", "CX"),
  #("CYP", "CY"),
  #("CZE", "CZ"),
  #("DEU", "DE"),
  #("DGA", "DG"),
  #("DJI", "DJ"),
  #("DNK", "DK"),
  #("DMA", "DM"),
  #("DOM", "DO"),
  #("DZA", "DZ"),
  #("XEA", "EA"),
  #("ECU", "EC"),
  #("EST", "EE"),
  #("EGY", "EG"),
  #("ESH", "EH"),
  #("ERI", "ER"),
  #("ESP", "ES"),
  #("ETH", "ET"),
  #("FIN", "FI"),
  #("FJI", "FJ"),
  #("FLK", "FK"),
  #("FSM", "FM"),
  #("FRO", "FO"),
  #("FRA", "FR"),
  #("GAB", "GA"),
  #("GBR", "GB"),
  #("GRD", "GD"),
  #("GEO", "GE"),
  #("GUF", "GF"),
  #("GGY", "GG"),
  #("GHA", "GH"),
  #("GIB", "GI"),
  #("GRL", "GL"),
  #("GMB", "GM"),
  #("GIN", "GN"),
  #("GLP", "GP"),
  #("GNQ", "GQ"),
  #("GRC", "GR"),
  #("SGS", "GS"),
  #("GTM", "GT"),
  #("GUM", "GU"),
  #("GNB", "GW"),
  #("GUY", "GY"),
  #("HKG", "HK"),
  #("HMD", "HM"),
  #("HND", "HN"),
  #("HRV", "HR"),
  #("HTI", "HT"),
  #("HUN", "HU"),
  #("XIC", "IC"),
  #("IDN", "ID"),
  #("IRL", "IE"),
  #("ISR", "IL"),
  #("IMN", "IM"),
  #("IND", "IN"),
  #("IOT", "IO"),
  #("IRQ", "IQ"),
  #("IRN", "IR"),
  #("ISL", "IS"),
  #("ITA", "IT"),
  #("JEY", "JE"),
  #("JAM", "JM"),
  #("JOR", "JO"),
  #("JPN", "JP"),
  #("KEN", "KE"),
  #("KGZ", "KG"),
  #("KHM", "KH"),
  #("KIR", "KI"),
  #("COM", "KM"),
  #("KNA", "KN"),
  #("PRK", "KP"),
  #("KOR", "KR"),
  #("KWT", "KW"),
  #("CYM", "KY"),
  #("KAZ", "KZ"),
  #("LAO", "LA"),
  #("LBN", "LB"),
  #("LCA", "LC"),
  #("LIE", "LI"),
  #("LKA", "LK"),
  #("LBR", "LR"),
  #("LSO", "LS"),
  #("LTU", "LT"),
  #("LUX", "LU"),
  #("LVA", "LV"),
  #("LBY", "LY"),
  #("MAR", "MA"),
  #("MCO", "MC"),
  #("MDA", "MD"),
  #("MNE", "ME"),
  #("MAF", "MF"),
  #("MDG", "MG"),
  #("MHL", "MH"),
  #("MKD", "MK"),
  #("MLI", "ML"),
  #("MMR", "MM"),
  #("MNG", "MN"),
  #("MAC", "MO"),
  #("MNP", "MP"),
  #("MTQ", "MQ"),
  #("MRT", "MR"),
  #("MSR", "MS"),
  #("MLT", "MT"),
  #("MUS", "MU"),
  #("MDV", "MV"),
  #("MWI", "MW"),
  #("MEX", "MX"),
  #("MYS", "MY"),
  #("MOZ", "MZ"),
  #("NAM", "NA"),
  #("NCL", "NC"),
  #("NER", "NE"),
  #("NFK", "NF"),
  #("NGA", "NG"),
  #("NIC", "NI"),
  #("NLD", "NL"),
  #("NOR", "NO"),
  #("NPL", "NP"),
  #("NRU", "NR"),
  #("NIU", "NU"),
  #("NZL", "NZ"),
  #("OMN", "OM"),
  #("PAN", "PA"),
  #("PER", "PE"),
  #("PYF", "PF"),
  #("PNG", "PG"),
  #("PHL", "PH"),
  #("PAK", "PK"),
  #("POL", "PL"),
  #("SPM", "PM"),
  #("PCN", "PN"),
  #("PRI", "PR"),
  #("PSE", "PS"),
  #("PRT", "PT"),
  #("PLW", "PW"),
  #("PRY", "PY"),
  #("QAT", "QA"),
  #("REU", "RE"),
  #("ROU", "RO"),
  #("SRB", "RS"),
  #("RUS", "RU"),
  #("RWA", "RW"),
  #("SAU", "SA"),
  #("SLB", "SB"),
  #("SYC", "SC"),
  #("SDN", "SD"),
  #("SWE", "SE"),
  #("SGP", "SG"),
  #("SHN", "SH"),
  #("SVN", "SI"),
  #("SJM", "SJ"),
  #("SVK", "SK"),
  #("SLE", "SL"),
  #("SMR", "SM"),
  #("SEN", "SN"),
  #("SOM", "SO"),
  #("SUR", "SR"),
  #("SSD", "SS"),
  #("STP", "ST"),
  #("SLV", "SV"),
  #("SXM", "SX"),
  #("SYR", "SY"),
  #("SWZ", "SZ"),
  #("TCA", "TC"),
  #("TCD", "TD"),
  #("ATF", "TF"),
  #("TGO", "TG"),
  #("THA", "TH"),
  #("TJK", "TJ"),
  #("TKL", "TK"),
  #("TLS", "TL"),
  #("TKM", "TM"),
  #("TUN", "TN"),
  #("TON", "TO"),
  #("TUR", "TR"),
  #("TTO", "TT"),
  #("TUV", "TV"),
  #("TWN", "TW"),
  #("TZA", "TZ"),
  #("UKR", "UA"),
  #("UGA", "UG"),
  #("UMI", "UM"),
  #("USA", "US"),
  #("URY", "UY"),
  #("UZB", "UZ"),
  #("VAT", "VA"),
  #("VCT", "VC"),
  #("VEN", "VE"),
  #("VGB", "VG"),
  #("VIR", "VI"),
  #("VNM", "VN"),
  #("VUT", "VU"),
  #("WLF", "WF"),
  #("WSM", "WS"),
  #("XKK", "XK"),
  #("YEM", "YE"),
  #("MYT", "YT"),
  #("ZAF", "ZA"),
  #("ZMB", "ZM"),
  #("ZWE", "ZW"),
  #("ANT", "AN"),
  #("BUR", "BU"),
  #("SCG", "CS"),
  #("FXX", "FX"),
  #("ROM", "RO"),
  #("SUN", "SU"),
  #("TMP", "TP"),
  #("YMD", "YD"),
  #("YUG", "YU"),
  #("ZAR", "ZR"),
]

fn code_points(s: String) -> List(String) {
  string.to_graphemes(s)
}

fn char_code(c: String) -> Int {
  case string.to_utf_codepoints(c) {
    [cp] -> string.utf_codepoint_to_int(cp)
    _ -> -1
  }
}

fn is_alpha(c: String) -> Bool {
  let code = char_code(c)
  { code >= 65 && code <= 90 } || { code >= 97 && code <= 122 }
}

fn is_digit(c: String) -> Bool {
  let code = char_code(c)
  code >= 48 && code <= 57
}

fn is_alpha_string(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_alpha(c) {
        True -> is_alpha_string(rest)
        False -> False
      }
  }
}

fn is_digit_string(chars: List(String)) -> Bool {
  case chars {
    [] -> True
    [c, ..rest] ->
      case is_digit(c) {
        True -> is_digit_string(rest)
        False -> False
      }
  }
}

fn is_alpha_len(s: String, len: Int) -> Bool {
  let chars = code_points(s)
  list.length(chars) == len && is_alpha_string(chars)
}

fn is_digit_len(s: String, len: Int) -> Bool {
  let chars = code_points(s)
  list.length(chars) == len && is_digit_string(chars)
}

fn is_alpha_range(s: String, min_len: Int, max_len: Int) -> Bool {
  let chars = code_points(s)
  let len = list.length(chars)
  len >= min_len && len <= max_len && is_alpha_string(chars)
}

fn index_dict(values: List(a)) -> Dict(Int, a) {
  values
  |> list.index_map(fn(value, i) { #(i, value) })
  |> dict.from_list
}

fn cached_pairs_dict(
  key: String,
  pairs: List(#(String, String)),
) -> Dict(String, String) {
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      cache.put(
        key,
        list.fold(pairs, dict.new(), fn(acc, pair) {
          case dict.has_key(acc, pair.0) {
            True -> acc
            False -> dict.insert(acc, pair.0, pair.1)
          }
        }),
      )
  }
}

fn dict_at(entries: Dict(Int, a), index: Int) -> Option(a) {
  case dict.get(entries, index) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn capitalize_script(s: String) -> String {
  case code_points(s) {
    [] -> ""
    [head, ..tail] ->
      string.uppercase(head) <> string.lowercase(string.join(tail, ""))
  }
}

fn normalize_separators(id: String) -> String {
  string.replace(id, "-", "_")
}

fn split_tokens(id: String) -> List(String) {
  string.split(normalize_separators(id), "_")
}

fn get_base_token_slice(id: Option(String)) -> List(String) {
  case id {
    None -> []
    Some(id_value) -> {
      let clean = case string.split_once(id_value, "@") {
        Ok(#(before, _after)) -> before
        Error(_) -> id_value
      }
      let tokens =
        split_tokens(clean)
        |> list.filter(fn(t) { t != "" })
      take_until_single_char_token(tokens)
    }
  }
}

fn take_until_single_char_token(tokens: List(String)) -> List(String) {
  case tokens {
    [] -> []
    [tok, ..rest] ->
      case list.length(code_points(tok)) == 1 {
        True -> []
        False -> [tok, ..take_until_single_char_token(rest)]
      }
  }
}

fn lang3to2_lookup(lang: String) -> String {
  case dict.get(cached_pairs_dict("uloc_lang3to2", lang3to2), lang) {
    Ok(v) -> v
    Error(_) -> lang
  }
}

fn country3to2_lookup(region: String) -> String {
  case dict.get(cached_pairs_dict("uloc_country3to2", country3to2), region) {
    Ok(v) -> v
    Error(_) -> region
  }
}

pub fn parse_base_name_subtags(id: Option(String)) -> BaseNameSubtags {
  let tokens = get_base_token_slice(id)
  let #(language, tokens) = parse_language_subtag(tokens)
  let #(script, tokens) = parse_script_subtag(tokens)
  let #(region, tokens) = parse_region_subtag(tokens)
  BaseNameSubtags(
    language:,
    script:,
    region:,
    variant: string.join(tokens, "_"),
  )
}

fn parse_language_subtag(tokens: List(String)) -> #(String, List(String)) {
  case tokens {
    [] -> #("", [])
    [t0, ..rest] -> {
      let lower = string.lowercase(t0)
      case lower {
        "und" | "root" -> #("", rest)
        _ -> {
          let language = case is_alpha_len(lower, 3) {
            True -> lang3to2_lookup(lower)
            False -> lower
          }
          #(language, rest)
        }
      }
    }
  }
}

fn parse_script_subtag(tokens: List(String)) -> #(String, List(String)) {
  case tokens {
    [t0, ..rest] ->
      case is_alpha_len(t0, 4) {
        True -> #(capitalize_script(t0), rest)
        False -> #("", tokens)
      }
    [] -> #("", tokens)
  }
}

fn parse_region_subtag(tokens: List(String)) -> #(String, List(String)) {
  case tokens {
    [t0, ..rest] ->
      case is_alpha_range(t0, 2, 3) {
        True -> {
          let region = string.uppercase(t0)
          let region = case is_alpha_len(region, 3) {
            True -> country3to2_lookup(region)
            False -> region
          }
          #(region, rest)
        }
        False ->
          case is_digit_len(t0, 3) {
            True -> #(t0, rest)
            False -> #("", tokens)
          }
      }
    [] -> #("", tokens)
  }
}

pub fn get_language_subtag(id: Option(String)) -> String {
  parse_base_name_subtags(id).language
}

pub fn get_script_subtag(id: Option(String)) -> String {
  parse_base_name_subtags(id).script
}

pub fn get_region_subtag(id: Option(String)) -> String {
  parse_base_name_subtags(id).region
}

pub fn get_language(id: Option(String)) -> String {
  get_language_subtag(id)
}

pub fn get_country(id: Option(String)) -> String {
  get_region_subtag(id)
}

pub fn get_base_name(id: Option(String)) -> String {
  let subtags = parse_base_name_subtags(id)
  [subtags.language, subtags.script, subtags.region, subtags.variant]
  |> list.filter(fn(s) { s != "" })
  |> string.join("_")
}

pub fn get_script(id: Option(String)) -> String {
  get_script_subtag(id)
}

pub fn get_region(id: Option(String)) -> String {
  get_region_subtag(id)
}

fn split_pairs(s: String) -> List(String) {
  string.split(s, ";")
}

pub fn get_keyword_value_from_legacy_syntax(
  id: Option(String),
  legacy_key: String,
) -> String {
  case id {
    None -> ""
    Some(id_value) ->
      case string.split_once(id_value, "@") {
        Error(_) -> ""
        Ok(#(_before, kw_part)) ->
          find_legacy_keyword_value(split_pairs(kw_part), legacy_key)
      }
  }
}

fn find_legacy_keyword_value(
  pairs: List(String),
  legacy_key: String,
) -> String {
  case pairs {
    [] -> ""
    [pair, ..rest] ->
      case string.split_once(pair, "=") {
        Error(_) -> find_legacy_keyword_value(rest, legacy_key)
        Ok(#(k, v)) ->
          case string.trim(k) == legacy_key {
            True -> string.trim(v)
            False -> find_legacy_keyword_value(rest, legacy_key)
          }
      }
  }
}

fn bcp47_key_for_legacy(legacy_key: String) -> Option(String) {
  find_bcp47_key_for_legacy_loop(bcp47_to_legacy_key, legacy_key)
}

fn find_bcp47_key_for_legacy_loop(
  entries: List(#(String, String)),
  legacy_key: String,
) -> Option(String) {
  case entries {
    [] -> None
    [#(bcp47_key, legacy), ..rest] ->
      case legacy == legacy_key {
        True -> Some(bcp47_key)
        False -> find_bcp47_key_for_legacy_loop(rest, legacy_key)
      }
  }
}

fn is_known_key_token(token: String) -> Bool {
  let lower = string.lowercase(token)
  case
    dict.get(
      cached_pairs_dict("uloc_bcp47_to_legacy_key", bcp47_to_legacy_key),
      lower,
    )
  {
    Ok(_) -> True
    Error(_) -> list.length(code_points(lower)) == 2
  }
}

pub fn get_keyword_value_from_unicode_extension(
  id: Option(String),
  legacy_key: String,
) -> String {
  case bcp47_key_for_legacy(legacy_key) {
    None -> ""
    Some(bcp47_key) ->
      case id {
        None -> ""
        Some(id_value) -> {
          let clean = case string.split_once(id_value, "@") {
            Ok(#(before, _after)) -> before
            Error(_) -> id_value
          }
          let tokens = split_tokens(clean)
          case find_u_index(tokens, 0) {
            None -> ""
            Some(u_idx) ->
              scan_unicode_extension(index_dict(tokens), u_idx + 1, bcp47_key)
          }
        }
      }
  }
}

fn find_u_index(tokens: List(String), i: Int) -> Option(Int) {
  case tokens {
    [] -> None
    [t, ..rest] ->
      case string.lowercase(t) == "u" {
        True -> Some(i)
        False -> find_u_index(rest, i + 1)
      }
  }
}

fn scan_unicode_extension(
  tokens: Dict(Int, String),
  i: Int,
  bcp47_key: String,
) -> String {
  case dict_at(tokens, i) {
    None -> ""
    Some(token) -> {
      let key = string.lowercase(token)
      case is_known_key_token(token) {
        False -> scan_unicode_extension(tokens, i + 1, bcp47_key)
        True ->
          case key == bcp47_key {
            True -> collect_extension_values(tokens, i + 1, [])
            False ->
              scan_unicode_extension(
                tokens,
                skip_extension_values(tokens, i + 1),
                bcp47_key,
              )
          }
      }
    }
  }
}

fn skip_extension_values(tokens: Dict(Int, String), i: Int) -> Int {
  case dict_at(tokens, i) {
    None -> i
    Some(token) ->
      case is_known_key_token(token) {
        True -> i
        False -> skip_extension_values(tokens, i + 1)
      }
  }
}

fn collect_extension_values(
  tokens: Dict(Int, String),
  i: Int,
  acc: List(String),
) -> String {
  case dict_at(tokens, i) {
    None -> string.join(list.reverse(acc), "_")
    Some(token) ->
      case is_known_key_token(token) {
        True -> string.join(list.reverse(acc), "_")
        False -> collect_extension_values(tokens, i + 1, [token, ..acc])
      }
  }
}

pub fn get_keyword_value(id: Option(String), legacy_key: String) -> String {
  case get_keyword_value_from_legacy_syntax(id, legacy_key) {
    "" -> get_keyword_value_from_unicode_extension(id, legacy_key)
    value -> value
  }
}

pub fn create_u_enumeration(items: List(String)) -> UEnumeration {
  UEnumeration(
    items:,
    by_index: index_dict(items),
    length: list.length(items),
    index: 0,
  )
}

pub fn locale_canon_keyword_name(name: String) -> Result(String, String) {
  locale_canon_keyword_name_loop(code_points(name), "")
}

fn locale_canon_keyword_name_loop(
  chars: List(String),
  acc: String,
) -> Result(String, String) {
  case chars {
    [] -> Ok(acc)
    [c, ..rest] ->
      case is_alpha(c) || is_digit(c) {
        False -> Error("U_ILLEGAL_ARGUMENT_ERROR")
        True -> locale_canon_keyword_name_loop(rest, acc <> string.lowercase(c))
      }
  }
}

fn is_ok_value_punctuation(c: String) -> Bool {
  c == "_" || c == "-" || c == "+" || c == "/"
}

fn validate_keyword_value_chars(chars: List(String)) -> Result(Nil, String) {
  case chars {
    [] -> Ok(Nil)
    [c, ..rest] ->
      case is_alpha(c) || is_digit(c) || is_ok_value_punctuation(c) {
        False -> Error("U_ILLEGAL_ARGUMENT_ERROR")
        True -> validate_keyword_value_chars(rest)
      }
  }
}

fn parse_keyword_entry(pair: String) -> Result(KeywordEntry, String) {
  case string.split_once(pair, "=") {
    Error(_) -> Error("U_ILLEGAL_ARGUMENT_ERROR")
    Ok(#(k, v)) -> {
      let k = string.trim(k)
      let v = string.trim(v)
      case k == "" || v == "" {
        True -> Error("U_ILLEGAL_ARGUMENT_ERROR")
        False ->
          case locale_canon_keyword_name(k) {
            Error(e) -> Error(e)
            Ok(k_lower) -> Ok(KeywordEntry(k_lower, v))
          }
      }
    }
  }
}

fn parse_keyword_entries(
  pairs: List(String),
) -> Result(List(KeywordEntry), String) {
  case pairs {
    [] -> Ok([])
    [pair, ..rest] ->
      case parse_keyword_entry(pair) {
        Error(e) -> Error(e)
        Ok(entry) ->
          case parse_keyword_entries(rest) {
            Error(e) -> Error(e)
            Ok(entries) -> Ok([entry, ..entries])
          }
      }
  }
}

fn merge_keyword_entries(
  entries: List(KeywordEntry),
  canon_keyword_name: String,
  canon_keyword_value: String,
  handled: Bool,
) -> #(List(KeywordEntry), Bool) {
  case entries {
    [] -> #([], handled)
    [entry, ..rest] -> {
      let rc = string.compare(canon_keyword_name, entry.key)
      case rc {
        order.Eq -> {
          let out = case canon_keyword_value != "" {
            True -> [KeywordEntry(canon_keyword_name, canon_keyword_value)]
            False -> []
          }
          let #(rest_out, _handled) =
            merge_keyword_entries(
              rest,
              canon_keyword_name,
              canon_keyword_value,
              True,
            )
          #(list.append(out, rest_out), True)
        }
        order.Lt if canon_keyword_value != "" && !handled -> {
          let #(rest_out, _handled) =
            merge_keyword_entries(
              rest,
              canon_keyword_name,
              canon_keyword_value,
              True,
            )
          #(
            [
              KeywordEntry(canon_keyword_name, canon_keyword_value),
              entry,
              ..rest_out
            ],
            True,
          )
        }
        _ -> {
          let #(rest_out, handled2) =
            merge_keyword_entries(
              rest,
              canon_keyword_name,
              canon_keyword_value,
              handled,
            )
          #([entry, ..rest_out], handled2)
        }
      }
    }
  }
}

pub fn set_keyword_value(
  keyword_name: String,
  keyword_value: Option(String),
  locale_id: String,
) -> Result(String, String) {
  case keyword_name {
    "" -> Error("U_ILLEGAL_ARGUMENT_ERROR")
    _ ->
      case locale_canon_keyword_name(keyword_name) {
        Error(e) -> Error(e)
        Ok(canon_keyword_name) -> {
          let canon_keyword_value = option.unwrap(keyword_value, "")
          case validate_keyword_value_chars(code_points(canon_keyword_value)) {
            Error(e) -> Error(e)
            Ok(_) ->
              build_set_keyword_value(
                canon_keyword_name,
                canon_keyword_value,
                locale_id,
              )
          }
        }
      }
  }
}

fn build_set_keyword_value(
  canon_keyword_name: String,
  canon_keyword_value: String,
  locale_id: String,
) -> Result(String, String) {
  let #(base, keywords) = case string.split_once(locale_id, "@") {
    Ok(#(before, after)) -> #(before, "@" <> after)
    Error(_) -> #(locale_id, "")
  }

  case string.length(keywords) <= 1 {
    True ->
      case canon_keyword_value == "" {
        True -> Ok(locale_id)
        False ->
          Ok(base <> "@" <> canon_keyword_name <> "=" <> canon_keyword_value)
      }
    False ->
      case parse_keyword_entries(split_pairs(string.drop_start(keywords, 1))) {
        Error(e) -> Error(e)
        Ok(entries) -> {
          let #(out, handled) =
            merge_keyword_entries(
              entries,
              canon_keyword_name,
              canon_keyword_value,
              False,
            )
          let #(out, handled) = case !handled && canon_keyword_value != "" {
            True -> #(
              list.append(out, [
                KeywordEntry(canon_keyword_name, canon_keyword_value),
              ]),
              True,
            )
            False -> #(out, handled)
          }
          case !handled {
            True -> Ok(locale_id)
            False ->
              case out {
                [] -> Ok(base)
                _ ->
                  Ok(
                    base
                    <> "@"
                    <> string.join(
                      list.map(out, fn(e) { e.key <> "=" <> e.value }),
                      ";",
                    ),
                  )
              }
          }
        }
      }
  }
}

fn adapt_table_view(
  table: resource.ResourceTableView,
) -> uloc_keytype.ResourceTableView {
  uloc_keytype.ResourceTableView(
    length: table.length,
    get_key: fn(i) {
      case table.get_key {
        Some(get_key) -> get_key(i)
        None -> ""
      }
    },
    get_res: fn(i) {
      case table.get_res {
        Some(get_res) -> get_res(i)
        None -> 0
      }
    },
  )
}

fn adapt_resource_data(rd: resource.ResourceData) -> uloc_keytype.ResourceData {
  uloc_keytype.ResourceData(
    get_table: fn(res) { adapt_table_view(resource.get_table(rd, res)) },
    get_table_safe: fn(res) {
      option.map(resource.get_table_safe(rd, res), adapt_table_view)
    },
    get_string: fn(res) {
      let value = resource.create_resource_value(Some(rd), res)
      uloc_keytype.ResourceStringResult(
        text: option.map(resource.resource_value_get_string(value), fn(s) {
          s.text
        }),
      )
    },
  )
}

fn adapt_key_type_bundle(
  bundle: Bundle,
  name: String,
) -> Option(uloc_keytype.Bundle) {
  case resbund.open_direct(bundle, name) {
    None -> None
    Some(rd) ->
      Some(uloc_keytype.Bundle(
        open_direct: fn(inner_name) {
          case resbund.open_direct(bundle, inner_name) {
            Some(inner_rd) -> adapt_resource_data(inner_rd)
            None -> adapt_resource_data(rd)
          }
        },
        root_res: rd.root_res,
      ))
  }
}

fn build_loc_ext_key_map(bundle: Bundle) -> Option(uloc_keytype.LocExtKeyMap) {
  let key = "keytypemap\n" <> bundle.data_path
  case cache.get(key) {
    Ok(cached) -> cached
    Error(_) ->
      case adapt_key_type_bundle(bundle, "keyTypeData") {
        None -> None
        Some(kt_bundle) ->
          cache.put(
            key,
            Some(uloc_keytype.init_from_resource_bundle(kt_bundle)),
          )
      }
  }
}

pub fn to_legacy_type(
  bundle: Option(Bundle),
  keyword: String,
  value: String,
) -> Option(String) {
  case bundle {
    None ->
      case uloc_keytype.is_well_formed_legacy_type(value) {
        True -> Some(value)
        False -> None
      }
    Some(b) ->
      case build_loc_ext_key_map(b) {
        None -> None
        Some(key_map) ->
          uloc_keytype.ulocimp_to_legacy_type_with_fallback(
            key_map,
            keyword,
            value,
          )
      }
  }
}

pub fn to_legacy_key(
  bundle: Option(Bundle),
  keyword: String,
) -> Option(String) {
  case bundle {
    None ->
      case uloc_keytype.is_well_formed_legacy_key(keyword) {
        True -> Some(keyword)
        False -> None
      }
    Some(b) ->
      case build_loc_ext_key_map(b) {
        None -> None
        Some(key_map) ->
          uloc_keytype.ulocimp_to_legacy_key_with_fallback(key_map, keyword)
      }
  }
}

fn normalize_calendar_type(cal_type: String) -> String {
  case cal_type == "gregory" {
    True -> "gregorian"
    False -> cal_type
  }
}

fn apply_explicit_calendar_type_quirks(
  locale_id: String,
  raw_cal_type: String,
  cal_type: String,
) -> String {
  case cal_type != "gregorian" {
    True -> cal_type
    False ->
      case raw_cal_type != "gregory" {
        True -> cal_type
        False ->
          case
            get_language(Some(locale_id)) == "th"
            && get_region(Some(locale_id)) == "TH"
          {
            True -> "buddhist"
            False -> cal_type
          }
      }
  }
}

fn resolve_calendar_preference_region(
  bundle: Bundle,
  locale_id: String,
) -> String {
  let language = get_language(Some(locale_id))
  let region = get_region(Some(locale_id))
  case language == "" || region == "" {
    False -> region
    True -> {
      let script = get_script(Some(locale_id))
      case build_likely_subtags_state(bundle) {
        None -> region
        Some(state) ->
          loclikelysubtags.maximize(state, language, script, region, False).region
      }
    }
  }
}

fn build_likely_subtags_state(
  bundle: Bundle,
) -> Option(loclikelysubtags.LikelySubtagsState) {
  case
    loclikelysubtags.create_likely_subtags(adapt_likely_subtags_bundle(bundle))
  {
    Ok(state) -> Some(state)
    Error(_) -> None
  }
}

fn adapt_likely_subtags_bundle(bundle: Bundle) -> loclikelysubtags.Bundle {
  loclikelysubtags.Bundle(
    open_direct: fn(name) { resbund.open_direct_or_panic(bundle, name) },
    get_by_path: fn(chain, path) {
      let resbund_chain =
        list.map(chain, fn(entry) {
          resbund.LocaleChainEntry(entry.name, Some(entry.res_data))
        })
      case resbund.get_by_path(bundle, resbund_chain, path, 0) {
        None -> None
        Some(resolved) ->
          Some(loclikelysubtags.MatchLookup(resolved.res_data, resolved.res))
      }
    },
  )
}

fn get_calendar_preference(bundle: Bundle, region: String) -> Option(String) {
  case resbund.open_direct(bundle, "supplementalData") {
    None -> None
    Some(supp_rd) -> {
      let chain = [resbund.LocaleChainEntry("supplementalData", Some(supp_rd))]
      case resbund.get_by_path(bundle, chain, "calendarPreferenceData", 0) {
        None -> None
        Some(cp) -> {
          let table = resource.get_table(cp.res_data, cp.res)
          let idx = case find_region_index(table, region) {
            Some(i) -> Some(i)
            None -> find_region_index(table, "001")
          }
          case idx {
            None -> None
            Some(i) -> {
              let assert Some(get_res) = table.get_res
              let arr = resource.get_array(cp.res_data, get_res(i))
              case arr.length == 0 {
                True -> None
                False -> {
                  let assert Some(arr_get_res) = arr.get_res
                  let value =
                    resource.create_resource_value(
                      Some(cp.res_data),
                      arr_get_res(0),
                    )
                  case resource.resource_value_get_string(value) {
                    None -> None
                    Some(s) -> Some(normalize_calendar_type(s.text))
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn find_region_index(
  table: resource.ResourceTableView,
  region: String,
) -> Option(Int) {
  case table.get_key {
    None -> None
    Some(get_key) -> find_region_index_loop(get_key, table.length, region, 0)
  }
}

fn find_region_index_loop(
  get_key: fn(Int) -> String,
  length: Int,
  region: String,
  i: Int,
) -> Option(Int) {
  case i >= length {
    True -> None
    False ->
      case get_key(i) == region {
        True -> Some(i)
        False -> find_region_index_loop(get_key, length, region, i + 1)
      }
  }
}

pub fn get_calendar_type_to_use(bundle: Bundle, locale_id: String) -> String {
  case get_keyword_value(Some(locale_id), "calendar") {
    "" -> {
      let region = resolve_calendar_preference_region(bundle, locale_id)
      case get_calendar_preference(bundle, region) {
        Some(preferred) -> preferred
        None -> "gregorian"
      }
    }
    explicit ->
      apply_explicit_calendar_type_quirks(
        locale_id,
        explicit,
        normalize_calendar_type(explicit),
      )
  }
}

pub fn uloc_get_country(locale_id: Option(String)) -> String {
  get_country(locale_id)
}

pub fn uloc_get_base_name(locale_id: Option(String)) -> String {
  get_base_name(locale_id)
}

pub const default_locale_fallback = "en_US_POSIX"

pub fn uloc_get_default(current_default: String) -> String {
  current_default
}

pub fn uloc_to_legacy_type(
  bundle: Option(Bundle),
  keyword: String,
  value: String,
) -> Option(String) {
  to_legacy_type(bundle, keyword, value)
}

pub fn uloc_open_available_by_type(bundle: Bundle, type_: Int) -> UEnumeration {
  create_u_enumeration(resbund.get_available_locales_by_type(bundle, type_))
}
