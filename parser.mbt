///|
pub fn parse_deck_toml(source : String) -> Deck raise {
  match @toml.parse(source) {
    @toml.TomlTable(table) => parse_deck_table(table)
    _ => fail("deck: expected top-level table")
  }
}

///|
pub fn parse_page_toml(source : String) -> Page raise {
  match @toml.parse(source) {
    @toml.TomlTable(table) => parse_page_table(table)
    _ => fail("page: expected top-level table")
  }
}

///|
fn parse_deck_table(table : Map[String, @toml.TomlValue]) -> Deck raise {
  Deck::{
    title: required_string(table, "title"),
    size: parse_size(required_array(table, "size"), "size"),
    theme: parse_theme(required_table(table, "theme"), "theme"),
    pages: parse_page_refs(required_array(table, "pages"), "pages"),
    output: parse_optional_output(table.get("output"), "output"),
  }
}

///|
fn parse_page_table(table : Map[String, @toml.TomlValue]) -> Page raise {
  Page::{
    page_type: parse_page_type(required_string(table, "page_type")),
    background: parse_optional_background(table.get("background"), "background"),
    elements: parse_elements(required_array(table, "elements"), "elements"),
  }
}

///|
fn parse_theme(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Theme raise {
  Theme::{
    colors: parse_string_map(required_table(table, "colors"), "\{path}.colors"),
    text_styles: parse_text_styles(
      required_table(table, "text_styles"),
      "\{path}.text_styles",
    ),
    table_styles: parse_table_styles(
      table.get("table_styles"),
      "\{path}.table_styles",
    ),
  }
}

///|
fn parse_string_map(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Map[String, String] raise {
  let result = Map([], capacity=table.length())
  for key, value in table {
    match value {
      @toml.TomlString(text) => result[key] = text
      _ => fail("\{path}.\{key}: expected string")
    }
  }
  result
}

///|
fn parse_text_styles(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Map[String, TextStyle] raise {
  let result = Map([], capacity=table.length())
  for name, value in table {
    let style_path = "\{path}.\{name}"
    let style_table = expect_table(value, style_path)
    result[name] = TextStyle::{
      font_size: optional_int(
        style_table.get("font_size"),
        "\{style_path}.font_size",
      ),
      font_family: optional_string(
        style_table.get("font_family"),
        "\{style_path}.font_family",
      ),
      color: optional_string(style_table.get("color"), "\{style_path}.color"),
      line_height: optional_double(
        style_table.get("line_height"),
        "\{style_path}.line_height",
      ),
      letter_spacing: optional_int(
        style_table.get("letter_spacing"),
        "\{style_path}.letter_spacing",
      ),
    }
  }
  result
}

///|
fn parse_table_styles(
  value : @toml.TomlValue?,
  path : String,
) -> Map[String, TableStyle] raise {
  match value {
    None => Map([], capacity=0)
    Some(value) => {
      let table = expect_table(value, path)
      let result = Map([], capacity=table.length())
      for name, style_value in table {
        let style_path = "\{path}.\{name}"
        let style_table = expect_table(style_value, style_path)
        result[name] = TableStyle::{
          font_size: optional_int(
            style_table.get("font_size"),
            "\{style_path}.font_size",
          ),
          font_family: optional_string(
            style_table.get("font_family"),
            "\{style_path}.font_family",
          ),
          header_fill: optional_string(
            style_table.get("header_fill"),
            "\{style_path}.header_fill",
          ),
          header_color: optional_string(
            style_table.get("header_color"),
            "\{style_path}.header_color",
          ),
          body_color: optional_string(
            style_table.get("body_color"),
            "\{style_path}.body_color",
          ),
          border: parse_optional_border(
            style_table.get("border"),
            "\{style_path}.border",
          ),
        }
      }
      result
    }
  }
}

///|
fn parse_page_refs(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[PageRef] raise {
  let refs = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    let table = expect_table(value, item_path)
    refs.push(PageRef::{
      path: required_string(table, "\{item_path}.path", key="path"),
    })
  }
  refs
}

///|
fn parse_optional_output(
  value : @toml.TomlValue?,
  path : String,
) -> Output? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      Some(Output::{ path: required_string(table, "\{path}.path", key="path") })
    }
  }
}

///|
fn parse_optional_background(
  value : @toml.TomlValue?,
  path : String,
) -> Background? raise {
  match value {
    None => None
    Some(value) => Some(parse_background_table(expect_table(value, path), path))
  }
}

