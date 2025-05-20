import gleam/float
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam_community/maths

pub const zero_point = Point(0.0, 0.0, 0.0)

pub const zero_rotation = Rotation(0.0, 0.0, 0.0)

pub const one_scale = Scale(1.0, 1.0, 1.0)

pub const identity_transform = Transform(zero_point, zero_rotation, one_scale)

pub const forward = Point(0.0, 0.0, 1.0)

pub const default_style = Style("#333", 1.0, False)

/// The rotation necessary to produce an isometric view.
/// ( x: -atan( 1/sqrt(2) ), y: tau/8 )
pub const iso_rotation = Rotation(-0.6154797086703873, 0.7853981633974483, 0.0)

pub const iso_transform = Transform(zero_point, iso_rotation, one_scale)

/// An Object is the powerhouse of the dog. It contains all the information needed
/// to render a pseudo-3D object, and the entire scene is represented by a tree of
/// Objects with a single root Object.
pub type Object {
  Object(
    name: String,
    transform: Transform,
    path: List(PathCommand),
    style: Style,
    children: List(Object),
    composite: Bool,
    prerender: Option(fn(RenderObject) -> RenderObject),
  )
}

/// RenderObject is a half-chewed object that has had its transforms and the
/// transforms of its ancestors applied to it. Any necessary information for
/// rendering has been calculated, and it is ready to be drawn.
pub type RenderObject {
  RenderObject(
    origin: Point,
    normal: Point,
    path: List(PathCommand),
    style: Style,
  )
}

/// While the path property of an Object determines the geometry of an object,
/// this Style type determines how that geometry is rendered.
pub type Style {
  Style(color: String, stroke: Float, fill: Bool)
}

/// PathCommand is a single segment of a path. All paths must start with a
/// Move command, and while an Close command is not necessary, it must be
/// the last command if present.
///
/// Move picks up the virtual 3D pen and moves it to another location without
/// drawing anything along the way.
///
/// Line draws a straight line from the previous point to the given point.
///
/// Arc draws an elliptical arc from the previous point to the given point.
/// The ellipse of this curve fits within a rectangle formed by the previous,
/// corner, and end points. As a consequence of this, a single Arc segment can
/// only be used to draw a quarter of an ellipse at most.
///
/// Bezier draws a cubic Bezier curve from the previous point to the given
/// point using the two control points in the standard Bezier fashion.
pub type PathCommand {
  Move(to: Point)
  Line(to: Point)
  Arc(corner: Point, to: Point)
  Bezier(control_from: Point, control_to: Point, to: Point)
  Close
}

/// This move function is just a convenience for creating a Move command
/// without needing to manually summon a Point.
pub fn move(x: Float, y: Float, z: Float) -> PathCommand {
  Move(Point(x, y, z))
}

/// See [`move`], but this is Line instead.
pub fn line(x: Float, y: Float, z: Float) -> PathCommand {
  Line(Point(x, y, z))
}

