import gleam/float
import intldate/internal/math

pub const synodic_month = 29.530588853

const tropical_year = 365.242191

const day_ms = 86_400_000.0

const minute_ms = 60_000.0

const julian_epoch_ms = -210_866_760_000_000.0

const jd_epoch = 2_447_891.5

pub type CalendarAstronomer {
  CalendarAstronomer(time: Float)
}

pub type EquatorialCoordinates {
  EquatorialCoordinates(ascension: Float, declination: Float)
}

pub type SunLongitudeResult {
  SunLongitudeResult(longitude: Float, mean_anomaly: Float)
}

pub type MoonPositionResult {
  MoonPositionResult(
    ascension: Float,
    declination: Float,
    moon_eclip_long: Float,
    sun_longitude: Float,
  )
}

fn sun_eta_g() -> Float {
  279.403303 *. { math.pi() /. 180.0 }
}

fn sun_omega_g() -> Float {
  282.768422 *. { math.pi() /. 180.0 }
}

const sun_e = 0.016713

fn moon_l0() -> Float {
  318.351648 *. { math.pi() /. 180.0 }
}

fn moon_p0() -> Float {
  36.34041 *. { math.pi() /. 180.0 }
}

fn moon_n0() -> Float {
  318.510107 *. { math.pi() /. 180.0 }
}

fn moon_i() -> Float {
  5.145366 *. { math.pi() /. 180.0 }
}

pub fn winter_solstice() -> Float {
  { math.pi() *. 3.0 } /. 2.0
}

pub const new_moon = 0.0

fn norm2pi(angle: Float) -> Float {
  math.float_mod(angle, math.pi() *. 2.0)
}

fn norm_pi(angle: Float) -> Float {
  math.float_mod(angle +. math.pi(), math.pi() *. 2.0) -. math.pi()
}

fn true_anomaly_loop(
  e: Float,
  mean_anomaly: Float,
  eccentricity: Float,
) -> Float {
  let delta = e -. eccentricity *. math.sin(e) -. mean_anomaly
  let next_e = e -. delta /. { 1.0 -. eccentricity *. math.cos(e) }
  case float.absolute_value(delta) >. 1.0e-5 {
    True -> true_anomaly_loop(next_e, mean_anomaly, eccentricity)
    False -> next_e
  }
}

fn true_anomaly(mean_anomaly: Float, eccentricity: Float) -> Float {
  let e = true_anomaly_loop(mean_anomaly, mean_anomaly, eccentricity)
  let ratio_sqrt =
    math.float_sqrt({ 1.0 +. eccentricity } /. { 1.0 -. eccentricity })
  2.0 *. math.atan(math.tan(e /. 2.0) *. ratio_sqrt)
}

pub fn create_calendar_astronomer(time_millis: Float) -> CalendarAstronomer {
  CalendarAstronomer(time: time_millis)
}

pub fn get_julian_day(astronomer: CalendarAstronomer) -> Float {
  { astronomer.time -. julian_epoch_ms } /. day_ms
}

pub fn ecliptic_to_equatorial(
  astronomer: CalendarAstronomer,
  eclip_long: Float,
  eclip_lat: Float,
) -> EquatorialCoordinates {
  let obliq = ecliptic_obliquity(astronomer)
  let sin_e = math.sin(obliq)
  let cos_e = math.cos(obliq)
  let sin_l = math.sin(eclip_long)
  let cos_l = math.cos(eclip_long)
  let sin_b = math.sin(eclip_lat)
  let cos_b = math.cos(eclip_lat)
  let tan_b = math.tan(eclip_lat)
  EquatorialCoordinates(
    ascension: math.atan2(sin_l *. cos_e -. tan_b *. sin_e, cos_l),
    declination: math.asin(sin_b *. cos_e +. cos_b *. sin_e *. sin_l),
  )
}

pub fn ecliptic_obliquity(astronomer: CalendarAstronomer) -> Float {
  let epoch = 2_451_545.0
  let t = { get_julian_day(astronomer) -. epoch } /. 36_525.0
  let eclip_obliquity_deg =
    23.439292
    -. { 46.815 /. 3600.0 }
    *. t
    -. { 0.0006 /. 3600.0 }
    *. t
    *. t
    +. { 0.00181 /. 3600.0 }
    *. t
    *. t
    *. t
  eclip_obliquity_deg *. { math.pi() /. 180.0 }
}

pub fn sun_longitude_at(j_day: Float) -> SunLongitudeResult {
  let day = j_day -. jd_epoch
  let epoch_angle = norm2pi({ math.pi() *. 2.0 } /. tropical_year *. day)
  let mean_anomaly = norm2pi(epoch_angle +. sun_eta_g() -. sun_omega_g())
  let longitude = norm2pi(true_anomaly(mean_anomaly, sun_e) +. sun_omega_g())
  SunLongitudeResult(longitude:, mean_anomaly:)
}

pub fn get_sun_longitude(astronomer: CalendarAstronomer) -> Float {
  sun_longitude_at(get_julian_day(astronomer)).longitude
}

pub fn get_sun_longitude_and_mean_anomaly(
  astronomer: CalendarAstronomer,
) -> SunLongitudeResult {
  sun_longitude_at(get_julian_day(astronomer))
}

