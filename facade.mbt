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
pub using @diagnostic {type Diagnostic, type Severity}

///|
pub using @loader {
  type DeckBundle,
  type LoadError,
  type LoadedDeck,
  type ResolvedPage,
}

///|
pub using @model {
  type Align,
  type Background,
  type Border,
  type Bounds,
  type BulletSpec,
  type ChartSeriesSpec,
  type ChartSpec,
  type ChartStyle,
  type ComponentInstance,
  type ComponentTemplate,
  type ConnectorAnchor,
  type ConnectorEndpoint,
  type ConnectorSpec,
  type CropRect,
  type Deck,
  type Element,
  type ElementBase,
  type Fill,
  type Gradient,
  type GradientStop,
  type IconSpec,
  type ImageFill,
  type ImageFit,
  type ImageSpec,
  type LayoutSlot,
  type LayoutTemplate,
  type Page,
  type PageRef,
  type ShadowSpec,
  type ShapeSpec,
  type Size,
  type TableCellMargin,
  type TableCellSpec,
  type TableRowSpec,
  type TableSpec,
  type TableStyle,
  type TextBodyOptions,
  type TextContent,
  type TextInset,
  type TextParagraphSpec,
  type TextRunSpec,
  type TextStyle,
  type Theme,
}

///|
pub using @writer {type WriteError}

///|
pub fn load_deck(input_path : String) -> LoadedDeck raise {
  @loader.load_deck(input_path)
}

///|
pub fn parse_deck_yaml(source : String) -> Deck raise {
  @parser.parse_deck_yaml(source)
}

///|
pub fn parse_page_yaml(source : String) -> Page raise {
  @parser.parse_page_yaml(source)
}

///|
pub fn render_pptx(loaded : LoadedDeck) -> FixedArray[Byte] raise {
  @writer.render_pptx(loaded)
}

///|
pub fn write_pptx_file(loaded : LoadedDeck, output_path : String) -> Unit raise {
  @writer.write_pptx_file(loaded, output_path)
}
