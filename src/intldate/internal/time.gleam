import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import tzif/database
import tzif/tzcalendar

pub fn resolve(
  date: timestamp.Timestamp,
  time_zone: Option(String),
) -> Result(
  #(calendar.Date, calendar.TimeOfDay, Bool, duration.Duration, String),
  Nil,
) {
  let time_zone = case time_zone {
    Some(_) -> time_zone
    None -> option.from_result(system_time_zone())
  }

  case time_zone {
    None -> {
      let #(date, time) = timestamp.to_calendar(date, duration.empty)
      Ok(#(date, time, False, duration.empty, "UTC"))
    }
    Some(zone_name) -> {
      use db <- result.try(resolve_database())

      let lookup = timestamp.add(date, duration.seconds(leap_offset(date, db)))
      case tzcalendar.to_time_and_zone(lookup, zone_name, db) {
        Ok(time_and_zone) -> {
          let #(date, time) = timestamp.to_calendar(date, time_and_zone.offset)
          Ok(#(
            date,
            time,
            time_and_zone.is_dst,
            time_and_zone.offset,
            zone_name,
          ))
        }
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn resolve_database() -> Result(database.TzDatabase, Nil) {
  case get_default_time_zone_database() {
    Some(db) -> Ok(db)
    None -> database.load_from_os()
  }
}

pub fn set_default_time_zone_database(db: database.TzDatabase) -> Nil {
  ffi_set_default_time_zone_database(db)
}

fn get_default_time_zone_database() -> Option(database.TzDatabase) {
  option.from_result(ffi_get_default_time_zone_database())
}

@external(erlang, "intldate_time_ffi", "system_time_zone")
fn system_time_zone() -> Result(String, Nil) {
  Error(Nil)
}

@external(erlang, "intldate_time_ffi", "set_default_time_zone_database")
fn ffi_set_default_time_zone_database(_db: database.TzDatabase) -> Nil {
  Nil
}

@external(erlang, "intldate_time_ffi", "get_default_time_zone_database")
fn ffi_get_default_time_zone_database() -> Result(database.TzDatabase, Nil) {
  Error(Nil)
}

fn leap_offset(
  the_timestamp: timestamp.Timestamp,
  db: database.TzDatabase,
) -> Int {
  database.leap_seconds(the_timestamp, "UTC", db)
  |> result.unwrap(0)
}
