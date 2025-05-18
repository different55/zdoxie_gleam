import gleam/float
import gleam/result
import gleam_community/maths

const epsilon = 1.0e-9

const tau = 6.283185307179586

/// Point stores 3D coordinates in space.
pub type Point {
  Point(x: Float, y: Float, z: Float)
}

/// Rotation stores an Euler rotation in radians.
pub type Rotation {
  Rotation(x: Float, y: Float, z: Float)
}

/// Boy howdy I wonder what this is.
pub type Scale {
  Scale(x: Float, y: Float, z: Float)
}

pub type Transform {
  Transform(translation: Point, rotation: Rotation, scale: Scale)
}

pub fn pair_to_string(v: Point) -> String {
  float.to_string(float.to_precision(v.x, 2))
  <> ","
  <> float.to_string(float.to_precision(v.y, 2))
}

pub fn point_to_string(v: Point) -> String {
  float.to_string(float.to_precision(v.x, 2))
  <> ","
  <> float.to_string(float.to_precision(v.y, 2))
  <> ","
  <> float.to_string(float.to_precision(v.z, 2))
}

pub fn rotation_to_string(v: Rotation) -> String {
  case v {
    Rotation(0.0, 0.0, 0.0) -> "None"
    _ ->
      float.to_string(float.to_precision(v.x, 2))
      <> ","
      <> float.to_string(float.to_precision(v.y, 2))
      <> ","
      <> float.to_string(float.to_precision(v.z, 2))
  }
}

pub fn scale_to_string(v: Scale) -> String {
  case v, v.x == v.y && v.y == v.z {
    Scale(1.0, 1.0, 1.0), _ -> "None"
    _, True -> float.to_string(float.to_precision(v.x, 2))
    _, _ ->
      float.to_string(float.to_precision(v.x, 2))
      <> ","
      <> float.to_string(float.to_precision(v.y, 2))
      <> ","
      <> float.to_string(float.to_precision(v.z, 2))
  }
}

pub fn transform_to_string(transform: Transform) -> String {
  "( P:"
  <> point_to_string(transform.translation)
  <> ", R:"
  <> rotation_to_string(transform.rotation)
  <> ", S:"
  <> scale_to_string(transform.scale)
  <> " )"
}

/// Merges two transforms into a single Transform that will produce the same
/// result as applying transform a and b in that order.
///
/// Most of these operations don't care much about order, but rotation does.
/// Rotation is the bane of my existence.
/// But I refuse to learn me a quaternion, for good or evil.
pub fn merge_transforms(a: Transform, b: Transform) -> Transform {
  Transform(
    translation: transform(a.translation, b),
    rotation: merge_rotations(a.rotation, b.rotation),
    scale: merge_scales(a.scale, b.scale),
  )
}

pub fn merge_scales(a: Scale, with b: Scale) -> Scale {
  Scale(a.x *. b.x, a.y *. b.y, a.z *. b.z)
}

// Merging rotations without quaternions or matrices makes me sad :(
// But it's better than dealing with quaternions or matrices
pub fn merge_rotations(a: Rotation, with b: Rotation) -> Rotation {
  let right = Point(1.0, 0.0, 0.0) |> rotate(a) |> rotate(b)
  let down = Point(0.0, 1.0, 0.0) |> rotate(a) |> rotate(b)
  let forward = Point(0.0, 0.0, 1.0) |> rotate(a) |> rotate(b)

  case float.absolute_value(forward.x) >. 0.99999 {
    True ->
      Rotation(
        x: 0.0,
        y: case forward.x >. 0.0 {
          True -> tau /. -4.0
          False -> tau /. 4.0
        },
        z: maths.atan2(right.y, down.y),
      )
    False ->
      Rotation(
        x: maths.atan2(-1.0 *. forward.y, forward.z),
        y: -1.0 *. result.unwrap(maths.asin(forward.x), 0.0),
        z: maths.atan2(-1.0 *. down.x, right.x),
      )
  }
}

