import constants
import gleam/bit_array
import gleam/erlang/process
import gleam/float
import gleam/io
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element
import lustre/element/svg
import transform
import vector.{type Point, type Transform, Point, Rotation, Transform}

const orange = "#ffd596"

const blue = "#9ce7ff"

const red = "#ff6262"

const pink = "#ffaff3"

const green = "#c8ffa7"

pub fn main() {
  let scene =
    sphere(10.0, constants.transform, pink, [
      sphere(1.0, vector.transform_from_coords(7.0, 0.0, 0.0), orange, []),
      sphere(1.25, vector.transform_from_coords(0.0, 0.0, -10.0), blue, []),
      sphere(
        2.0,
        Transform(
          Point(0.0, 0.0, 15.0),
          Rotation(0.0, 6.28 /. 8.0, 0.0),
          constants.scale,
        ),
        red,
        [sphere(0.5, vector.transform_from_coords(-1.7, 0.0, 0.0), orange, [])],
      ),
      sphere(1.1, vector.transform_from_coords(-20.0, 0.0, 0.0), green, []),
    ])
  orbit_scene(scene, constants.isometric)
}

pub fn orbit_scene(scene: Object, transform: Transform) {
  let flat = prerender_scene(scene, transform)
  flat
  |> render_to_svg(64.0, 32.0, 1.0, 10.0)
  |> display_svg_inline_iterm2
  let slight_rotation =
    Transform(constants.point, Rotation(0.0, 0.02, 0.0), constants.scale)
  process.sleep(167)
  orbit_scene(scene, vector.merge_transforms(transform, slight_rotation))
}

fn save_cursor_position() {
  io.print("\u{001b}[s")
}

fn restore_cursor_position() {
  io.print("\u{001b}[u")
}

pub fn print_object(object: Object) -> String {
  print_object_loop(object, 0) <> "\n"
}

pub fn print_object_loop(object: Object, level: Int) -> String {
  let indent = string.repeat(" ", level * 2)
  list.flatten([
    ["Object:"],
    ["* Transform: " <> vector.transform_to_string(object.transform)],
    ["* Path: " <> render_path(object.path)],
    ["* Style: " <> style_to_string(object.style)],
    ["* Children: "],
    list.map(object.children, print_object_loop(_, level + 1)),
  ])
  |> list.map(fn(str) -> String { indent <> str })
  |> string.join("\n")
}

/// The basic Object type is used for anything that exists in the scene.
/// It has a transform, and can have a list of children.
/// It can optionally have a physical form to render to the screen.
pub type Object {
  Object(
    transform: Transform,
    path: List(PathCommand),
    style: Style,
    children: List(Object),
  )
}

pub type RenderObject {
  RenderObject(
    origin: Point,
    normal: Point,
    path: List(PathCommand),
    style: Style,
  )
}

pub type PathCommand {
  Move(to: Point)
  Line(to: Point)
  Close
}

fn display_svg_inline_iterm2(svg: String) {
  let image_data = svg |> bit_array.from_string |> bit_array.base64_encode(True)
  save_cursor_position()
  io.print("\u{001b}]1337;File=inline=1;width=60:" <> image_data <> "\u{0007}")
  restore_cursor_position()
}

fn render_to_svg(
  scene: List(RenderObject),
  width: Float,
  height: Float,
  zoom: Float,
  scale: Float,
) -> String {
  let view_width = width /. zoom
  let view_height = height /. zoom
  let view_x = -1.0 *. view_width /. 2.0
  let view_y = -1.0 *. view_height /. 2.0
  let width = view_width *. scale
  let height = view_height *. scale
  element.to_string(svg.svg(
    [
      attribute.attribute(
        "viewbox",
        float.to_string(view_x)
          <> " "
          <> float.to_string(view_y)
          <> " "
          <> float.to_string(view_width)
          <> " "
          <> float.to_string(view_height),
      ),
      attribute.attribute("width", float.to_string(width)),
      attribute.attribute("height", float.to_string(height)),
    ],
    list.map(scene, render_object_to_svg),
  ))
}

// TODO: Add support for fills
pub fn render_object_to_svg(object: RenderObject) -> element.Element(a) {
  // <path stroke-linecap="round" stroke-linejoin="round" d="M-29.524,-2.429 L-88.488,-4.023 L-88.488,61.293 L-29.524,62.887 Z" stroke="#ccd" stroke-width="12" fill="#ccd"/>
  case object.path {
    [] -> element.none()
    _ ->
      element.advanced(
        "",
        "path",
        [
          attribute.attribute("stroke-linecap", "round"),
          attribute.attribute("stroke-linejoin", "round"),
          attribute.attribute(
            "stroke-width",
            float.to_string(object.style.stroke),
          ),
          attribute.attribute("stroke", object.style.color),
          attribute.attribute("d", render_path(object.path)),
        ],
        [],
        True,
        False,
      )
  }
}

pub fn print_renderobject(object: RenderObject) -> String {
  "RenderObject: "
  <> vector.pair_to_string(object.origin)
  <> " S:"
  <> style_to_string(object.style)
}

pub fn render_path(path: List(PathCommand)) -> String {
  case path {
    // paths must start with a Move command OR ELSE
    [Move(to), ..rest] ->
      render_path_loop(rest, "M" <> vector.pair_to_string(to))
    _ -> ""
  }
}

pub fn render_path_loop(path: List(PathCommand), acc: String) -> String {
  case path {
    [] -> acc
    [Move(to), ..rest] ->
      render_path_loop(rest, acc <> " M" <> vector.pair_to_string(to))
    [Line(to), ..rest] ->
      render_path_loop(rest, acc <> " L" <> vector.pair_to_string(to))
    [Close, ..rest] -> render_path_loop(rest, acc <> " Z")
  }
}

