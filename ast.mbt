// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
pub(all) struct Size {
  width : Double
  height : Double
} derive(Eq, Debug)

///|
pub(all) struct Deck {
  title : String?
  size : Size
  theme : Theme?
  pages : Array[PageRef]
} derive(Eq, Debug)

///|
pub(all) struct PageRef {
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
  extends : String?
  font_size : Double?
  font_family : String?
  color : String?
  bold : Bool?
  italic : Bool?
  line_height : Double?
  letter_spacing : Double?
} derive(Eq, Debug)

///|
pub(all) struct TableStyle {
  extends : String?
  font_size : Double?
  font_family : String?
  header_fill : String?
  header_text_color : String?
  body_text_color : String?
  header_color : String?
  body_color : String?
  border : Border?
} derive(Eq, Debug)

///|
pub(all) struct Page {
  page_type : String?
  background : Background?
  elements : Array[Element]
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
} derive(Eq, Debug)

///|
pub(all) struct Gradient {
  direction : Double?
  stops : Array[GradientStop]
} derive(Eq, Debug)

///|
pub(all) struct GradientStop {
  at : Double
  color : String
} derive(Eq, Debug)

///|
pub(all) enum Element {
  TextElement(ElementBase, TextContent)
  ShapeElement(ElementBase, ShapeSpec)
  ImageElement(ElementBase, ImageSpec)
  ConnectorElement(String, ConnectorSpec)
  IconElement(ElementBase, IconSpec)
  TableElement(ElementBase, TableSpec)
  ChartElement(ElementBase, ChartSpec)
} derive(Eq, Debug)

///|
pub(all) struct ElementBase {
  id : String
  bounds : Bounds
} derive(Eq, Debug)

///|
pub(all) struct Bounds {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
pub(all) struct TextContent {
  text : String
  style : String?
  align : Align?
  wrap : Bool?
  body : TextBodyOptions?
  paragraphs : Array[TextParagraphSpec]?
  font_size : Double?
  font_family : String?
  color : String?
  bold : Bool?
  italic : Bool?
} derive(Eq, Debug)

///|
pub(all) struct TextBodyOptions {
  inset : TextInset?
  auto_fit : String?
} derive(Eq, Debug)

///|
pub(all) struct TextInset {
  left : Double?
  right : Double?
  top : Double?
  bottom : Double?
} derive(Eq, Debug)

///|
pub(all) struct TextParagraphSpec {
  text : String?
  runs : Array[TextRunSpec]?
  style : String?
  align : Align?
  line_height : Double?
  space_before : Double?
  space_after : Double?
  margin_left : Double?
  indent : Double?
  bullet : BulletSpec?
} derive(Eq, Debug)

///|
pub(all) struct TextRunSpec {
  text : String
  style : String?
  font_size : Double?
  font_family : String?
  color : String?
  bold : Bool?
  italic : Bool?
  hyperlink : String?
  tooltip : String?
} derive(Eq, Debug)

///|
pub(all) struct BulletSpec {
  kind : String
  char : String?
  start : Int?
} derive(Eq, Debug)

///|
pub(all) struct Align {
  horizontal : String
  vertical : String
} derive(Eq, Debug)

///|
pub(all) struct ShapeSpec {
  shape : String
  fill : Fill?
  border : Border?
  shadow : ShadowSpec?
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
pub(all) struct ShadowSpec {
  color : String
  blur : Double
  distance : Double
  direction : Double
} derive(Eq, Debug)

///|
pub(all) struct ImageSpec {
  path : String
  fit : ImageFit
  crop : CropRect?
} derive(Eq, Debug)

///|
pub(all) struct ConnectorSpec {
  kind : String
  start : ConnectorEndpoint
  end : ConnectorEndpoint
  stroke : Border?
  start_arrow : String?
  end_arrow : String?
  shadow : ShadowSpec?
} derive(Eq, Debug)

///|
pub(all) enum ConnectorEndpoint {
  CoordinateEndpoint(Double, Double)
  ElementEndpoint(String)
} derive(Eq, Debug)

///|
pub(all) struct CropRect {
  left : Double
  top : Double
  right : Double
  bottom : Double
} derive(Eq, Debug)

///|
pub(all) struct IconSpec {
  name : String
  fill : Fill?
} derive(Eq, Debug)

///|
pub(all) struct TableSpec {
  style : String?
  col_widths : Array[Double]?
  row_heights : Array[Double]?
  rows : Array[TableRowSpec]
} derive(Eq, Debug)

///|
pub(all) struct TableRowSpec {
  cells : Array[TableCellSpec]
} derive(Eq, Debug)

///|
pub(all) struct TableCellSpec {
  text : String
  fill : Fill?
  border : Border?
  col_span : Int
  row_span : Int
  align : Align?
  margin : TableCellMargin?
} derive(Eq, Debug)

///|
pub(all) struct TableCellMargin {
  left : Double?
  right : Double?
  top : Double?
  bottom : Double?
} derive(Eq, Debug)

///|
pub(all) struct ChartSpec {
  kind : String
  title : String?
  legend : String?
  style : Int?
  data_labels : String?
  data_table : Bool?
  rounded_corners : Bool?
  categories : Array[String]?
  series : Array[ChartSeriesSpec]
} derive(Eq, Debug)

///|
pub(all) struct ChartSeriesSpec {
  name : String
  values : Array[Double]
  x_values : Array[Double]?
  bubble_sizes : Array[Double]?
} derive(Eq, Debug)