pub fn transform(v: Point, transform: Transform) -> Point {
  v
  |> multiply(transform.scale)
  |> rotate(transform.rotation)
  |> add(transform.translation)
}

pub fn transform_from_coords(x: Float, y: Float, z: Float) -> Transform {
  Transform(
    translation: Point(x, y, z),
    rotation: Rotation(0.0, 0.0, 0.0),
    scale: Scale(1.0, 1.0, 1.0),
  )
}

/// Rotates a vector around the origin given rotation.
pub fn rotate(v: Point, rotation: Rotation) -> Point {
  v
  |> rotate_z(rotation.z)
  |> rotate_y(rotation.y)
  |> rotate_x(rotation.x)
}

fn rotate_z(v: Point, angle: Float) -> Point {
  let #(x, y) = rotate_axis(angle, v.x, v.y)
  Point(..v, x: x, y: y)
}

fn rotate_y(v: Point, angle: Float) -> Point {
  let #(x, z) = rotate_axis(angle, v.x, v.z)
  Point(..v, x: x, z: z)
}

fn rotate_x(v: Point, angle: Float) -> Point {
  let #(y, z) = rotate_axis(angle, v.y, v.z)
  Point(..v, y: y, z: z)
}

fn rotate_axis(angle: Float, a: Float, b: Float) -> #(Float, Float) {
  let gone_full_circle = {
    let modded =
      angle
      |> float.modulo(maths.tau())
      |> result.unwrap(0.0)
    float.loosely_equals(modded, 0.0, epsilon)
    || float.loosely_equals(modded, maths.tau(), epsilon)
  }
  case gone_full_circle {
    True -> #(a, b)
    False -> {
      let cos = maths.cos(angle)
      let sin = maths.sin(angle)
      let rot_a = { a *. cos } -. { b *. sin }
      let rot_b = { b *. cos } +. { a *. sin }
      #(rot_a, rot_b)
    }
  }
}

pub fn equals(a: Point, b: Point) -> Bool {
  a.x == b.x && a.y == b.y && a.z == b.z
}

pub fn loosely_equals(a: Point, b: Point, epsilon: Float) -> Bool {
  float.loosely_equals(a.x, b.x, epsilon)
  && float.loosely_equals(a.y, b.y, epsilon)
  && float.loosely_equals(a.z, b.z, epsilon)
}

pub fn add(a: Point, b: Point) -> Point {
  Point(a.x +. b.x, a.y +. b.y, a.z +. b.z)
}

pub fn subtract(a: Point, b: Point) -> Point {
  Point(a.x -. b.x, a.y -. b.y, a.z -. b.z)
}

/// Multiply is element-wise multiplication, useful as a 3D scale.
pub fn multiply(a: Point, by b: Scale) -> Point {
  Point(a.x *. b.x, a.y *. b.y, a.z *. b.z)
}

/// Multiplies an entire Point by a scalar factor.
pub fn multiply_scalar(a: Point, by b: Float) -> Point {
  Point(a.x *. b, a.y *. b, a.z *. b)
}

fn flerp(from a: Float, to b: Float, at alpha: Float) -> Float {
  { b -. a } *. alpha +. a
}

/// Linearly interpolates between two vectors
pub fn lerp(from a: Point, to b: Point, at alpha: Float) -> Point {
  Point(
    x: flerp(a.x, b.x, alpha),
    y: flerp(a.y, b.y, alpha),
    z: flerp(a.z, b.z, alpha),
  )
}

/// Returns the length of the vector.
pub fn magnitude(v: Point) -> Float {
  float.absolute_value(v.x *. v.x +. v.y *. v.y +. v.z *. v.z)
  |> float.square_root
  |> result.unwrap(0.0)
}

/// Returns the length of the vector, ignoring the Z component.
pub fn magnitude_2d(v: Point) -> Float {
  float.absolute_value(v.x *. v.x +. v.y *. v.y)
  |> float.square_root
  |> result.unwrap(0.0)
}
