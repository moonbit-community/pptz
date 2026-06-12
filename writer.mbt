///|
pub(all) suberror WriteError {
  Capability(String)
  Backend(String)
  Io(String)
} derive(Debug)

///|
pub fn render_pptx(loaded : LoadedDeck) -> FixedArray[Byte] raise {
  let prs = @presentation.Presentation::new() catch {
    err => raise WriteError::Backend("cannot create presentation: \{err}")
  }
  prs.set_slide_size_mut(
    Custom(
      to_emu(loaded.bundle.deck.size.width),
      to_emu(loaded.bundle.deck.size.height),
    ),
  ) catch {
    err => raise WriteError::Backend("cannot set slide size: \{err}")
  }
  for index, resolved_page in loaded.bundle.pages {
    render_page_mut(prs, index, loaded.bundle, resolved_page)
  }
  prs.save()
}

///|
fn render_page_mut(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
) -> Unit raise {
  let _ = prs.add_blank_typed_slide_mut().finish_mut() catch {
      err => raise WriteError::Backend("cannot add slide: \{err}")
    }
  add_page_background_image(prs, slide_index, bundle, resolved_page)
  let initial_slide = current_slide(prs, slide_index)
  let slide = build_slide(bundle, resolved_page, initial_slide) catch {
    err => raise err
  }
  prs.update_slide_mut(slide_index, slide) catch {
    err =>
      raise WriteError::Backend("cannot update slide \{slide_index}: \{err}")
  }
  add_page_charts(prs, slide_index, bundle, resolved_page)
  add_page_images(prs, slide_index, bundle, resolved_page)
}

///|
pub fn write_pptx_file(loaded : LoadedDeck, output_path : String) -> Unit raise {
  if output_path.is_blank() {
    raise WriteError::Io("output path must not be empty")
  }
  ensure_parent_dir(output_path)
  let bytes = render_pptx(loaded)
  let temp_path = output_temp_path(output_path)
  @miniio.write_file(
    temp_path,
    Bytes::from_array(bytes[:]),
    create_mode=CreateNew,
  ) catch {
    err =>
      raise WriteError::Io(
        "cannot write temporary output '\{temp_path}': \{err}",
      )
  }
  @miniio.copy_file(temp_path, output_path, create_mode=CreateOrTruncate) catch {
    err => {
      remove_temp_file(temp_path)
      raise WriteError::Io("cannot write output '\{output_path}': \{err}")
    }
  }
  remove_temp_file(temp_path)
}

///|
fn build_slide(
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
  initial_slide : @slide.Slide,
) -> @slide.Slide raise {
  let mut slide = initial_slide
  match resolved_page.page.background {
    None => ()
    Some(SolidBackground(color)) =>
      slide = slide.with_background(SolidFill(resolve_color(bundle, color)))
    Some(GradientBackground(gradient)) =>
      slide = slide.with_background(to_gradient_fill(bundle, gradient))
    Some(ImageBackground(_)) => ()
  }
  let shape_ids = connector_shape_ids(
    slide.shapes.length() + 2,
    resolved_page.page.elements,
  )
  let shape_bounds = connector_shape_bounds(resolved_page.page.elements)
  for element in resolved_page.page.elements {
    match element {
      ImageElement(_, _) | ChartElement(_, _) => ()
      _ => {
        let shape = build_shape(bundle, element, shape_ids, shape_bounds)
        slide = slide.with_shape(shape)
      }
    }
  }
  slide
}

///|
fn connector_shape_ids(
  first_shape_id : Int,
  elements : Array[Element],
) -> Map[String, Int] {
  let result = Map([], capacity=elements.length())
  let mut shape_id = first_shape_id
  for element in elements {
    match element {
      ImageElement(_, _) | ChartElement(_, _) => ()
      _ => {
        result[element_id(element)] = shape_id
        shape_id += 1
      }
    }
  }
  result
}

///|
fn connector_shape_bounds(elements : Array[Element]) -> Map[String, Bounds] {
  let result = Map([], capacity=elements.length())
  for element in elements {
    match element {
      TextElement(base, _) | ShapeElement(base, _) | IconElement(base, _) =>
        result[base.id] = base.bounds
      _ => ()
    }
  }
  result
}

///|
fn add_page_background_image(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
) -> Unit raise {
  match resolved_page.page.background {
    Some(ImageBackground(fill)) =>
      add_image_fill(prs, slide_index, bundle, fill.path, fill.fit, None, Bounds::{
        x: 0.0,
        y: 0.0,
        width: bundle.deck.size.width,
        height: bundle.deck.size.height,
      })
    _ => ()
  }
}

///|
fn add_page_images(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
) -> Unit raise {
  for element in resolved_page.page.elements {
    match element {
      ImageElement(base, spec) =>
        add_image(prs, slide_index, bundle, base, spec)
      _ => ()
    }
  }
}

///|
fn add_page_charts(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
) -> Unit raise {
  for element in resolved_page.page.elements {
    match element {
      ChartElement(base, spec) =>
        add_chart(prs, slide_index, bundle, base, spec)
      _ => ()
    }
  }
}

///|
fn add_chart(
  prs : @presentation.Presentation,
  slide_index : Int,
  _bundle : DeckBundle,
  base : ElementBase,
  spec : ChartSpec,
) -> Unit raise {
  let bounds = base.bounds
  prs.add_chart_mut(
    slide_index,
    chart_from_spec(spec),
    to_emu(bounds.x),
    to_emu(bounds.y),
    to_emu(bounds.width),
    to_emu(bounds.height),
  ) catch {
    err => raise WriteError::Backend("cannot add chart '\{base.id}': \{err}")
  }
}