pub fn get_moon_position(astronomer: CalendarAstronomer) -> MoonPositionResult {
  let sun_result = get_sun_longitude_and_mean_anomaly(astronomer)
  let sun_longitude = sun_result.longitude
  let mean_anomaly_sun = sun_result.mean_anomaly

  let day = get_julian_day(astronomer) -. jd_epoch

  let mean_longitude =
    norm2pi({ 13.1763966 *. math.pi() } /. 180.0 *. day +. moon_l0())
  let mean_anomaly_moon0 =
    norm2pi(
      mean_longitude -. { 0.1114041 *. math.pi() } /. 180.0 *. day -. moon_p0(),
    )

  let evection =
    { 1.2739 *. math.pi() }
    /. 180.0
    *. math.sin(
      2.0 *. { mean_longitude -. sun_longitude } -. mean_anomaly_moon0,
    )
  let annual = { 0.1858 *. math.pi() } /. 180.0 *. math.sin(mean_anomaly_sun)
  let a3 = { 0.37 *. math.pi() } /. 180.0 *. math.sin(mean_anomaly_sun)
  let mean_anomaly_moon = mean_anomaly_moon0 +. evection -. annual -. a3

  let center = { 6.2886 *. math.pi() } /. 180.0 *. math.sin(mean_anomaly_moon)
  let a4 = { 0.214 *. math.pi() } /. 180.0 *. math.sin(2.0 *. mean_anomaly_moon)

  let moon_longitude0 = mean_longitude +. evection +. center -. annual +. a4

  let variation =
    { 0.6583 *. math.pi() }
    /. 180.0
    *. math.sin(2.0 *. { moon_longitude0 -. sun_longitude })
  let moon_longitude = moon_longitude0 +. variation

  let node_longitude0 =
    norm2pi(moon_n0() -. { 0.0529539 *. math.pi() } /. 180.0 *. day)
  let node_longitude =
    node_longitude0
    -. { 0.16 *. math.pi() }
    /. 180.0
    *. math.sin(mean_anomaly_sun)

  let y = math.sin(moon_longitude -. node_longitude)
  let x = math.cos(moon_longitude -. node_longitude)

  let moon_eclip_long = math.atan2(y *. math.cos(moon_i()), x) +. node_longitude
  let moon_eclip_lat = math.asin(y *. math.sin(moon_i()))

  let equatorial =
    ecliptic_to_equatorial(astronomer, moon_eclip_long, moon_eclip_lat)

  MoonPositionResult(
    ascension: equatorial.ascension,
    declination: equatorial.declination,
    moon_eclip_long:,
    sun_longitude:,
  )
}

pub fn get_moon_age(astronomer: CalendarAstronomer) -> Float {
  let position = get_moon_position(astronomer)
  norm2pi(position.moon_eclip_long -. position.sun_longitude)
}

fn time_of_angle_loop(
  current: CalendarAstronomer,
  eval_fn: fn(CalendarAstronomer) -> Float,
  desired: Float,
  period_days: Float,
  epsilon: Float,
  next: Bool,
  last_angle: Float,
  delta_t: Float,
  last_delta_t: Float,
  start_time: Float,
) -> Float {
  let angle = eval_fn(current)
  let factor = float.absolute_value(delta_t /. norm_pi(angle -. last_angle))
  let new_delta_t = norm_pi(desired -. angle) *. factor

  case float.absolute_value(new_delta_t) >. float.absolute_value(last_delta_t) {
    True -> {
      let delta = float.ceiling({ period_days *. day_ms } /. 8.0)
      let retry_start =
        CalendarAstronomer(
          start_time
          +. case next {
            True -> delta
            False -> 0.0 -. delta
          },
        )
      time_of_angle(retry_start, eval_fn, desired, period_days, epsilon, next)
    }
    False -> {
      let new_current =
        CalendarAstronomer(current.time +. float.ceiling(new_delta_t))
      case float.absolute_value(new_delta_t) <=. epsilon {
        True -> new_current.time
        False ->
          time_of_angle_loop(
            new_current,
            eval_fn,
            desired,
            period_days,
            epsilon,
            next,
            angle,
            new_delta_t,
            new_delta_t,
            start_time,
          )
      }
    }
  }
}

pub fn time_of_angle(
  astronomer: CalendarAstronomer,
  eval_fn: fn(CalendarAstronomer) -> Float,
  desired: Float,
  period_days: Float,
  epsilon: Float,
  next: Bool,
) -> Float {
  let last_angle = eval_fn(astronomer)
  let delta_angle0 = norm2pi(desired -. last_angle)
  let delta_t =
    {
      delta_angle0
      +. case next {
        True -> 0.0
        False -> 0.0 -. { math.pi() *. 2.0 }
      }
    }
    *. { { period_days *. day_ms } /. { math.pi() *. 2.0 } }

  let start_time = astronomer.time

  let current = CalendarAstronomer(astronomer.time +. float.ceiling(delta_t))

  time_of_angle_loop(
    current,
    eval_fn,
    desired,
    period_days,
    epsilon,
    next,
    last_angle,
    delta_t,
    delta_t,
    start_time,
  )
}

pub fn get_sun_time(
  astronomer: CalendarAstronomer,
  desired: Float,
  next: Bool,
) -> Float {
  time_of_angle(
    astronomer,
    get_sun_longitude,
    desired,
    tropical_year,
    minute_ms,
    next,
  )
}

pub fn get_moon_time(
  astronomer: CalendarAstronomer,
  desired: Float,
  next: Bool,
) -> Float {
  time_of_angle(
    astronomer,
    get_moon_age,
    desired,
    synodic_month,
    minute_ms,
    next,
  )
}
