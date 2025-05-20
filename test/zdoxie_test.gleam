import gleeunit
import gleeunit/should
import zdoxie as zdox

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn rotating_by_zero_does_nothing_test() {
  let tests = [
    #(zdox.Point(1.0, 0.0, 0.0), zdox.Point(1.0, 0.0, 0.0)),
    #(zdox.Point(0.0, 1.0, 0.0), zdox.Point(0.0, 1.0, 0.0)),
    #(zdox.Point(0.0, 0.0, 1.0), zdox.Point(0.0, 0.0, 1.0)),
    #(zdox.Point(-1.5, -2.5, -3.5), zdox.Point(-1.5, -2.5, -3.5)),
    #(zdox.Point(-1.5, -2.5, -3.5), zdox.Point(-1.5, -2.5, -3.5)),
  ]
  test_each_one_of_these_things(
    tests,
    fn(point) { zdox.rotate_point(point, zdox.zero_rotation) },
    fn(actual, expected) { zdox.loosely_equals(actual, expected, zdox.epsilon) },
  )
}

pub fn rotating_by_tau_does_nothing_test() {
  let tests = [
    #(zdox.Point(1.0, 0.0, 0.0), zdox.Point(1.0, 0.0, 0.0)),
    #(zdox.Point(0.0, 1.0, 0.0), zdox.Point(0.0, 1.0, 0.0)),
    #(zdox.Point(0.0, 0.0, 1.0), zdox.Point(0.0, 0.0, 1.0)),
    #(zdox.Point(-1.0, -1.0, -1.0), zdox.Point(-1.0, -1.0, -1.0)),
    #(zdox.Point(-1.5, -2.5, -3.5), zdox.Point(-1.5, -2.5, -3.5)),
  ]
  test_each_one_of_these_things(
    tests,
    fn(point) {
      zdox.rotate_point(point, zdox.Rotation(zdox.tau, zdox.tau, zdox.tau))
    },
    fn(actual, expected) { zdox.loosely_equals(actual, expected, zdox.epsilon) },
  )
}

pub fn rotating_by_pi_around_y() {
  let pi = zdox.tau /. 2.0
  let tests = [
    #(zdox.Point(1.0, 0.0, 0.0), zdox.Point(-1.0, 0.0, 0.0)),
    #(zdox.Point(0.0, 1.0, 0.0), zdox.Point(0.0, 1.0, 0.0)),
    #(zdox.Point(0.0, 0.0, 1.0), zdox.Point(0.0, 0.0, -1.0)),
    #(zdox.Point(-1.0, 1.0, -1.0), zdox.Point(1.0, 1.0, 1.0)),
    #(zdox.Point(1.0, -1.0, 1.0), zdox.Point(-1.0, -1.0, -1.0)),
  ]
  test_each_one_of_these_things(
    tests,
    fn(point) { zdox.rotate_point(point, zdox.Rotation(0.0, pi, 0.0)) },
    fn(actual, expected) { zdox.loosely_equals(actual, expected, zdox.epsilon) },
  )
}

fn test_each_one_of_these_things(
  tests: List(#(a, b)),
  experiment: fn(a) -> b,
  evaluation: fn(b, b) -> Bool,
) -> Nil {
  case tests {
    [] -> Nil
    [first, ..rest] -> {
      let #(input, expected) = first
      experiment(input)
      |> evaluation(expected)
      |> should.be_true
      test_each_one_of_these_things(rest, experiment, evaluation)
    }
  }
}