///|
fn chart_from_spec(spec : ChartSpec) -> @chart.Chart raise {
  let chart = match spec.kind {
    "bar" => @chart.Chart::of_bar(chart_data(spec))
    "line" => @chart.Chart::of_line(chart_data(spec))
    "pie" => @chart.Chart::of_pie(chart_data(spec))
    "doughnut" => @chart.Chart::of_doughnut(chart_data(spec))
    "area" => @chart.Chart::of_area(chart_data(spec))
    "radar" => @chart.Chart::of_radar(chart_data(spec))
    "scatter" => @chart.Chart::of_scatter(scatter_data(spec))
    "bubble" => @chart.Chart::of_bubble(bubble_data(spec))
    other =>
      raise WriteError::Capability("chart kind '\{other}' is not implemented")
  }
  chart.with_options(chart_options(spec))
}

///|
fn chart_options(spec : ChartSpec) -> Array[@chart.ChartOption] raise {
  let options = []
  match spec.title {
    None => ()
    Some(title) => options.push(@chart.ChartOption::Title(title))
  }
  match spec.legend {
    None => ()
    Some("hidden") => options.push(@chart.ChartOption::LegendHidden)
    Some(legend) =>
      options.push(@chart.ChartOption::Legend(chart_legend_pos(legend)))
  }
  match spec.style {
    None => ()
    Some(style) => options.push(@chart.ChartOption::Style(style))
  }
  match spec.data_labels {
    None => ()
    Some("hidden") => options.push(@chart.ChartOption::DataLabelsHidden)
    Some(pos) =>
      options.push(@chart.ChartOption::DataLabels(chart_data_label_pos(pos)))
  }
  match spec.data_table {
    None => ()
    Some(show) => options.push(@chart.ChartOption::DataTable(show))
  }
  match spec.rounded_corners {
    None => ()
    Some(value) => options.push(@chart.ChartOption::RoundedCorners(value))
  }
  options
}

///|
fn chart_legend_pos(value : String) -> @chart.LegendPos raise {
  match value {
    "bottom" => @chart.LegendPos::LegendBottom
    "top_right" => @chart.LegendPos::LegendTopRight
    "left" => @chart.LegendPos::LegendLeft
    "right" => @chart.LegendPos::LegendRight
    "top" => @chart.LegendPos::LegendTop
    other =>
      raise WriteError::Capability("chart legend '\{other}' is not implemented")
  }
}

///|
fn chart_data_label_pos(value : String) -> @chart.DLblPos raise {
  match value {
    "best_fit" => @chart.DLblPos::DLblBestFit
    "bottom" => @chart.DLblPos::DLblBottom
    "center" => @chart.DLblPos::DLblCenter
    "inside_base" => @chart.DLblPos::DLblInBase
    "inside_end" => @chart.DLblPos::DLblInEnd
    "left" => @chart.DLblPos::DLblLeft
    "outside_end" => @chart.DLblPos::DLblOutEnd
    "right" => @chart.DLblPos::DLblRight
    "top" => @chart.DLblPos::DLblTop
    other =>
      raise WriteError::Capability(
        "chart data_labels '\{other}' is not implemented",
      )
  }
}

///|
fn chart_data(spec : ChartSpec) -> @chart.ChartData raise {
  let mut data = @chart.ChartData::new()
  match spec.categories {
    Some(categories) =>
      for category in categories {
        data = data.with_category(category)
      }
    None =>
      raise WriteError::Capability(
        "chart categories are required for kind '\{spec.kind}'",
      )
  }
  for series in spec.series {
    data = data.with_series(series.name, series.values)
  }
  data.validate() catch {
    err => raise WriteError::Backend("invalid chart data: \{err}")
  }
}

///|
fn scatter_data(spec : ChartSpec) -> @chart.ScatterData raise {
  let mut data = @chart.ScatterData::new()
  for series in spec.series {
    data = data.with_series(
      series.name,
      required_chart_values(series.x_values, spec.kind, "x_values"),
      series.values,
    )
  }
  data.validate() catch {
    err => raise WriteError::Backend("invalid scatter chart data: \{err}")
  }
}

///|
fn bubble_data(spec : ChartSpec) -> @chart.BubbleData raise {
  let mut data = @chart.BubbleData::new()
  for series in spec.series {
    data = data.with_series(
      series.name,
      required_chart_values(series.x_values, spec.kind, "x_values"),
      series.values,
      required_chart_values(series.bubble_sizes, spec.kind, "bubble_sizes"),
    )
  }
  data.validate() catch {
    err => raise WriteError::Backend("invalid bubble chart data: \{err}")
  }
}

///|
fn required_chart_values(
  values : Array[Double]?,
  kind : String,
  field : String,
) -> Array[Double] raise {
  match values {
    Some(values) => values
    None =>
      raise WriteError::Capability("chart kind '\{kind}' requires \{field}")
  }
}

///|
fn build_shape(
  bundle : DeckBundle,
  element : Element,
  shape_ids : Map[String, Int],
  shape_bounds : Map[String, Bounds],
) -> @slide.Shape raise {
  match element {
    TextElement(base, content) =>
      @slide.AutoShape(
        build_textbox(
          bundle,
          base,
          content,
          require_shape_id(shape_ids, base.id),
        ),
      )
    ShapeElement(base, spec) =>
      @slide.AutoShape(
        build_auto_shape(
          bundle,
          base,
          spec,
          require_shape_id(shape_ids, base.id),
        ),
      )
    ConnectorElement(id, spec) =>
      @slide.Connector(
        build_connector(
          bundle,
          id,
          spec,
          require_shape_id(shape_ids, id),
          shape_ids,
          shape_bounds,
        ),
      )
    ImageElement(_, _) =>
      raise WriteError::Capability("internal image dispatch error")
    IconElement(base, spec) =>
      @slide.AutoShape(
        build_icon_shape(
          bundle,
          base,
          spec,
          require_shape_id(shape_ids, base.id),
        ),
      )
    TableElement(base, spec) =>
      @slide.GraphicFrame(
        build_table_frame(
          bundle,
          base,
          spec,
          require_shape_id(shape_ids, base.id),
        ),
      )
    ChartElement(_, _) =>
      raise WriteError::Capability("internal chart dispatch error")
  }
}