///|
fn parse_background_table(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Background raise {
  match required_string(table, "\{path}.type", key="type") {
    "solid" =>
      SolidBackground(required_string(table, "\{path}.color", key="color"))
    "image" =>
      ImageBackground(ImageFill::{
        path: required_string(table, "\{path}.path", key="path"),
        fit: parse_image_fit(optional_string(table.get("fit"), "\{path}.fit")),
      })
    "gradient" => GradientBackground(parse_gradient(table, path))
    kind => fail("\{path}.type: unsupported background type '\{kind}'")
  }
}

///|
fn parse_gradient(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Gradient raise {
  let kind = match
    optional_string(table.get("gradient_type"), "\{path}.gradient_type") {
    None => LinearGradient
    Some("linear") => LinearGradient
    Some("radial") => RadialGradient
    Some(value) => CustomGradient(value)
  }
  Gradient::{
    kind,
    angle: optional_double(table.get("angle"), "\{path}.angle"),
    stops: parse_gradient_stops(
      required_array(table, "\{path}.stops", key="stops"),
      "\{path}.stops",
    ),
  }
}

///|
fn parse_gradient_stops(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[GradientStop] raise {
  let stops = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    let table = expect_table(value, item_path)
    stops.push(GradientStop::{
      position: required_double(table, "\{item_path}.position", key="position"),
      color: required_string(table, "\{item_path}.color", key="color"),
    })
  }
  stops
}

///|
fn parse_elements(
  values : Array[@toml.TomlValue],
  path : String,
) -> Array[Element] raise {
  let elements = []
  for index, value in values {
    let item_path = "\{path}[\{index}]"
    elements.push(
      parse_element_table(expect_table(value, item_path), item_path),
    )
  }
  elements
}

///|
fn parse_element_table(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> Element raise {
  let base = ElementBase::{
    id: required_string(table, "\{path}.id", key="id"),
    bounds: parse_bounds(
      required_array(table, "\{path}.bounds", key="bounds"),
      "\{path}.bounds",
    ),
  }
  match required_string(table, "\{path}.type", key="type") {
    "text" =>
      TextElement(
        base,
        parse_text_content(
          required_table(table, "\{path}.content", key="content"),
          "\{path}.content",
        ),
      )
    "shape" => ShapeElement(base, parse_shape_spec(table, path))
    "image" => ImageElement(base, parse_image_spec(table, path))
    "icon" => IconElement(base, parse_icon_spec(table, path))
    "table" => TableElement(base)
    "chart" => ChartElement(base)
    kind => CustomElement(base, kind)
  }
}

///|
fn parse_text_content(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> TextContent raise {
  TextContent::{
    text: required_string(table, "\{path}.text", key="text"),
    style: optional_string(table.get("style"), "\{path}.style"),
    align: parse_optional_align(table.get("align"), "\{path}.align"),
    wrap: optional_bool(table.get("wrap"), "\{path}.wrap"),
    font_size: optional_int(table.get("font_size"), "\{path}.font_size"),
    font_family: optional_string(
      table.get("font_family"),
      "\{path}.font_family",
    ),
    color: optional_string(table.get("color"), "\{path}.color"),
  }
}

///|
fn parse_shape_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ShapeSpec raise {
  ShapeSpec::{
    shape_name: required_string(table, "\{path}.shape_name", key="shape_name"),
    fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
    border: parse_optional_border(table.get("border"), "\{path}.border"),
  }
}

///|
fn parse_image_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> ImageSpec raise {
  ImageSpec::{
    path: required_string(table, "\{path}.path", key="path"),
    fit: parse_image_fit(optional_string(table.get("fit"), "\{path}.fit")),
  }
}

///|
fn parse_icon_spec(
  table : Map[String, @toml.TomlValue],
  path : String,
) -> IconSpec raise {
  IconSpec::{
    name: required_string(table, "\{path}.name", key="name"),
    fill: parse_optional_fill(table.get("fill"), "\{path}.fill"),
  }
}

///|
fn parse_optional_align(
  value : @toml.TomlValue?,
  path : String,
) -> Align? raise {
  match value {
    None => None
    Some(
      @toml.TomlArray(
        [@toml.TomlString(horizontal), @toml.TomlString(vertical)]
      )
    ) => Some(Align::{ horizontal, vertical })
    Some(_) => fail("\{path}: expected [horizontal, vertical]")
  }
}

///|
fn parse_optional_fill(value : @toml.TomlValue?, path : String) -> Fill? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      match required_string(table, "\{path}.type", key="type") {
        "solid" =>
          Some(SolidFill(required_string(table, "\{path}.color", key="color")))
        "gradient" => Some(GradientFill(parse_gradient(table, path)))
        "none" => Some(NoFill)
        kind => fail("\{path}.type: unsupported fill type '\{kind}'")
      }
    }
  }
}

///|
fn parse_optional_border(
  value : @toml.TomlValue?,
  path : String,
) -> Border? raise {
  match value {
    None => None
    Some(value) => {
      let table = expect_table(value, path)
      Some(Border::{
        style: required_string(table, "\{path}.style", key="style"),
        width: required_double(table, "\{path}.width", key="width"),
        color: required_string(table, "\{path}.color", key="color"),
      })
    }
  }
}

///|
fn parse_page_type(value : String) -> PageType {
  match value {
    "cover" => Cover
    "content" => Content
    "section" => Section
    "closing" => Closing
    other => CustomPageType(other)
  }
}

///|
fn parse_image_fit(value : String?) -> ImageFit {
  match value {
    None => CoverFit
    Some("cover") => CoverFit
    Some("contain") => ContainFit
    Some("stretch") => StretchFit
    Some(other) => CustomImageFit(other)
  }
}

///|
fn parse_size(values : Array[@toml.TomlValue], path : String) -> Size raise {
  guard values.length() == 2 else { fail("\{path}: expected [width, height]") }
  Size::{
    width: expect_int(values[0], "\{path}[0]"),
    height: expect_int(values[1], "\{path}[1]"),
  }
}

///|
fn parse_bounds(values : Array[@toml.TomlValue], path : String) -> Bounds raise {
  guard values.length() == 4 else {
    fail("\{path}: expected [x, y, width, height]")
  }
  Bounds::{
    x: expect_int(values[0], "\{path}[0]"),
    y: expect_int(values[1], "\{path}[1]"),
    width: expect_int(values[2], "\{path}[2]"),
    height: expect_int(values[3], "\{path}[3]"),
  }
}

///|
fn required_string(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> String raise {
  match table.get(key) {
    Some(value) => expect_string(value, path)
    None => fail("\{path}: missing required string")
  }
}

///|
fn required_double(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Double raise {
  match table.get(key) {
    Some(value) => expect_double(value, path)
    None => fail("\{path}: missing required number")
  }
}

///|
fn required_array(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Array[@toml.TomlValue] raise {
  match table.get(key) {
    Some(@toml.TomlArray(values)) => values
    Some(_) => fail("\{path}: expected array")
    None => fail("\{path}: missing required array")
  }
}

///|
fn required_table(
  table : Map[String, @toml.TomlValue],
  path : String,
  key? : String = path,
) -> Map[String, @toml.TomlValue] raise {
  match table.get(key) {
    Some(value) => expect_table(value, path)
    None => fail("\{path}: missing required table")
  }
}

///|
fn optional_string(value : @toml.TomlValue?, path : String) -> String? raise {
  match value {
    None => None
    Some(value) => Some(expect_string(value, path))
  }
}

///|
fn optional_int(value : @toml.TomlValue?, path : String) -> Int? raise {
  match value {
    None => None
    Some(value) => Some(expect_int(value, path))
  }
}

///|
fn optional_double(value : @toml.TomlValue?, path : String) -> Double? raise {
  match value {
    None => None
    Some(value) => Some(expect_double(value, path))
  }
}

///|
fn optional_bool(value : @toml.TomlValue?, path : String) -> Bool? raise {
  match value {
    None => None
    Some(@toml.TomlBoolean(value)) => Some(value)
    Some(_) => fail("\{path}: expected boolean")
  }
}

///|
fn expect_string(value : @toml.TomlValue, path : String) -> String raise {
  match value {
    @toml.TomlString(text) => text
    _ => fail("\{path}: expected string")
  }
}

///|
fn expect_int(value : @toml.TomlValue, path : String) -> Int raise {
  match value {
    @toml.TomlInteger(number) => number.to_int()
    _ => fail("\{path}: expected integer")
  }
}

///|
fn expect_double(value : @toml.TomlValue, path : String) -> Double raise {
  match value {
    @toml.TomlInteger(number) => number.to_double()
    @toml.TomlFloat(number) => number
    _ => fail("\{path}: expected number")
  }
}

///|
fn expect_table(
  value : @toml.TomlValue,
  path : String,
) -> Map[String, @toml.TomlValue] raise {
  match value {
    @toml.TomlTable(table) => table
    _ => fail("\{path}: expected table")
  }
}
