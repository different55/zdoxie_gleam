import gleam/int
import gleam/list
import gleam/option.{None}
import gleam_community/maths
import zdoxie.{
  type Object, type PathCommand, Arc, Close, Object, Point, add_children, line,
  move, set_stroke, tau,
}

pub fn new_anchor() -> Object {
  Object(
    name: "",
    transform: zdoxie.identity_transform,
    path: [],
    style: zdoxie.default_style,
    children: [],
    composite: False,
    prerender: None,
  )
}

pub fn to_anchor(object: Object) -> Object {
  object
  |> to_shape([])
}

pub fn new_shape(path: List(PathCommand)) -> Object {
  new_anchor()
  |> to_shape(path)
}

pub fn to_shape(object: Object, path: List(PathCommand)) -> Object {
  Object(..object, path:)
}

pub fn set_path(object: Object, path: List(PathCommand)) -> Object {
  to_shape(object, path)
}

pub fn new_sphere(diameter: Float) -> Object {
  new_anchor()
  |> to_sphere(diameter)
}

pub fn to_sphere(object: Object, diameter: Float) -> Object {
  object
  |> to_shape([move(0.0, 0.0, 0.0), line(0.0, 0.0, 0.0)])
  |> set_stroke(diameter /. 2.0)
}

pub fn new_capsule(radius: Float, length: Float) -> Object {
  new_anchor()
  |> to_capsule(radius, length)
}

pub fn to_capsule(object: Object, radius: Float, length: Float) -> Object {
  object
  |> to_shape([move(0.0, 0.0, length *. -0.5), line(0.0, 0.0, length *. 0.5)])
  |> set_stroke(radius)
}

pub fn new_rect(width: Float, height: Float) -> Object {
  new_anchor()
  |> to_rect(width, height)
}

pub fn to_rect(object: Object, width: Float, height: Float) -> Object {
  object
  |> to_shape([
    move(width *. -0.5, height *. -0.5, 0.0),
    line(width *. 0.5, height *. -0.5, 0.0),
    line(width *. 0.5, height *. 0.5, 0.0),
    line(width *. -0.5, height *. 0.5, 0.0),
    Close,
  ])
}

pub fn new_circle(diameter: Float) -> Object {
  new_ellipse_arc(diameter, diameter, 4)
}

pub fn to_circle(object: Object, diameter: Float) -> Object {
  to_ellipse_arc(object, diameter, diameter, 4)
}

pub fn new_ellipse(width: Float, height: Float) -> Object {
  new_ellipse_arc(width, height, 4)
}

pub fn to_ellipse(object: Object, width: Float, height: Float) -> Object {
  to_ellipse_arc(object, width, height, 4)
}

// TODO: Replace quarters with start/stop angles.
pub fn new_ellipse_arc(width: Float, height: Float, quarters: Int) -> Object {
  new_anchor()
  |> to_ellipse_arc(width, height, quarters)
}

pub fn to_ellipse_arc(
  object: Object,
  width: Float,
  height: Float,
  quarters: Int,
) -> Object {
  let left = width *. -0.5
  let right = width *. 0.5
  let bottom = height *. 0.5
  let top = height *. -0.5
  [
    [move(0.0, top, 0.0), Arc(Point(right, top, 0.0), Point(right, 0.0, 0.0))],
    case quarters > 1 {
      True -> [Arc(Point(right, bottom, 0.0), Point(0.0, bottom, 0.0))]
      False -> []
    },
    case quarters > 2 {
      True -> [Arc(Point(left, bottom, 0.0), Point(left, 0.0, 0.0))]
      False -> []
    },
    case quarters > 3 {
      True -> [Arc(Point(left, top, 0.0), Point(0.0, top, 0.0))]
      False -> []
    },
  ]
  |> list.flatten
  |> to_shape(object, _)
}

pub fn new_polygon(sides: Int, radius: Float) -> Object {
  new_anchor()
  |> to_polygon(sides, radius)
}

pub fn to_polygon(object: Object, sides: Int, radius: Float) -> Object {
  object
  |> to_shape(
    list.range(0, sides - 1)
    |> list.map(fn(i) {
      let theta = int.to_float(i) /. int.to_float(sides) *. tau -. tau /. 4.0
      let x = maths.cos(theta) *. radius
      let y = maths.sin(theta) *. radius
      case i {
        0 -> move(x, y, 0.0)
        _ -> line(x, y, 0.0)
      }
    })
    |> list.append([Close]),
  )
}

pub fn new_box(width: Float, height: Float, depth: Float) -> Object {
  new_anchor()
  |> to_box(width, height, depth)
}

pub fn to_box(
  object: Object,
  width: Float,
  height: Float,
  depth: Float,
) -> Object {
  object
  |> add_children([
    new_rect(width, height)
      |> zdoxie.set_name("frontFace")
      |> zdoxie.set_translation_z(depth *. 0.5)
      |> zdoxie.set_composite(True),
    new_rect(width, height)
      |> zdoxie.set_name("rearFace")
      |> zdoxie.set_translation_z(depth *. -0.5)
      |> zdoxie.set_rotation_y(tau /. 2.0)
      |> zdoxie.set_composite(True),
    new_rect(depth, height)
      |> zdoxie.set_name("leftFace")
      |> zdoxie.set_translation_x(width *. -0.5)
      |> zdoxie.set_rotation_y(tau /. -4.0)
      |> zdoxie.set_composite(True),
    new_rect(depth, height)
      |> zdoxie.set_name("rightFace")
      |> zdoxie.set_translation_x(width *. 0.5)
      |> zdoxie.set_rotation_y(tau /. 4.0)
      |> zdoxie.set_composite(True),
    new_rect(width, depth)
      |> zdoxie.set_name("topFace")
      |> zdoxie.set_translation_y(height *. -0.5)
      |> zdoxie.set_rotation_x(tau /. -4.0)
      |> zdoxie.set_composite(True),
    new_rect(width, depth)
      |> zdoxie.set_name("bottomFace")
      |> zdoxie.set_translation_y(height *. 0.5)
      |> zdoxie.set_rotation_x(tau /. 4.0)
      |> zdoxie.set_composite(True),
  ])
  |> zdoxie.set_fill(True)
}