///|
fn require_shape_id(shape_ids : Map[String, Int], id : String) -> Int raise {
  match shape_ids.get(id) {
    Some(shape_id) => shape_id
    None =>
      raise WriteError::Backend("internal error: missing shape id for '\{id}'")
  }
}

///|
fn add_image(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  base : ElementBase,
  spec : ImageSpec,
) -> Unit raise {
  add_image_fill(
    prs,
    slide_index,
    bundle,
    spec.path,
    spec.fit,
    spec.crop,
    base.bounds,
  )
}

///|
fn add_image_fill(
  prs : @presentation.Presentation,
  slide_index : Int,
  bundle : DeckBundle,
  path : String,
  fit : ImageFit,
  crop : CropRect?,
  bounds : Bounds,
) -> Unit raise {
  let full_path = source_full_path(bundle.deck_dir, path).to_string()
  let bytes = @miniio.read_file(full_path) catch {
    err => raise WriteError::Io("cannot read image '\{path}': \{err}")
  }
  let image_bytes = bytes.binary().to_fixedarray()
  let placement = image_placement(
    bounds,
    fit,
    image_source_size(path, image_bytes),
    crop,
  )
  let shape_index = add_picture_shape_mut(
    prs,
    slide_index,
    path,
    image_bytes,
    placement.bounds,
  )
  apply_picture_crop_at(prs, slide_index, shape_index, placement.crop, path)
}

///|
fn add_picture_shape_mut(
  prs : @presentation.Presentation,
  slide_index : Int,
  path : String,
  image_bytes : FixedArray[Byte],
  bounds : Bounds,
) -> Int raise {
  let shape_index = last_shape_index(prs, slide_index) + 1
  if is_svg_path(path) {
    prs.add_svg_picture_mut(
      slide_index,
      image_bytes,
      transparent_png_fallback(),
      to_emu(bounds.x),
      to_emu(bounds.y),
      to_emu(bounds.width),
      to_emu(bounds.height),
    ) catch {
      err => raise WriteError::Backend("cannot add SVG image '\{path}': \{err}")
    }
  } else {
    prs.add_picture_mut(
      slide_index,
      image_bytes,
      to_emu(bounds.x),
      to_emu(bounds.y),
      to_emu(bounds.width),
      to_emu(bounds.height),
    ) catch {
      err => raise WriteError::Backend("cannot add image '\{path}': \{err}")
    }
  }
  shape_index
}

///|
fn apply_picture_crop_at(
  prs : @presentation.Presentation,
  slide_index : Int,
  shape_index : Int,
  crop : CropRect?,
  path : String,
) -> Unit raise {
  match crop {
    None => ()
    Some(crop) => {
      let slides = prs.slides() catch {
        err => raise WriteError::Backend("cannot read slides: \{err}")
      }
      let slide = slides[slide_index]
      let shape = match slide.shapes[shape_index] {
        @slide.Picture(picture) =>
          @slide.Shape::Picture(
            picture.with_crop(
              left=@units.Percentage(crop.left * 100.0),
              top=@units.Percentage(crop.top * 100.0),
              right=@units.Percentage(crop.right * 100.0),
              bottom=@units.Percentage(crop.bottom * 100.0),
            ),
          )
        _ =>
          raise WriteError::Backend(
            "internal error: last shape is not image '\{path}'",
          )
      }
      let slide = slide.with_shape_at(shape_index, shape) catch {
        err =>
          raise WriteError::Backend(
            "cannot apply image crop for '\{path}': \{err}",
          )
      }
      prs.update_slide_mut(slide_index, slide) catch {
        err =>
          raise WriteError::Backend(
            "cannot update cropped image '\{path}': \{err}",
          )
      }
    }
  }
}

///|
fn last_shape_index(
  prs : @presentation.Presentation,
  slide_index : Int,
) -> Int raise {
  let slides = prs.slides() catch {
    err => raise WriteError::Backend("cannot read slides: \{err}")
  }
  slides[slide_index].shapes.length() - 1
}

///|
fn current_slide(
  prs : @presentation.Presentation,
  slide_index : Int,
) -> @slide.Slide raise {
  let slides = prs.slides() catch {
    err => raise WriteError::Backend("cannot read slides: \{err}")
  }
  slides[slide_index]
}

///|
fn transparent_png_fallback() -> FixedArray[Byte] {
  b"\x89PNG\r\n\x1A\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\nIDATx\x9Cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xB4\x00\x00\x00\x00IEND\xAEB`\x82".to_fixedarray()
}

///|
fn build_textbox(
  bundle : DeckBundle,
  base : ElementBase,
  content : TextContent,
  shape_id : Int,
) -> @slide.AutoShape raise {
  let bounds = base.bounds
  let run_props = text_run_properties(bundle, content)
  let mut paragraph = text_paragraph(content.text, run_props)
  match content.align {
    None => ()
    Some(align) =>
      paragraph = paragraph.with_alignment(
        horizontal_alignment(align.horizontal),
      )
  }
  paragraph = paragraph.with_properties(
    text_paragraph_properties(bundle, content, paragraph.properties),
  )
  let mut text_body = @slide.TextBody::of_paragraphs([paragraph])
  let mut body_props = @slide.BodyProperties::default()
  let mut has_body_props = false
  match content.align {
    None => ()
    Some(align) => {
      body_props = @slide.BodyProperties::{
        ..body_props,
        anchor: Some(vertical_anchor(align.vertical)),
      }
      has_body_props = true
    }
  }
  match content.wrap {
    None => ()
    Some(wrap) => {
      body_props = @slide.BodyProperties::{
        ..body_props,
        wrap: Some(
          if wrap {
            @slide.WrapKind::WrapSquare
          } else {
            @slide.WrapKind::WrapNone
          },
        ),
      }
      has_body_props = true
    }
  }
  if has_body_props {
    text_body = @slide.TextBody::{
      ..text_body,
      body_properties: Some(body_props),
    }
  }
  @slide.AutoShape::textbox(
    shape_id,
    base.id,
    to_emu(bounds.x),
    to_emu(bounds.y),
    to_emu(bounds.width),
    to_emu(bounds.height),
    content.text,
  )
  .with_text_body(text_body)
  .with_no_fill()
  .with_no_stroke()
}

