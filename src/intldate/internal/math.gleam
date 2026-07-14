import gleam/float
import gleam/int

@external(erlang, "math", "pi")
pub fn pi() -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "sin")
pub fn sin(_x: Float) -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "cos")
pub fn cos(_x: Float) -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "tan")
pub fn tan(_x: Float) -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "asin")
pub fn asin(_x: Float) -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "atan")
pub fn atan(_x: Float) -> Float {
  panic as "unsupported Target"
}

@external(erlang, "math", "atan2")
pub fn atan2(_y: Float, _x: Float) -> Float {
  panic as "unsupported Target"
}

pub fn floor_div(a: Int, b: Int) -> Int {
  case int.floor_divide(a, b) {
    Ok(q) -> q
    Error(_) -> 0
  }
}

pub fn floor_div_rem(a: Int, b: Int) -> #(Int, Int) {
  let q = floor_div(a, b)
  let r = case int.modulo(a, b) {
    Ok(r) -> r
    Error(_) -> 0
  }
  #(q, r)
}

pub fn floor_float(x: Float) -> Int {
  float.round(float.floor(x))
}

pub fn ceil_float(x: Float) -> Int {
  float.round(float.ceiling(x))
}

pub fn float_sqrt(x: Float) -> Float {
  case float.square_root(x) {
    Ok(v) -> v
    Error(_) -> 0.0
  }
}

pub fn float_mod(a: Float, b: Float) -> Float {
  case float.modulo(a, b) {
    Ok(v) -> v
    Error(_) -> a
  }
}

pub fn pow10(exponent: Int) -> Int {
  pow10_loop(exponent, 1)
}

fn pow10_loop(exponent: Int, acc: Int) -> Int {
  case exponent {
    0 -> acc
    _ -> pow10_loop(exponent - 1, acc * 10)
  }
}