/// Prerender_scene takes a root object, a view transform, and applies all of
/// the transforms in the scene hierarchically. It calculates where everything
/// should exist in screen space, and prepares the scene for rendering.
///
/// During this phase, only the information needed for rendering is kept in a
/// single flat list of RenderObjects.
pub fn prerender_scene(
  root object: Object,
  view transform: Transform,
) -> List(RenderObject) {
  do_prerender_scene([#(object, transform)], [])
  |> list.sort(fn(a, b) { float.compare(a.origin.z, b.origin.z) })
}

fn do_prerender_scene(
  queue: List(#(Object, Transform)),
  out: List(RenderObject),
) -> List(RenderObject) {
  case queue {
    [] -> out
    [#(object, transform), ..rest] -> {
      let new_transform = merge_transforms(object.transform, transform)
      let queue =
        list.fold(object.children, rest, fn(acc, child) {
          [#(child, new_transform), ..acc]
        })
      do_prerender_scene(queue, [prerender_object(object, new_transform), ..out])
    }
  }
}

fn prerender_object(object: Object, transform: Transform) -> RenderObject {
  let origin = transform_point(zero_point, transform)
  let front = transform_point(forward, transform)
  RenderObject(
    origin: origin,
    normal: subtract(origin, front),
    path: list.map(object.path, transform_pathcommand(_, transform)),
    style: object.style,
  )
}

/// Applies a transformation to each point of a PathCommand.
pub fn transform_pathcommand(
  command: PathCommand,
  transform: Transform,
) -> PathCommand {
  case command {
    Move(to) -> Move(transform_point(to, transform))
    Line(to) -> Line(transform_point(to, transform))
    Arc(corner, to) ->
      Arc(transform_point(corner, transform), transform_point(to, transform))
    Bezier(control_from, control_to, to) ->
      Bezier(
        transform_point(control_from, transform),
        transform_point(control_to, transform),
        transform_point(to, transform),
      )
    Close -> Close
  }
}

/// Set the color of an Object. This color is applied to both fills and strokes.
/// This function applies to both this object and to any composite children of
/// this object. For example, the individual faces of a cube.
pub fn set_color(on object: Object, to color: String) -> Object {
  // TODO: Make the rest composite-friendly.
  let new_style = Style(..object.style, color:)
  Object(..object, style: new_style)
  |> update_composite_children(set_color(_, color))
}

fn update_composite_children(
  object: Object,
  function: fn(Object) -> Object,
) -> Object {
  Object(
    ..object,
    children: list.map(object.children, fn(child) -> Object {
      case child.composite {
        True -> function(child)
        False -> child
      }
    }),
  )
}

// pub fn set_component_color(
//   on object: Object,
//   with name: String,
//   to color: String,
// ) -> Object {
//   todo
// }

/// Set whether to fill the Object when rendering, or to only draw a stroke.
pub fn set_fill(on object: Object, to fill: Bool) -> Object {
  Object(..object, style: Style(..object.style, fill:))
  |> update_composite_children(set_fill(_, fill))
}

/// Set the width of the stroke to use when rendering the object. Set it to 0.0
/// to disable the stroke.
pub fn set_stroke(on object: Object, to stroke: Float) -> Object {
  let new_style = Style(..object.style, stroke:)
  Object(..object, style: new_style)
  |> update_composite_children(set_stroke(_, stroke))
}

/// Sets the translation of the object to the given point, changing its position.
pub fn set_translation(on object: Object, to translation: Point) -> Object {
  Object(
    ..object,
    transform: Transform(..object.transform, translation: translation),
  )
}

/// Sets only the X component of the object's translation.
pub fn set_translation_x(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      translation: Point(..object.transform.translation, x: value),
    ),
  )
}

/// Sets only the Y component of the object's translation.
pub fn set_translation_y(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      translation: Point(..object.transform.translation, y: value),
    ),
  )
}

pub fn set_translation_z(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      translation: Point(..object.transform.translation, z: value),
    ),
  )
}

/// Sets the rotation of the object to the given rotation, changing its
/// orientation and the orientation of all of its descendents for all time.
/// As Gleam is immutable, you know this to be true.
pub fn set_rotation(on object: Object, to rotation: Rotation) -> Object {
  Object(..object, transform: Transform(..object.transform, rotation: rotation))
}

pub fn set_rotation_x(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      rotation: Rotation(..object.transform.rotation, x: value),
    ),
  )
}

pub fn set_rotation_y(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      rotation: Rotation(..object.transform.rotation, y: value),
    ),
  )
}

pub fn set_rotation_z(on object: Object, to value: Float) -> Object {
  Object(
    ..object,
    transform: Transform(
      ..object.transform,
      rotation: Rotation(..object.transform.rotation, z: value),
    ),
  )
}

/// Sets the scale on the object.
/// Some treacherous objects won't render correctly with a non-uniform scale.
pub fn set_scale(on object: Object, to scale: Scale) -> Object {
  Object(..object, transform: Transform(..object.transform, scale: scale))
}

pub fn set_scale_uniform(on object: Object, to scale: Float) -> Object {
  Object(
    ..object,
    transform: Transform(..object.transform, scale: Scale(scale, scale, scale)),
  )
}

/// Sets the name of the object, allowing you to locate it later in the scene.
pub fn set_name(on object: Object, to name: String) -> Object {
  Object(..object, name: name)
}

/// Updates any objects with a given name in the scene. If multiple objects
/// share a name, they will all be updated with the given function.
pub fn update_named_objects(
  in scene: Object,
  named name: String,
  with function: fn(Object) -> Object,
) -> Object {
  map_scene(scene, fn(object) {
    case object.name == name {
      True -> function(object)
      False -> object
    }
  })
}

