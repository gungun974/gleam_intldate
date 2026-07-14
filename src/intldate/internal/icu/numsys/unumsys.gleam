import intldate/internal/icu/icudata/resbund.{type Bundle}
import intldate/internal/icu/numsys/numsys.{type NumberingSystem}

pub fn unumsys_open(bundle: Bundle, locale: String) -> NumberingSystem {
  numsys.create_instance_for_locale(bundle, locale)
}

pub fn unumsys_get_name(unumsys: NumberingSystem) -> String {
  numsys.numbering_system_get_name(unumsys)
}