// We tail call now
// pub fn prerender_scene( root object: Object, view transform: Transform ) -> List(RenderObject) {
//   let transform = vector.merge_transforms( object.transform, transform )
//   [
//     prerender_object( object, transform ),
//     ..list.flat_map( object.children, prerender_scene( _, transform ) )
//   ]
// }

pub fn prerender_scene(
  root object: Object,
  view transform: Transform,
) -> List(RenderObject) {
  do_prerender_scene([#(object, transform)], [])
  |> list.sort(fn(a, b) { float.compare(a.origin.z, b.origin.z) })
}

pub fn do_prerender_scene(
  queue: List(#(Object, Transform)),
  out: List(RenderObject),
) -> List(RenderObject) {
  case queue {
    [] -> out
    [#(object, transform), ..rest] -> {
      let new_transform = vector.merge_transforms(object.transform, transform)
      let queue =
        list.fold(object.children, rest, fn(acc, child) {
          [#(child, new_transform), ..acc]
        })
      do_prerender_scene(queue, [prerender_object(object, new_transform), ..out])
    }
  }
}

pub fn prerender_object(object: Object, transform: Transform) -> RenderObject {
  let origin = transform.point(constants.point, transform)
  let front = transform.point(constants.forward, transform)
  RenderObject(
    origin: origin,
    normal: vector.subtract(origin, front),
    path: list.map(object.path, transform_pathcommand(_, transform)),
    style: object.style,
  )
}

pub fn transform_pathcommand(
  command: PathCommand,
  transform: Transform,
) -> PathCommand {
  case command {
    Move(to) -> Move(vector.transform(to, transform))
    Line(to) -> Line(vector.transform(to, transform))
    Close -> Close
  }
}

// pub fn apply_transforms( object: Object ) -> Object {
//   let children = list.map( object.children, apply_transforms )
//   Object( ..object, children: children )
// }

// pub fn apply_transforms_recurse( object: Object, transforms: List(vector.Transform) ) -> Object {
//   let transforms = [ object.transform, ..transforms ]
//   let transformed_children = object.children
//   |> list.map(apply_transforms_recurse( _, transforms ))
//   Object(
//     ..apply_transforms_loop( object, transforms ),
//     children: transformed_children,
//   )
// }

// pub fn apply_transforms_loop( object: Object, transforms: List(vector.Transform) ) -> Object {
//   case transforms {
//     [] -> object
//     [first, ..rest] -> apply_transforms_loop(apply_single_transform_innermost_thingy(object, first), rest)
//   }
// }

// pub fn apply_single_transform_innermost_thingy( object: Object, transform: vector.Transform ) -> Object {
//   Object(
//     ..object,
//     shape: transform_shape( object.shape, transform ),
//   )
// }

/// Flatten flattens the parent-child hierarchy of Object into a flat list of objects.
/// In this flattened representation, all of the children fields will be replaced with empty lists.
// pub fn flatten( object: Object ) -> List(Object) {
//   [ Object(..object, children: []), ..list.flat_map( object.children, flatten ) ]
// }

// pub fn zsort( objects: List(Object) ) -> List(Object) {
//   todo
// }

// pub fn transform_shape( shape: Shape, transform: vector.Transform ) -> Shape {
//   Shape(
//     ..shape,
//     origin: vector.transform( shape.origin, transform ),
//     front: vector.transform( shape.origin, transform ),
//     path: list.map( shape.path, transform_pathcommand( _, transform ) )
//   )
// }

// pub fn sphere_shape( radius: Float ) -> Shape {
//   Shape(
//     origin: constants.point,
//     front: constants.forward,
//     path: [
//       Move(vector.Point( 0., 0., 0. )),
//       Line(vector.Point( 0., 0., 0. )),
//     ],
//     style: Some(Style( "#333", radius, False ))
//   )
// }

pub fn sphere(
  radius: Float,
  transform: Transform,
  color: String,
  children: List(Object),
) -> Object {
  Object(
    transform: transform,
    path: [Move(Point(0.0, 0.0, 0.0)), Line(Point(0.0, 0.0, 0.0))],
    style: Style(color, radius, False),
    children: children,
  )
}

pub opaque type Path {
  Path(commands: List(PathCommand))
}

pub type PathError {
  PathEmpty
  PathTooShort
  PathMustStartWithMove
  PathMustHaveAtLeastOneElementThatActuallyDrawsSomethingToTheScreen
  PathHasLiterallyAnythingAfterAClose
}

pub fn path(from commands: List(PathCommand)) -> Result(Path, PathError) {
  case parse_path(commands) {
    Ok(path) -> Ok(path)
    Error(err) -> Error(err)
  }
}

fn parse_path(path: List(PathCommand)) -> Result(Path, PathError) {
  let length = list.length(path)
  case path {
    _ if length == 1 -> Error(PathTooShort)
    [] -> Error(PathEmpty)
    [Close, ..] | [Line(_), ..] -> Error(PathMustStartWithMove)
    _ -> Ok(Path(path))
  }
}

// pub fn transform_pathcommand( command: PathCommand, transform: Transform ) -> PathCommand {
//   case command {
//     Move(to) -> Move(vector.transform(to, transform))
//     Line(to) -> Line(vector.transform(to, transform))
//     Close -> Close
//   }
// }

pub type Style {
  Style(color: String, stroke: Float, fill: Bool)
}

pub fn style_to_string(style: Style) -> String {
  let fill = case style.fill {
    True -> "filled"
    False -> ""
  }
  style.color
  <> " "
  <> float.to_string(float.to_precision(style.stroke, 2))
  <> "px "
  <> fill
}