///|
fn text_paragraph(
  text : String,
  run_props : @slide.RunProperties,
) -> @slide.Paragraph {
  let paragraph_content = []
  let mut first_line = true
  for part in text.split("\n") {
    if first_line {
      first_line = false
    } else {
      paragraph_content.push(@slide.ParagraphContent::Break(run_props))
    }
    let line = part.to_owned()
    if !line.is_empty() {
      paragraph_content.push(
        @slide.ParagraphContent::RunContent(@slide.Run::{
          text: line,
          properties: run_props,
          extension: [],
        }),
      )
    }
  }
  if paragraph_content.is_empty() {
    paragraph_content.push(
      @slide.ParagraphContent::RunContent(@slide.Run::{
        text,
        properties: run_props,
        extension: [],
      }),
    )
  }
  @slide.Paragraph::{
    content: paragraph_content,
    properties: @slide.ParagraphProperties::default(),
    extension: [],
  }
}

///|
fn build_auto_shape(
  bundle : DeckBundle,
  base : ElementBase,
  spec : ShapeSpec,
  shape_id : Int,
) -> @slide.AutoShape raise {
  let bounds = base.bounds
  let mut shape = build_preset_shape(
    base,
    bounds,
    shape_id,
    preset_shape_from_name(spec.shape),
  )
  match spec.fill {
    None => ()
    Some(NoFill) => shape = shape.with_no_fill()
    Some(SolidFill(color)) =>
      shape = shape.with_fill(SolidFill(resolve_color(bundle, color)))
    Some(GradientFill(gradient)) =>
      shape = shape.with_fill(to_gradient_fill(bundle, gradient))
  }
  match spec.border {
    None => ()
    Some(border) => shape = shape.with_stroke(to_stroke(bundle, border))
  }
  match spec.shadow {
    None => ()
    Some(shadow) =>
      shape = @slide.AutoShape::{
        ..shape,
        effects: Some(to_effect_list(bundle, shadow)),
      }
  }
  shape
}

///|
fn build_icon_shape(
  bundle : DeckBundle,
  base : ElementBase,
  spec : IconSpec,
  shape_id : Int,
) -> @slide.AutoShape raise {
  let bounds = base.bounds
  let mut shape = build_preset_shape(
    base,
    bounds,
    shape_id,
    icon_preset_shape(spec.name),
  )
  shape = shape.with_no_stroke()
  match spec.fill {
    None => shape = shape.with_fill(SolidFill(resolve_color(bundle, "#000000")))
    Some(NoFill) => shape = shape.with_no_fill()
    Some(SolidFill(color)) =>
      shape = shape.with_fill(SolidFill(resolve_color(bundle, color)))
    Some(GradientFill(gradient)) =>
      shape = shape.with_fill(to_gradient_fill(bundle, gradient))
  }
  shape
}

///|
fn build_table_frame(
  bundle : DeckBundle,
  base : ElementBase,
  spec : TableSpec,
  shape_id : Int,
) -> @slide.GraphicFrame raise {
  let bounds = base.bounds
  let table = @slide.Table::of_rows(
    table_rows(bundle, spec, bounds),
    col_widths=table_col_widths(spec, bounds),
  )
  @slide.GraphicFrame::of_table(
    shape_id,
    base.id,
    to_emu(bounds.x),
    to_emu(bounds.y),
    to_emu(bounds.width),
    to_emu(bounds.height),
    table,
  )
}

///|
fn table_rows(
  bundle : DeckBundle,
  spec : TableSpec,
  bounds : Bounds,
) -> Array[@slide.TableRow] raise {
  let row_heights = table_row_heights(spec, bounds)
  let column_count = table_column_count(spec)
  let mut active_counts = zero_int_array(column_count)
  let mut active_horizontal = false_bool_array(column_count)
  let rows = []
  for index, row in spec.rows {
    let (cells, next_counts, next_horizontal) = table_cells(
      bundle,
      row.cells,
      active_counts,
      active_horizontal,
      column_count,
    )
    rows.push(@slide.TableRow::of_cells(cells, height=row_heights[index]))
    active_counts = next_counts
    active_horizontal = next_horizontal
  }
  rows
}

///|
fn table_cells(
  bundle : DeckBundle,
  cells : Array[TableCellSpec],
  active_counts : Array[Int],
  active_horizontal : Array[Bool],
  column_count : Int,
) -> (Array[@slide.TableCell], Array[Int], Array[Bool]) raise {
  let result = []
  let next_counts = zero_int_array(column_count)
  let next_horizontal = false_bool_array(column_count)
  let mut column = 0
  let mut cell_index = 0
  while column < column_count {
    if active_counts[column] > 0 {
      if active_horizontal[column] {
        result.push(@slide.TableCell::hv_merge_covered())
      } else {
        result.push(@slide.TableCell::v_merge_covered())
      }
      next_counts[column] = active_counts[column] - 1
      next_horizontal[column] = active_counts[column] > 1 &&
        active_horizontal[column]
      column += 1
    } else if cell_index < cells.length() {
      let cell = cells[cell_index]
      if column + cell.col_span > column_count {
        raise WriteError::Backend("table row exceeds computed column count")
      }
      for offset in 0..<cell.col_span {
        if active_counts[column + offset] > 0 {
          raise WriteError::Backend("table merge overlaps active row span")
        }
      }
      result.push(table_origin_cell(bundle, cell))
      if cell.row_span > 1 {
        next_counts[column] = cell.row_span - 1
        next_horizontal[column] = false
      }
      for offset in 1..<cell.col_span {
        result.push(@slide.TableCell::h_merge_covered())
        if cell.row_span > 1 {
          next_counts[column + offset] = cell.row_span - 1
          next_horizontal[column + offset] = true
        }
      }
      column += cell.col_span
      cell_index += 1
    } else {
      raise WriteError::Backend("table row does not fill computed column count")
    }
  }
  if cell_index != cells.length() {
    raise WriteError::Backend("table row has unused cells after grid expansion")
  }
  (result, next_counts, next_horizontal)
}

