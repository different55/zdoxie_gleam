import constants
import vector

// Transform a point with a translation, rotation, and scale.
pub fn point(
  point: vector.Point,
  transformation: vector.Transform,
) -> vector.Point {
  point
  |> vector.multiply(transformation.scale)
  |> vector.rotate(transformation.rotation)
  |> vector.add(transformation.translation)
}

pub fn from_point(translation: vector.Point) -> vector.Transform {
  vector.Transform(..constants.transform, translation:)
}

pub fn from_coords(x: Float, y: Float, z: Float) -> vector.Transform {
  vector.Transform(
    translation: vector.Point(x, y, z),
    rotation: constants.rotation,
    scale: constants.scale,
  )
}
