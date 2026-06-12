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
  let slide = build_slide(bundle, resolved_page) catch { err => raise err }
  prs.update_slide_mut(slide_index, slide) catch {
    err =>
      raise WriteError::Backend("cannot update slide \{slide_index}: \{err}")
  }
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
) -> @slide.Slide raise {
  let prs = @presentation.Presentation::new() catch {
    err => raise WriteError::Backend("cannot create slide template: \{err}")
  }
  let _ = prs.add_blank_typed_slide_mut().finish_mut() catch {
      err => raise WriteError::Backend("cannot create slide template: \{err}")
    }
  let mut slide = prs.slides()[0]
  match resolved_page.page.background {
    None => ()
    Some(SolidBackground(color)) =>
      slide = slide.with_background(SolidFill(resolve_color(bundle, color)))
    Some(GradientBackground(_)) =>
      raise WriteError::Capability("gradient backgrounds are not implemented")
    Some(ImageBackground(_)) =>
      raise WriteError::Capability("image backgrounds are not implemented")
  }
  let mut shape_id = 2
  for element in resolved_page.page.elements {
    match element {
      ImageElement(_, _) => ()
      _ => {
        let shape = build_shape(bundle, element, shape_id)
        shape_id += 1
        slide = slide.with_shape(shape)
      }
    }
  }
  slide
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
fn build_shape(
  bundle : DeckBundle,
  element : Element,
  shape_id : Int,
) -> @slide.Shape raise {
  match element {
    TextElement(base, content) =>
      @slide.AutoShape(build_textbox(bundle, base, content, shape_id))
    ShapeElement(base, spec) =>
      @slide.AutoShape(build_auto_shape(bundle, base, spec, shape_id))
    ImageElement(_, _) =>
      raise WriteError::Capability("internal image dispatch error")
    IconElement(_, _) =>
      raise WriteError::Capability("icon elements are not implemented")
    TableElement(_) =>
      raise WriteError::Capability("table elements are not implemented")
    ChartElement(_) =>
      raise WriteError::Capability("chart elements are not implemented")
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
  let path = source_full_path(bundle.deck_dir, spec.path).to_string()
  let bytes = @miniio.read_file(path) catch {
    err => raise WriteError::Io("cannot read image '\{spec.path}': \{err}")
  }
  let image_bytes = bytes.binary().to_fixedarray()
  let placement = image_placement(
    base.bounds,
    spec.fit,
    image_source_size(spec.path, image_bytes),
    spec.crop,
  )
  let bounds = placement.bounds
  let shape_index = add_picture_shape_mut(
    prs,
    slide_index,
    spec.path,
    image_bytes,
    bounds,
  )
  apply_picture_crop_at(
    prs,
    slide_index,
    shape_index,
    placement.crop,
    spec.path,
  )
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
  let mut paragraph = @slide.Paragraph::of_styled_text(content.text, run_props)
  match content.align {
    None => ()
    Some(align) =>
      paragraph = paragraph.with_alignment(
        horizontal_alignment(align.horizontal),
      )
  }
  let mut text_body = @slide.TextBody::of_paragraphs([paragraph])
  match content.align {
    None => ()
    Some(align) => {
      let props = @slide.BodyProperties::{
        ..@slide.BodyProperties::default(),
        anchor: Some(vertical_anchor(align.vertical)),
      }
      text_body = @slide.TextBody::{ ..text_body, body_properties: Some(props) }
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
fn build_auto_shape(
  bundle : DeckBundle,
  base : ElementBase,
  spec : ShapeSpec,
  shape_id : Int,
) -> @slide.AutoShape raise {
  let bounds = base.bounds
  let mut shape = match spec.shape {
    "rect" =>
      @slide.AutoShape::rect(
        shape_id,
        base.id,
        to_emu(bounds.x),
        to_emu(bounds.y),
        to_emu(bounds.width),
        to_emu(bounds.height),
      )
    "ellipse" =>
      @slide.AutoShape::ellipse(
        shape_id,
        base.id,
        to_emu(bounds.x),
        to_emu(bounds.y),
        to_emu(bounds.width),
        to_emu(bounds.height),
      )
    "round_rect" =>
      @slide.AutoShape::round_rect(
        shape_id,
        base.id,
        to_emu(bounds.x),
        to_emu(bounds.y),
        to_emu(bounds.width),
        to_emu(bounds.height),
      )
    other => raise WriteError::Capability("shape '\{other}' is not implemented")
  }
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
  shape
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
    Some(color) => props = props.with_color(resolve_rgb(bundle, color))
  }
  if text.bold == Some(true) {
    props = props.with_bold()
  }
  if text.italic == Some(true) {
    props = props.with_italic()
  }
  if text.line_height is Some(_) || text.letter_spacing is Some(_) {
    raise WriteError::Capability(
      "line_height and letter_spacing are not implemented by the MVP writer",
    )
  }
  props
}

///|
fn resolve_color(bundle : DeckBundle, color : String) -> @oxml.Color raise {
  @oxml.Color::srgb(resolve_rgb(bundle, color))
}

///|
fn resolve_rgb(bundle : DeckBundle, color : String) -> @units.RgbColor raise {
  let color = match token_name_unchecked(color) {
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
  if color.length() == 9 {
    raise WriteError::Capability(
      "alpha colors are not implemented by the MVP writer",
    )
  }
  @units.RgbColor::parse_hex(color) catch {
    err =>
      raise WriteError::Backend("invalid color after loader validation: \{err}")
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