///|
fn table_origin_cell(
  bundle : DeckBundle,
  cell : TableCellSpec,
) -> @slide.TableCell raise {
  let mut table_cell = if cell.col_span == 1 && cell.row_span == 1 {
    @slide.TableCell::of_text(cell.text)
  } else {
    @slide.TableCell::merged_origin(
      cell.text,
      grid_span=cell.col_span,
      row_span=cell.row_span,
    )
  }
  let properties = table_cell_properties(bundle, cell)
  if properties is Some(_) {
    table_cell = @slide.TableCell::{ ..table_cell, properties, }
  }
  table_cell
}

///|
fn table_cell_properties(
  bundle : DeckBundle,
  cell : TableCellSpec,
) -> @slide.TableCellProperties? raise {
  let mut properties = @slide.TableCellProperties::default()
  let mut has_properties = false
  match cell.fill {
    None => ()
    Some(NoFill) => {
      properties = @slide.TableCellProperties::{
        ..properties,
        fill: Some(@oxml.Fill::NoFill),
      }
      has_properties = true
    }
    Some(SolidFill(color)) => {
      properties = properties.with_fill(SolidFill(resolve_color(bundle, color)))
      has_properties = true
    }
    Some(GradientFill(gradient)) => {
      properties = properties.with_fill(to_gradient_fill(bundle, gradient))
      has_properties = true
    }
  }
  match cell.border {
    None => ()
    Some(border) => {
      properties = properties.with_border_all(to_stroke(bundle, border))
      has_properties = true
    }
  }
  match cell.margin {
    None => ()
    Some(margin) => {
      properties = @slide.TableCellProperties::{
        ..properties,
        margin_l: optional_emu(margin.left),
        margin_r: optional_emu(margin.right),
        margin_t: optional_emu(margin.top),
        margin_b: optional_emu(margin.bottom),
      }
      has_properties = true
    }
  }
  match cell.align {
    None => ()
    Some(align) => {
      properties = @slide.TableCellProperties::{
        ..properties,
        anchor: Some(vertical_anchor(align.vertical)),
        anchor_ctr: table_anchor_center(align.horizontal),
      }
      has_properties = true
    }
  }
  if has_properties {
    Some(properties)
  } else {
    None
  }
}

///|
fn table_anchor_center(horizontal : String) -> Bool? raise {
  match horizontal {
    "left" => None
    "center" => Some(true)
    other =>
      raise WriteError::Capability(
        "table cell horizontal alignment '\{other}' is not implemented",
      )
  }
}

///|
fn optional_emu(value : Double?) -> @units.Emu? {
  match value {
    None => None
    Some(value) => Some(to_emu(value))
  }
}

///|
fn table_col_widths(spec : TableSpec, bounds : Bounds) -> Array[@units.Emu] {
  match spec.col_widths {
    Some(widths) => double_array_to_emu(widths)
    None => {
      let column_count = table_column_count(spec)
      equal_emu_array(bounds.width, column_count)
    }
  }
}

///|
fn table_column_count(spec : TableSpec) -> Int {
  match spec.col_widths {
    Some(widths) => widths.length()
    None => {
      let mut count = 0
      for cell in spec.rows[0].cells {
        count += cell.col_span
      }
      count
    }
  }
}

///|
fn table_row_heights(spec : TableSpec, bounds : Bounds) -> Array[@units.Emu] {
  match spec.row_heights {
    Some(heights) => double_array_to_emu(heights)
    None => equal_emu_array(bounds.height, spec.rows.length())
  }
}

///|
fn double_array_to_emu(values : Array[Double]) -> Array[@units.Emu] {
  let result = []
  for value in values {
    result.push(to_emu(value))
  }
  result
}

///|
fn equal_emu_array(total : Double, count : Int) -> Array[@units.Emu] {
  let result = []
  let size = total / count.to_double()
  for _ in 0..<count {
    result.push(to_emu(size))
  }
  result
}

///|
fn zero_int_array(count : Int) -> Array[Int] {
  let result = []
  for _ in 0..<count {
    result.push(0)
  }
  result
}

///|
fn false_bool_array(count : Int) -> Array[Bool] {
  let result = []
  for _ in 0..<count {
    result.push(false)
  }
  result
}