/// Runs a function on every object in the scene, returning a new world that
/// has been reshaped according to your whims.
fn map_scene(scene: Object, function: fn(Object) -> Object) -> Object {
  Object(
    ..function(scene),
    children: list.map(scene.children, map_scene(_, function)),
  )
}

/// Attaches an object as a child and returns the proud parent.
pub fn add_child(object: Object, child: Object) -> Object {
  Object(..object, children: [child, ..object.children])
}

/// Attachs a gaggle of children to the object and returns the haggard parent.
pub fn add_children(object: Object, children: List(Object)) -> Object {
  Object(..object, children: list.append(object.children, children))
}

/// Inserts a child into the scene under the specified parent name. Returns the
/// updated scene.
pub fn insert_child(
  child: Object,
  in scene: Object,
  under parent_name: String,
) -> Object {
  map_scene(scene, fn(object) {
    case object.name == parent_name {
      True -> add_child(object, child)
      False -> object
    }
  })
}

pub fn set_composite(object: Object, value: Bool) -> Object {
  Object(..object, composite: value)
}

pub const epsilon = 1.0e-9

pub const tau = 6.283185307179586

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

/// Transform stores a translation, rotation, and scale.
pub type Transform {
  Transform(translation: Point, rotation: Rotation, scale: Scale)
}

pub fn point_to_string_2d(v: Point) -> String {
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

/// Merges two transforms into a single Transform that will produce the same
/// result as applying transform a and b in that order.
///
/// Most of these operations don't care much about order, but rotation does.
/// Rotation is the bane of my existence.
/// But I refuse to learn me a quaternion, for good or evil.
pub fn merge_transforms(a: Transform, b: Transform) -> Transform {
  Transform(
    translation: transform_point(a.translation, b),
    rotation: merge_rotations(a.rotation, b.rotation),
    scale: merge_scales(a.scale, b.scale),
  )
}

fn merge_scales(a: Scale, with b: Scale) -> Scale {
  Scale(a.x *. b.x, a.y *. b.y, a.z *. b.z)
}

// Merging rotations without quaternions or matrices makes me sad :(
// But it's better than dealing with quaternions or matrices
fn merge_rotations(a: Rotation, with b: Rotation) -> Rotation {
  let right = Point(1.0, 0.0, 0.0) |> rotate_point(a) |> rotate_point(b)
  let down = Point(0.0, 1.0, 0.0) |> rotate_point(a) |> rotate_point(b)
  let forward = Point(0.0, 0.0, 1.0) |> rotate_point(a) |> rotate_point(b)

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

pub fn transform_point(v: Point, transform: Transform) -> Point {
  v
  |> multiply(transform.scale)
  |> rotate_point(transform.rotation)
  |> add(transform.translation)
}

pub fn new_transform_from_coords(x: Float, y: Float, z: Float) -> Transform {
  Transform(
    translation: Point(x, y, z),
    rotation: zero_rotation,
    scale: one_scale,
  )
}

pub fn new_transform_from_point(v: Point) -> Transform {
  Transform(..identity_transform, translation: v)
}

pub fn set_transform_translation(
  on transform: Transform,
  to translation: Point,
) -> Transform {
  Transform(..transform, translation: translation)
}

pub fn set_transform_rotation(
  on transform: Transform,
  to rotation: Rotation,
) -> Transform {
  Transform(..transform, rotation: rotation)
}

pub fn set_transform_scale(
  on transform: Transform,
  to scale: Scale,
) -> Transform {
  Transform(..transform, scale: scale)
}

/// Rotates a vector around the origin given rotation.
pub fn rotate_point(v: Point, rotation: Rotation) -> Point {
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

/// Returns true if the two points are exactly equal.
/// Unless they came from the same place, they probably won't be due to Floating Point Nonsense. Check out loosely_equals for that.
pub fn equals(a: Point, b: Point) -> Bool {
  a.x == b.x && a.y == b.y && a.z == b.z
}

/// Returns true if two points are within a small distance from each other.
pub fn loosely_equals(a: Point, b: Point, epsilon: Float) -> Bool {
  subtract(a, b)
  |> magnitude
  |> float.loosely_equals(0.0, epsilon)
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
