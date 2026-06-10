///|
pub(all) struct Size {
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub(all) struct Deck {
  title : String
  size : Size
  theme : Theme
  pages : Array[PageRef]
  output : Output?
} derive(Eq, Debug)

///|
pub(all) struct PageRef {
  path : String
} derive(Eq, Debug)

///|
pub(all) struct Output {
  path : String
} derive(Eq, Debug)

///|
pub(all) struct Theme {
  colors : Map[String, String]
  text_styles : Map[String, TextStyle]
  table_styles : Map[String, TableStyle]
} derive(Eq, Debug)

///|
pub(all) struct TextStyle {
  font_size : Int?
  font_family : String?
  color : String?
  line_height : Double?
  letter_spacing : Int?
} derive(Eq, Debug)

///|
pub(all) struct TableStyle {
  font_size : Int?
  font_family : String?
  header_fill : String?
  header_color : String?
  body_color : String?
  border : Border?
} derive(Eq, Debug)

///|
pub(all) struct Page {
  page_type : PageType
  background : Background?
  elements : Array[Element]
} derive(Eq, Debug)

///|
pub(all) enum PageType {
  Cover
  Content
  Section
  Closing
  CustomPageType(String)
} derive(Eq, Debug)

///|
pub(all) enum Background {
  SolidBackground(String)
  GradientBackground(Gradient)
  ImageBackground(ImageFill)
} derive(Eq, Debug)

///|
pub(all) struct ImageFill {
  path : String
  fit : ImageFit
} derive(Eq, Debug)

///|
pub(all) enum ImageFit {
  CoverFit
  ContainFit
  StretchFit
  CustomImageFit(String)
} derive(Eq, Debug)

///|
pub(all) struct Gradient {
  kind : GradientKind
  angle : Double?
  stops : Array[GradientStop]
} derive(Eq, Debug)

///|
pub(all) enum GradientKind {
  LinearGradient
  RadialGradient
  CustomGradient(String)
} derive(Eq, Debug)

///|
pub(all) struct GradientStop {
  position : Double
  color : String
} derive(Eq, Debug)

///|
pub(all) enum Element {
  TextElement(ElementBase, TextContent)
  ShapeElement(ElementBase, ShapeSpec)
  ImageElement(ElementBase, ImageSpec)
  IconElement(ElementBase, IconSpec)
  TableElement(ElementBase)
  ChartElement(ElementBase)
  CustomElement(ElementBase, String)
} derive(Eq, Debug)

///|
pub(all) struct ElementBase {
  id : String
  bounds : Bounds
} derive(Eq, Debug)

///|
pub(all) struct Bounds {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub(all) struct TextContent {
  text : String
  style : String?
  align : Align?
  wrap : Bool?
  font_size : Int?
  font_family : String?
  color : String?
} derive(Eq, Debug)

///|
pub(all) struct Align {
  horizontal : String
  vertical : String
} derive(Eq, Debug)

///|
pub(all) struct ShapeSpec {
  shape_name : String
  fill : Fill?
  border : Border?
} derive(Eq, Debug)

///|
pub(all) enum Fill {
  SolidFill(String)
  GradientFill(Gradient)
  NoFill
} derive(Eq, Debug)

///|
pub(all) struct Border {
  style : String
  width : Double
  color : String
} derive(Eq, Debug)

///|
pub(all) struct ImageSpec {
  path : String
  fit : ImageFit
} derive(Eq, Debug)

///|
pub(all) struct IconSpec {
  name : String
  fill : Fill?
} derive(Eq, Debug)