///|
fn icon_preset_shape(name : String) -> @slide.PresetShape raise {
  match icon_local_name(name) {
    "cube" => @slide.PresetShape::Cube
    "circle" => @slide.PresetShape::Ellipse
    "square" => @slide.PresetShape::Rect
    "star" => @slide.PresetShape::Star5
    "heart" => @slide.PresetShape::Heart
    "plus" => @slide.PresetShape::Plus
    "home" => @slide.PresetShape::ActionButtonHome
    "info" => @slide.PresetShape::ActionButtonInformation
    "help" => @slide.PresetShape::ActionButtonHelp
    "return" => @slide.PresetShape::ActionButtonReturn
    "blank" => @slide.PresetShape::ActionButtonBlank
    "smiley" => @slide.PresetShape::SmileyFace
    "sun" => @slide.PresetShape::Sun
    "moon" => @slide.PresetShape::Moon
    "cloud" => @slide.PresetShape::Cloud
    "lightning" => @slide.PresetShape::LightningBolt
    "gear6" => @slide.PresetShape::Gear6
    "gear9" => @slide.PresetShape::Gear9
    "funnel" => @slide.PresetShape::Funnel
    "chart_plus" => @slide.PresetShape::ChartPlus
    "chart_star" => @slide.PresetShape::ChartStar
    "chart_x" => @slide.PresetShape::ChartX
    "no_smoking" => @slide.PresetShape::NoSmoking
    _ =>
      raise WriteError::Capability(
        "icon '\{name}' is not implemented; supported icon names: cube, circle, square, star, heart, plus, home, info, help, return, blank, smiley, sun, moon, cloud, lightning, gear6, gear9, funnel, chart_plus, chart_star, chart_x, no_smoking",
      )
  }
}

///|
fn icon_local_name(name : String) -> String raise {
  if name.is_empty() {
    raise WriteError::Capability("icon name must not be empty")
  }
  let prefix = []
  let local_chars = []
  let mut colon_count = 0
  for char in name {
    if char == ':' {
      colon_count += 1
    } else if colon_count == 0 {
      prefix.push(char)
    } else if colon_count == 1 {
      local_chars.push(char)
    }
  }
  match colon_count {
    0 => name
    1 =>
      if prefix.is_empty() || local_chars.is_empty() {
        raise WriteError::Capability("icon '\{name}' must use prefix:name")
      } else {
        String::from_iter(local_chars.iter())
      }
    _ => raise WriteError::Capability("icon '\{name}' must use prefix:name")
  }
}

///|
fn preset_shape_from_name(name : String) -> @slide.PresetShape raise {
  if is_connector_shape_name(name) {
    raise WriteError::Capability(
      "shape '\{name}' is a connector or line; connector elements are not implemented",
    )
  }
  let xml_name = preset_shape_xml_name(name)
  @slide.PresetShape::from_xml(xml_name) catch {
    _ => raise WriteError::Capability("shape '\{name}' is not implemented")
  }
}

///|
fn is_connector_shape_name(name : String) -> Bool {
  match name {
    "line"
    | "line_inv"
    | "straight_connector1"
    | "bent_connector2"
    | "bent_connector3"
    | "bent_connector4"
    | "bent_connector5"
    | "curved_connector2"
    | "curved_connector3"
    | "curved_connector4"
    | "curved_connector5" => true
    _ => false
  }
}

///|
fn preset_shape_xml_name(name : String) -> String raise {
  if name == "right_triangle" {
    return "rtTriangle"
  }
  if name.is_empty() {
    raise WriteError::Capability("shape name must not be empty")
  }
  let chars = []
  let mut capitalize_next = false
  let mut first = true
  for char in name {
    if char == '_' {
      if first || capitalize_next {
        raise WriteError::Capability(
          "shape '\{name}' must use canonical snake_case",
        )
      }
      capitalize_next = true
    } else if char.is_ascii_lowercase() {
      if capitalize_next {
        chars.push(ascii_upper(char))
        capitalize_next = false
      } else {
        chars.push(char)
      }
      first = false
    } else if char.is_ascii_digit() {
      if first || capitalize_next {
        raise WriteError::Capability(
          "shape '\{name}' must use canonical snake_case",
        )
      }
      chars.push(char)
      first = false
    } else {
      raise WriteError::Capability(
        "shape '\{name}' must use canonical snake_case",
      )
    }
  }
  if capitalize_next {
    raise WriteError::Capability(
      "shape '\{name}' must use canonical snake_case",
    )
  }
  String::from_iter(chars.iter())
}

///|
fn ascii_upper(char : Char) -> Char {
  (char.to_int() - 32).unsafe_to_char()
}

///|
fn build_preset_shape(
  base : ElementBase,
  bounds : Bounds,
  shape_id : Int,
  preset : @slide.PresetShape,
) -> @slide.AutoShape {
  @slide.AutoShape::of_preset(
    shape_id,
    base.id,
    preset,
    to_emu(bounds.x),
    to_emu(bounds.y),
    to_emu(bounds.width),
    to_emu(bounds.height),
  )
}

///|
fn build_connector(
  bundle : DeckBundle,
  id : String,
  spec : ConnectorSpec,
  shape_id : Int,
  shape_ids : Map[String, Int],
  shape_bounds : Map[String, Bounds],
) -> @slide.Connector raise {
  let start = connector_endpoint_point(spec.start, shape_bounds)
  let end = connector_endpoint_point(spec.end, shape_bounds)
  @slide.Connector::{
    id: shape_id,
    name: id,
    start: connector_connection_end(spec.start, shape_ids),
    end: connector_connection_end(spec.end, shape_ids),
    transform: Some(connector_transform(start, end)),
    geometry: Some(@slide.Geometry::Preset(connector_geometry(spec.kind), [])),
    stroke: Some(to_connector_stroke(bundle, spec)),
    effects: match spec.shadow {
      None => None
      Some(shadow) => Some(to_effect_list(bundle, shadow))
    },
    extension: [],
  }
}

///|
fn connector_geometry(kind : String) -> @slide.PresetShape raise {
  match kind {
    "straight" => @slide.PresetShape::StraightConnector1
    "bent2" => @slide.PresetShape::BentConnector2
    "bent3" => @slide.PresetShape::BentConnector3
    "bent4" => @slide.PresetShape::BentConnector4
    "bent5" => @slide.PresetShape::BentConnector5
    "curved2" => @slide.PresetShape::CurvedConnector2
    "curved3" => @slide.PresetShape::CurvedConnector3
    "curved4" => @slide.PresetShape::CurvedConnector4
    "curved5" => @slide.PresetShape::CurvedConnector5
    other =>
      raise WriteError::Capability(
        "connector kind '\{other}' is not implemented",
      )
  }
}

