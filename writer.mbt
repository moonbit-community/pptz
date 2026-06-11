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
    let _ = prs.add_blank_typed_slide_mut().finish_mut() catch {
        err => raise WriteError::Backend("cannot add slide: \{err}")
      }
    let slide = build_slide(loaded.bundle, resolved_page) catch {
      err => raise err
    }
    prs.update_slide_mut(index, slide) catch {
      err => raise WriteError::Backend("cannot update slide \{index}: \{err}")
    }
    add_page_images(prs, index, loaded.bundle, resolved_page)
  }
  prs.save()
}

///|
pub fn write_pptx_file(loaded : LoadedDeck, output_path : String) -> Unit raise {
  if output_path.is_blank() {
    raise WriteError::Io("output path must not be empty")
  }
  ensure_parent_dir(output_path)
  let bytes = render_pptx(loaded)
  @miniio.write_file(output_path, Bytes::from_array(bytes[:])) catch {
    err => raise WriteError::Io("cannot write output '\{output_path}': \{err}")
  }
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
  match spec.fit {
    StretchFit => ()
    CoverFit =>
      raise WriteError::Capability("image fit 'cover' is not implemented")
    ContainFit =>
      raise WriteError::Capability("image fit 'contain' is not implemented")
  }
  let path = source_full_path(bundle.deck_dir, spec.path).to_string()
  let bytes = @miniio.read_file(path) catch {
    err => raise WriteError::Io("cannot read image '\{spec.path}': \{err}")
  }
  let bounds = base.bounds
  prs.add_picture_mut(
    slide_index,
    bytes.binary().to_fixedarray(),
    to_emu(bounds.x),
    to_emu(bounds.y),
    to_emu(bounds.width),
    to_emu(bounds.height),
  ) catch {
    err => raise WriteError::Backend("cannot add image '\{spec.path}': \{err}")
  }
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
    other => raise WriteError::Capability("shape '\{other}' is not implemented")
  }
  match spec.fill {
    None => ()
    Some(NoFill) => shape = shape.with_no_fill()
    Some(SolidFill(color)) =>
      shape = shape.with_fill(SolidFill(resolve_color(bundle, color)))
    Some(GradientFill(_)) =>
      raise WriteError::Capability("shape gradient fill is not implemented")
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
  let theme_style = match content.style {
    None => None
    Some(style_token) => lookup_text_style(bundle, style_token)
  }
  let font_size = option_or(content.font_size, style_font_size(theme_style))
  match font_size {
    None => ()
    Some(size) => props = props.with_font_size(@units.Pt(size))
  }
  let font_family = option_or(
    content.font_family,
    style_font_family(theme_style),
  )
  match font_family {
    None => ()
    Some(family) => props = props.with_font(family)
  }
  let color = option_or(content.color, style_color(theme_style))
  match color {
    None => ()
    Some(color) => props = props.with_color(resolve_rgb(bundle, color))
  }
  let bold = option_or(content.bold, style_bold(theme_style))
  if bold == Some(true) {
    props = props.with_bold()
  }
  let italic = option_or(content.italic, style_italic(theme_style))
  if italic == Some(true) {
    props = props.with_italic()
  }
  match theme_style {
    Some(style) =>
      if style.line_height is Some(_) || style.letter_spacing is Some(_) {
        raise WriteError::Capability(
          "line_height and letter_spacing are not implemented by the MVP writer",
        )
      }
    None => ()
  }
  props
}

///|
fn lookup_text_style(
  bundle : DeckBundle,
  style_token : String,
) -> TextStyle? raise {
  match token_name_for_writer(style_token) {
    None => raise WriteError::Capability("text style must be a theme token")
    Some(name) =>
      match bundle.deck.theme {
        None => None
        Some(theme) => theme.text_styles.get(name)
      }
  }
}

///|
fn resolve_color(bundle : DeckBundle, color : String) -> @oxml.Color raise {
  @oxml.Color::srgb(resolve_rgb(bundle, color))
}

///|
fn resolve_rgb(bundle : DeckBundle, color : String) -> @units.RgbColor raise {
  let color = match token_name_for_writer(color) {
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
  if border.style != "solid" {
    raise WriteError::Capability("only solid borders are implemented")
  }
  @oxml.Stroke::{
    width: Some(to_emu(border.width)),
    cap: None,
    compound: None,
    alignment: None,
    fill: Some(SolidFill(resolve_color(bundle, border.color))),
    dash: None,
    join: None,
    head_end: None,
    tail_end: None,
    extension: [],
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
fn source_full_path(base : String, value : String) -> @path.Path {
  let base_path : @path.Path = base
  let relative : @path.Path = value
  base_path.join(relative).normalize()
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
fn token_name_for_writer(value : String) -> String? {
  match value.strip_prefix("$") {
    None => None
    Some(name) => Some(name.to_owned())
  }
}

///|
fn[T] option_or(value : T?, fallback : T?) -> T? {
  match value {
    Some(_) => value
    None => fallback
  }
}

///|
fn style_font_size(style : TextStyle?) -> Double? {
  match style {
    None => None
    Some(style) => style.font_size
  }
}

///|
fn style_font_family(style : TextStyle?) -> String? {
  match style {
    None => None
    Some(style) => style.font_family
  }
}

///|
fn style_color(style : TextStyle?) -> String? {
  match style {
    None => None
    Some(style) => style.color
  }
}

///|
fn style_bold(style : TextStyle?) -> Bool? {
  match style {
    None => None
    Some(style) => style.bold
  }
}

///|
fn style_italic(style : TextStyle?) -> Bool? {
  match style {
    None => None
    Some(style) => style.italic
  }
}
