import vector

pub const point = vector.Point(0.0, 0.0, 0.0)

pub const forward = vector.Point(0.0, 0.0, 1.0)

pub const rotation = vector.Rotation(0.0, 0.0, 0.0)

pub const scale = vector.Scale(1.0, 1.0, 1.0)

pub const transform = vector.Transform(point, rotation, scale)

// ( x: -atan( 1/sqrt(2) ), y: tau/8 )
pub const iso_rotation = vector.Rotation(
  -0.6154797086703873,
  0.7853981633974483,
  0.0,
)

pub const isometric = vector.Transform(point, iso_rotation, scale)