///|
fn connector_endpoint_point(
  endpoint : ConnectorEndpoint,
  shape_bounds : Map[String, Bounds],
) -> Point2 raise {
  match endpoint {
    CoordinateEndpoint(x, y) => Point2::{ x, y }
    ElementEndpoint(id) =>
      match shape_bounds.get(id) {
        Some(bounds) =>
          Point2::{
            x: bounds.x + bounds.width / 2.0,
            y: bounds.y + bounds.height / 2.0,
          }
        None =>
          raise WriteError::Capability(
            "connector endpoint '\{id}' is not a supported connectable element",
          )
      }
  }
}

///|
fn connector_connection_end(
  endpoint : ConnectorEndpoint,
  shape_ids : Map[String, Int],
) -> @slide.ConnectionEnd? raise {
  match endpoint {
    CoordinateEndpoint(_, _) => None
    ElementEndpoint(id) =>
      match shape_ids.get(id) {
        Some(shape_id) => Some(@slide.ConnectionEnd::{ shape_id, idx: 0 })
        None =>
          raise WriteError::Capability(
            "connector endpoint '\{id}' is not a supported connectable element",
          )
      }
  }
}

///|
priv struct Point2 {
  x : Double
  y : Double
}

///|
fn connector_transform(start : Point2, end : Point2) -> @slide.Transform {
  @slide.Transform::{
    offset: @slide.Point::{
      x: to_emu(start.x.min(end.x)),
      y: to_emu(start.y.min(end.y)),
    },
    extent: @slide.Size::{
      cx: to_emu((end.x - start.x).abs()),
      cy: to_emu((end.y - start.y).abs()),
    },
  }
}

///|
fn to_connector_stroke(
  bundle : DeckBundle,
  spec : ConnectorSpec,
) -> @oxml.Stroke raise {
  let mut stroke = match spec.stroke {
    Some(stroke) => to_stroke(bundle, stroke)
    None =>
      @oxml.Stroke::{
        width: Some(to_emu(2.0)),
        cap: None,
        compound: None,
        alignment: None,
        fill: Some(SolidFill(resolve_color(bundle, "#000000"))),
        dash: Some(@oxml.DashStyle::DashSolid),
        join: None,
        head_end: None,
        tail_end: None,
        extension: [],
      }
  }
  match spec.start_arrow {
    None => ()
    Some(arrow) =>
      stroke = @oxml.Stroke::{
        ..stroke,
        head_end: Some(connector_arrow(arrow)),
      }
  }
  match spec.end_arrow {
    None => ()
    Some(arrow) =>
      stroke = @oxml.Stroke::{
        ..stroke,
        tail_end: Some(connector_arrow(arrow)),
      }
  }
  stroke
}

///|
fn connector_arrow(arrow : String) -> @oxml.ArrowEnd raise {
  @oxml.ArrowEnd::{
    arrow_type: match arrow {
      "none" => @oxml.ArrowType::ArrowNone
      "triangle" => @oxml.ArrowType::ArrowTriangle
      "arrow" => @oxml.ArrowType::ArrowArrow
      "stealth" => @oxml.ArrowType::ArrowStealth
      "diamond" => @oxml.ArrowType::ArrowDiamond
      "oval" => @oxml.ArrowType::ArrowOval
      other =>
        raise WriteError::Capability(
          "connector arrow '\{other}' is not implemented",
        )
    },
    width: None,
    length: None,
  }
}

///|
fn to_effect_list(
  bundle : DeckBundle,
  shadow : ShadowSpec,
) -> @oxml.EffectList raise {
  @oxml.EffectList::{
    outer_shadow: Some(@oxml.OuterShadow::{
      blur_rad: to_emu(shadow.blur),
      dist: to_emu(shadow.distance),
      dir: @units.Angle(shadow.direction),
      color: resolve_color(bundle, shadow.color),
      sx: None,
      sy: None,
      kx: None,
      ky: None,
      alignment: None,
      rotate_with_shape: Some(true),
    }),
    inner_shadow: None,
    glow: None,
    blur: None,
    reflection: None,
    soft_edge: None,
    preset_shadow: None,
    extension: [],
  }
}

///|
fn text_run_properties(
  bundle : DeckBundle,
  content : TextContent,
) -> @slide.RunProperties raise {
  let mut props = @slide.RunProperties::default()
  let text = resolve_text_properties(bundle, content)
  match text.font_size {
    None => ()
    Some(size) => props = props.with_font_size(@units.Pt(size))
  }
  match text.font_family {
    None => ()
    Some(family) => props = props.with_font(family)
  }
  match text.color {
    None => ()
    Some(color) =>
      props = @slide.RunProperties::{
        ..props,
        fill: Some(resolve_color(bundle, color)),
      }
  }
  if text.bold == Some(true) {
    props = props.with_bold()
  }
  if text.italic == Some(true) {
    props = props.with_italic()
  }
  if text.letter_spacing is Some(_) {
    raise WriteError::Capability("letter_spacing is not implemented")
  }
  props
}

///|
fn text_paragraph_properties(
  bundle : DeckBundle,
  content : TextContent,
  props : @slide.ParagraphProperties,
) -> @slide.ParagraphProperties {
  let text = resolve_text_properties(bundle, content)
  match text.line_height {
    None => props
    Some(line_height) =>
      @slide.ParagraphProperties::{
        ..props,
        line_spacing: Some(@units.Percentage((line_height * 100.0).round())),
      }
  }
}

