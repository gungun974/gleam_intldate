import intldate/internal/icu/calendar/chnsecal
import intldate/internal/icu/calendar/gregocal
import intldate/internal/icu/icudata/bundle.{type Bundle}

const threshold_1897 = -2_302_156_800_000

const threshold_1898 = -2_270_617_200_000

const threshold_1912 = -1_829_116_800_000

pub fn dangi_offset_fn(millis: Int) -> Int {
  case millis < threshold_1897 {
    True -> 8 * 3_600_000
    False ->
      case millis < threshold_1898 {
        True -> 7 * 3_600_000
        False ->
          case millis < threshold_1912 {
            True -> 8 * 3_600_000
            False -> 9 * 3_600_000
          }
      }
  }
}

pub fn compute_dangi_fields(
  bundle: Bundle,
  locale_id: String,
  epoch_millis: Int,
  zone_offset_millis: Int,
) -> gregocal.CalendarFields {
  chnsecal.compute_chinese_fields_with_offset(
    bundle,
    locale_id,
    epoch_millis,
    zone_offset_millis,
    dangi_offset_fn,
  )
}
