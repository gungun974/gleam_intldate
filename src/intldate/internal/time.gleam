import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import tzif/database
import tzif/tzcalendar
import zones

pub fn resolve(
  date: timestamp.Timestamp,
  time_zone: Option(String),
) -> #(calendar.Date, calendar.TimeOfDay, Bool, duration.Duration, String) {
  let time_zone = case time_zone {
    Some(_) -> time_zone
    None -> option.from_result(system_time_zone())
  }

  case time_zone {
    None -> {
      let #(date, time) = timestamp.to_calendar(date, duration.empty)
      #(date, time, False, duration.empty, "UTC")
    }
    Some(zone_name) -> {
      let db = zones.database()

      let lookup = timestamp.add(date, duration.seconds(leap_offset(date, db)))
      case tzcalendar.to_time_and_zone(lookup, zone_name, db) {
        Ok(time_and_zone) -> {
          let #(date, time) = timestamp.to_calendar(date, time_and_zone.offset)
          #(date, time, time_and_zone.is_dst, time_and_zone.offset, zone_name)
        }
        Error(_) -> {
          let #(date, time) = timestamp.to_calendar(date, duration.empty)
          #(date, time, False, duration.empty, "UTC")
        }
      }
    }
  }
}

@external(erlang, "intldate_time_ffi", "system_time_zone")
fn system_time_zone() -> Result(String, Nil) {
  Error(Nil)
}

fn leap_offset(
  the_timestamp: timestamp.Timestamp,
  db: database.TzDatabase,
) -> Int {
  database.leap_seconds(the_timestamp, "UTC", db)
  |> result.unwrap(0)
}