///|
fn resolve_color(bundle : DeckBundle, color : String) -> @oxml.Color raise {
  let color = resolve_color_text(bundle, color)
  let rgb = @units.RgbColor::parse_hex(rgb_hex(color)) catch {
    err =>
      raise WriteError::Backend("invalid color after loader validation: \{err}")
  }
  let base = @oxml.Color::srgb(rgb)
  if color.length() == 9 {
    @oxml.Color::{
      ..base,
      transforms: [@units.ColorTransform::Alpha(alpha_percentage(color))],
    }
  } else {
    base
  }
}

///|
fn resolve_color_text(bundle : DeckBundle, color : String) -> String {
  match token_name_unchecked(color) {
    None => color
    Some(name) =>
      match bundle.deck.theme {
        Some(theme) =>
          match theme.colors.get(name) {
            Some(value) => value
            None => color
          }
        None => color
      }
  }
}

///|
fn rgb_hex(color : String) -> String {
  if color.length() == 9 {
    String::from_iter(color.iter().take(7))
  } else {
    color
  }
}

///|
fn alpha_percentage(color : String) -> @units.Percentage raise {
  let chars = color.to_array()
  let alpha = parse_hex_byte(chars[7], chars[8], color)
  @units.Percentage(alpha.to_double() / 255.0 * 100.0)
}

///|
fn parse_hex_byte(hi : Char, lo : Char, original : String) -> Int raise {
  match (hex_digit(hi), hex_digit(lo)) {
    (Some(hi), Some(lo)) => hi * 16 + lo
    _ =>
      raise WriteError::Backend(
        "invalid alpha color after loader validation: \{original}",
      )
  }
}

///|
fn hex_digit(char : Char) -> Int? {
  let code = char.to_int()
  if code >= '0'.to_int() && code <= '9'.to_int() {
    Some(code - '0'.to_int())
  } else if code >= 'a'.to_int() && code <= 'f'.to_int() {
    Some(code - 'a'.to_int() + 10)
  } else if code >= 'A'.to_int() && code <= 'F'.to_int() {
    Some(code - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn to_stroke(bundle : DeckBundle, border : Border) -> @oxml.Stroke raise {
  @oxml.Stroke::{
    width: Some(to_emu(border.width)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(SolidFill(resolve_color(bundle, border.color))),
    dash: Some(border_dash_style(border.style)),
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
  }
}

///|
fn to_gradient_fill(
  bundle : DeckBundle,
  gradient : Gradient,
) -> @oxml.Fill raise {
  @oxml.Fill::GradientFill(@oxml.Gradient::{
    stops: gradient_stops(bundle, gradient.stops),
    direction: @oxml.GradientDirection::Linear(
      @units.Angle(gradient.direction.unwrap_or(0.0)),
      false,
    ),
    rotate_with_shape: Some(true),
    flip: None,
    extension: [],
  })
}

///|
fn gradient_stops(
  bundle : DeckBundle,
  stops : Array[GradientStop],
) -> Array[@oxml.GradientStop] raise {
  let result = []
  for stop in stops {
    result.push(@oxml.GradientStop::{
      position: @units.Percentage(stop.at * 100.0),
      color: resolve_color(bundle, stop.color),
    })
  }
  result
}

///|
fn border_dash_style(style : String) -> @oxml.DashStyle raise {
  match style {
    "solid" => @oxml.DashStyle::DashSolid
    "dot" => @oxml.DashStyle::DashDot
    "dash" => @oxml.DashStyle::DashDash
    "long_dash" => @oxml.DashStyle::DashLgDash
    "dash_dot" => @oxml.DashStyle::DashDashDot
    "long_dash_dot" => @oxml.DashStyle::DashLgDashDot
    "long_dash_dot_dot" => @oxml.DashStyle::DashLgDashDotDot
    other =>
      raise WriteError::Capability("border style '\{other}' is not implemented")
  }
}

///|
fn horizontal_alignment(value : String) -> @slide.TextAlignment raise {
  match value {
    "left" => AlignLeft
    "center" => AlignCenter
    "right" => AlignRight
    "justify" => AlignJustify
    "justify_low" => AlignJustifyLow
    "distributed" => AlignDistributed
    "thai_distributed" => AlignThaiDistributed
    other =>
      raise WriteError::Capability(
        "horizontal alignment '\{other}' is not implemented",
      )
  }
}

///|
fn vertical_anchor(value : String) -> @slide.Anchor raise {
  match value {
    "top" => AnchorTop
    "center" => AnchorCenter
    "bottom" => AnchorBottom
    "justify" => AnchorJustify
    "distributed" => AnchorDistributed
    other =>
      raise WriteError::Capability(
        "vertical alignment '\{other}' is not implemented",
      )
  }
}

///|
fn to_emu(value : Double) -> @units.Emu {
  @units.Emu((value / 96.0 * 914400.0).round().to_int64())
}

///|
fn ensure_parent_dir(output_path : String) -> Unit raise {
  let path : @path.Path = output_path
  let parent = path.dirname().to_string()
  if parent != "" &&
    parent != "." &&
    !(@miniio.is_dir(parent) catch { _ => false }) {
    @miniio.mkdir(parent) catch {
      err =>
        raise WriteError::Io(
          "cannot create output directory '\{parent}': \{err}",
        )
    }
  }
}

///|
fn output_temp_path(output_path : String) -> String raise {
  let path : @path.Path = output_path
  let parent = path.dirname().to_string()
  let base = path.basename().to_owned()
  for index in 1..<=1000 {
    let temp_name = ".\{base}.tmp-\{index}"
    let temp_path = if parent == "" {
      temp_name
    } else {
      let parent_path : @path.Path = parent
      parent_path.join(temp_name).to_string()
    }
    if !(@miniio.exists(temp_path) catch { _ => false }) {
      return temp_path
    }
  }
  raise WriteError::Io(
    "cannot allocate temporary output path for '\{output_path}'",
  )
}

///|
fn remove_temp_file(path : String) -> Unit {
  @miniio.remove_file(path) catch {
    _ => ()
  }
}
