///|
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub(all) struct Diagnostic {
  severity : Severity
  code : String
  message : String
  path : String?
  element_id : String?
  field : String?
} derive(Eq, Debug)

///|
pub(all) suberror LoadError {
  Fatal(String)
  Diagnostics(Array[Diagnostic])
} derive(Debug)

///|
pub(all) struct LoadedDeck {
  bundle : DeckBundle
  warnings : Array[Diagnostic]
} derive(Eq, Debug)

///|
pub(all) struct DeckBundle {
  deck_path : String
  deck_dir : String
  deck : Deck
  pages : Array[ResolvedPage]
} derive(Eq, Debug)

///|
pub(all) struct ResolvedPage {
  path : String
  full_path : String
  page : Page
} derive(Eq, Debug)

///|
pub fn load_deck(input_path : String) -> LoadedDeck raise {
  let deck_path = normal_path(input_path)
  let deck_path_text = deck_path.to_string()
  if !(@miniio.is_file(deck_path_text) catch {
      err =>
        raise LoadError::Fatal("cannot stat deck file '\{input_path}': \{err}")
    }) {
    raise LoadError::Fatal("deck input is not a file: \{input_path}")
  }
  let source = @miniio.read_text_file(deck_path_text) catch {
    err =>
      raise LoadError::Fatal("cannot read deck file '\{input_path}': \{err}")
  }
  let deck = parse_deck_toml(source) catch {
    err =>
      raise LoadError::Fatal("cannot parse deck file '\{input_path}': \{err}")
  }
  let deck_dir = deck_path.dirname()
  let deck_dir_text = deck_dir.to_string()
  let errors = []
  let pages = load_pages(deck_dir, deck, errors)
  if errors.length() > 0 {
    raise LoadError::Diagnostics(errors)
  }
  let bundle = DeckBundle::{
    deck_path: deck_path_text,
    deck_dir: deck_dir_text,
    deck,
    pages,
  }
  let warnings = []
  let validation_errors = []
  validate_bundle(bundle, validation_errors, warnings)
  if validation_errors.length() > 0 {
    raise LoadError::Diagnostics(validation_errors)
  }
  LoadedDeck::{ bundle, warnings }
}

///|
fn load_pages(
  deck_dir : @path.Path,
  deck : Deck,
  errors : Array[Diagnostic],
) -> Array[ResolvedPage] raise {
  let parsed_pages = Map([], capacity=deck.pages.length())
  let resolved_pages = []
  for page_ref in deck.pages {
    match resolve_source_path(deck_dir, page_ref.path) {
      Some(full_path) => {
        let full_path_text = full_path.to_string()
        match parsed_pages.get(full_path_text) {
          Some(page) =>
            resolved_pages.push(ResolvedPage::{
              path: page_ref.path,
              full_path: full_path_text,
              page,
            })
          None =>
            if !(@miniio.is_file(full_path_text) catch { _ => false }) {
              errors.push(
                error_diagnostic(
                  "PZ010",
                  "page reference does not resolve to a file",
                  path=page_ref.path,
                  field="pages.path",
                ),
              )
            } else {
              let source = @miniio.read_text_file(full_path_text) catch {
                err =>
                  raise LoadError::Fatal(
                    "cannot read page file '\{page_ref.path}': \{err}",
                  )
              }
              let page = parse_page_toml(source) catch {
                err =>
                  raise LoadError::Fatal(
                    "cannot parse page file '\{page_ref.path}': \{err}",
                  )
              }
              parsed_pages[full_path_text] = page
              resolved_pages.push(ResolvedPage::{
                path: page_ref.path,
                full_path: full_path_text,
                page,
              })
            }
        }
      }
      None =>
        errors.push(
          error_diagnostic(
            "PZ010",
            "page path must be relative and stay inside the deck directory",
            path=page_ref.path,
            field="pages.path",
          ),
        )
    }
  }
  resolved_pages
}

///|
fn validate_bundle(
  bundle : DeckBundle,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  if bundle.deck.size.width <= 0.0 || bundle.deck.size.height <= 0.0 {
    errors.push(
      error_diagnostic(
        "PZ001",
        "deck size must be positive",
        path=bundle.deck_path,
        field="size",
      ),
    )
  }
  if bundle.deck.pages.length() == 0 {
    errors.push(
      error_diagnostic(
        "PZ010",
        "deck must reference at least one page",
        path=bundle.deck_path,
        field="pages",
      ),
    )
  }
  validate_theme(bundle.deck, bundle.deck_path, errors)
  for resolved_page in bundle.pages {
    validate_page(bundle, resolved_page, errors, warnings)
  }
}

///|
fn validate_theme(
  deck : Deck,
  deck_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  match deck.theme {
    None => ()
    Some(theme) => {
      for name, value in theme.colors {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme color token name is invalid",
              path=deck_path,
              field="theme.colors.\{name}",
            ),
          )
        }
        validate_color_value(
          value,
          theme,
          deck_path,
          None,
          "theme.colors.\{name}",
          errors,
        )
      }
      for name, style in theme.text_styles {
        if !is_identifier(name) {
          errors.push(
            error_diagnostic(
              "PZ030",
              "theme text style token name is invalid",
              path=deck_path,
              field="theme.text_styles.\{name}",
            ),
          )
        }
        match style.color {
          None => ()
          Some(color) =>
            validate_color_value(
              color,
              theme,
              deck_path,
              None,
              "theme.text_styles.\{name}.color",
              errors,
            )
        }
      }
    }
  }
}

///|
fn validate_page(
  bundle : DeckBundle,
  resolved_page : ResolvedPage,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  match resolved_page.page.background {
    None => ()
    Some(background) =>
      validate_background(bundle, resolved_page.path, background, errors)
  }
  let ids = Map([], capacity=resolved_page.page.elements.length())
  for element in resolved_page.page.elements {
    let base = element_base(element)
    if !is_identifier(base.id) {
      errors.push(
        error_diagnostic(
          "PZ021",
          "element id is invalid",
          path=resolved_page.path,
          element_id=base.id,
          field="elements.id",
        ),
      )
    }
    if ids.contains(base.id) {
      errors.push(
        error_diagnostic(
          "PZ020",
          "duplicate element id",
          path=resolved_page.path,
          element_id=base.id,
          field="elements.id",
        ),
      )
    } else {
      ids[base.id] = true
    }
    validate_bounds(bundle, resolved_page.path, base, errors, warnings)
    validate_element(bundle, resolved_page.path, element, errors, warnings)
  }
}

///|
fn validate_background(
  bundle : DeckBundle,
  page_path : String,
  background : Background,
  errors : Array[Diagnostic],
) -> Unit {
  match background {
    SolidBackground(color) =>
      validate_page_color(
        bundle,
        page_path,
        None,
        "background.color",
        color,
        errors,
      )
    GradientBackground(gradient) =>
      validate_gradient(bundle, page_path, None, "background", gradient, errors)
    ImageBackground(fill) =>
      validate_asset_path(
        bundle,
        page_path,
        None,
        "background.path",
        fill.path,
        errors,
      )
  }
}

///|
fn validate_element(
  bundle : DeckBundle,
  page_path : String,
  element : Element,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  match element {
    TextElement(base, content) => {
      if content.text.trim().is_empty() {
        warnings.push(
          warning_diagnostic(
            "PZ102",
            "text is empty or whitespace-only",
            path=page_path,
            element_id=base.id,
            field="elements.content.text",
          ),
        )
      }
      validate_text_fit(bundle, page_path, base, content, warnings)
      validate_text_style_ref(bundle, page_path, base.id, content.style, errors)
      match content.color {
        None => ()
        Some(color) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.color",
            color,
            errors,
          )
      }
    }
    ShapeElement(base, spec) => {
      match spec.fill {
        None | Some(NoFill) => ()
        Some(SolidFill(color)) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill.color",
            color,
            errors,
          )
        Some(GradientFill(gradient)) =>
          validate_gradient(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill",
            gradient,
            errors,
          )
      }
      match spec.border {
        None => ()
        Some(border) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.border.color",
            border.color,
            errors,
          )
      }
    }
    ImageElement(base, spec) => {
      validate_asset_path(
        bundle,
        page_path,
        Some(base.id),
        "elements.content.path",
        spec.path,
        errors,
      )
      validate_image_crop(page_path, base.id, spec.crop, errors)
      validate_image_source_size(bundle, page_path, base.id, spec, errors)
    }
    IconElement(base, spec) =>
      match spec.fill {
        None | Some(NoFill) => ()
        Some(SolidFill(color)) =>
          validate_page_color(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill.color",
            color,
            errors,
          )
        Some(GradientFill(gradient)) =>
          validate_gradient(
            bundle,
            page_path,
            Some(base.id),
            "elements.content.fill",
            gradient,
            errors,
          )
      }
    TableElement(_) | ChartElement(_) => ()
  }
}

///|
fn validate_text_fit(
  bundle : DeckBundle,
  page_path : String,
  base : ElementBase,
  content : TextContent,
  warnings : Array[Diagnostic],
) -> Unit {
  let bounds = base.bounds
  if bounds.width <= 0.0 ||
    bounds.height <= 0.0 ||
    content.text.trim().is_empty() {
    return
  }
  let estimate = estimate_text_fit(bundle, bounds, content)
  if estimate.height > bounds.height * 1.05 ||
    estimate.longest_token_width > bounds.width {
    warnings.push(
      warning_diagnostic(
        "PZ103",
        "text may overflow its bounds",
        path=page_path,
        element_id=base.id,
        field="elements.content.text",
      ),
    )
  }
}

///|
fn validate_bounds(
  bundle : DeckBundle,
  page_path : String,
  base : ElementBase,
  errors : Array[Diagnostic],
  warnings : Array[Diagnostic],
) -> Unit {
  let bounds = base.bounds
  if bounds.width < 0.0 || bounds.height < 0.0 {
    errors.push(
      error_diagnostic(
        "PZ101",
        "bounds width and height must not be negative",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  } else if bounds.width == 0.0 || bounds.height == 0.0 {
    warnings.push(
      warning_diagnostic(
        "PZ101",
        "bounds have zero width or height",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  }
  if bounds.x < 0.0 ||
    bounds.y < 0.0 ||
    bounds.x + bounds.width > bundle.deck.size.width ||
    bounds.y + bounds.height > bundle.deck.size.height {
    warnings.push(
      warning_diagnostic(
        "PZ100",
        "bounds extend outside canvas",
        path=page_path,
        element_id=base.id,
        field="elements.bounds",
      ),
    )
  }
}

///|
fn validate_text_style_ref(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  style : String?,
  errors : Array[Diagnostic],
) -> Unit {
  match style {
    None => ()
    Some(style) =>
      match bundle.deck.theme {
        None =>
          errors.push(
            error_diagnostic(
              "PZ030",
              "text style token has no deck theme",
              path=page_path,
              element_id~,
              field="elements.content.style",
            ),
          )
        Some(theme) =>
          match token_name(style) {
            Some(name) =>
              if !theme.text_styles.contains(name) {
                errors.push(
                  error_diagnostic(
                    "PZ030",
                    "unresolved text style token",
                    path=page_path,
                    element_id~,
                    field="elements.content.style",
                  ),
                )
              }
            None =>
              errors.push(
                error_diagnostic(
                  "PZ030",
                  "text style must be a whole-string theme token",
                  path=page_path,
                  element_id~,
                  field="elements.content.style",
                ),
              )
          }
      }
  }
}

///|
fn validate_page_color(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  color : String,
  errors : Array[Diagnostic],
) -> Unit {
  match bundle.deck.theme {
    None => validate_color_syntax(color, page_path, element_id, field, errors)
    Some(theme) =>
      validate_color_value(color, theme, page_path, element_id, field, errors)
  }
}

///|
fn validate_color_value(
  color : String,
  theme : Theme,
  path : String,
  element_id : String?,
  field : String,
  errors : Array[Diagnostic],
) -> Unit {
  match token_name(color) {
    Some(name) =>
      if !theme.colors.contains(name) {
        errors.push(
          error_diagnostic(
            "PZ030",
            "unresolved color token",
            path~,
            element_id?,
            field~,
          ),
        )
      }
    None => validate_color_syntax(color, path, element_id, field, errors)
  }
}

///|
fn validate_color_syntax(
  color : String,
  path : String,
  element_id : String?,
  field : String,
  errors : Array[Diagnostic],
) -> Unit {
  if !is_hex_color(color) {
    errors.push(
      error_diagnostic(
        "PZ032",
        "color must be #RRGGBB, #RRGGBBAA, or a theme token",
        path~,
        element_id?,
        field~,
      ),
    )
  }
}

///|
fn validate_gradient(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  gradient : Gradient,
  errors : Array[Diagnostic],
) -> Unit {
  for index, stop in gradient.stops {
    validate_page_color(
      bundle,
      page_path,
      element_id,
      "\{field}.stops[\{index}].color",
      stop.color,
      errors,
    )
  }
}

///|
fn validate_asset_path(
  bundle : DeckBundle,
  page_path : String,
  element_id : String?,
  field : String,
  asset_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  if asset_path.is_blank() {
    errors.push(
      error_diagnostic(
        "PZ040",
        "asset path must not be empty",
        path=page_path,
        element_id?,
        field~,
      ),
    )
    return
  }
  if asset_path.contains("://") {
    errors.push(
      error_diagnostic(
        "PZ040",
        "remote asset URLs are not allowed",
        path=page_path,
        element_id?,
        field~,
      ),
    )
    return
  }
  match resolve_source_path(bundle.deck_dir, asset_path) {
    None =>
      errors.push(
        error_diagnostic(
          "PZ040",
          "asset path must be relative and stay inside the deck directory",
          path=page_path,
          element_id?,
          field~,
        ),
      )
    Some(full_path) => {
      let full_path_text = full_path.to_string()
      if !(@miniio.is_file(full_path_text) catch { _ => false }) {
        errors.push(
          error_diagnostic(
            "PZ040",
            "asset path does not resolve to a file",
            path=page_path,
            element_id?,
            field~,
          ),
        )
      }
    }
  }
}

///|
fn validate_image_crop(
  page_path : String,
  element_id : String,
  crop : CropRect?,
  errors : Array[Diagnostic],
) -> Unit {
  match crop {
    None => ()
    Some(crop) => {
      if !valid_crop_edge(crop.left) ||
        !valid_crop_edge(crop.top) ||
        !valid_crop_edge(crop.right) ||
        !valid_crop_edge(crop.bottom) {
        errors.push(
          error_diagnostic(
            "PZ041",
            "image crop values must be between 0.0 and 1.0",
            path=page_path,
            element_id~,
            field="elements.content.crop",
          ),
        )
      }
      if crop.left + crop.right >= 1.0 || crop.top + crop.bottom >= 1.0 {
        errors.push(
          error_diagnostic(
            "PZ041",
            "image crop must leave a non-empty source rectangle",
            path=page_path,
            element_id~,
            field="elements.content.crop",
          ),
        )
      }
    }
  }
}

///|
fn valid_crop_edge(value : Double) -> Bool {
  value >= 0.0 && value <= 1.0
}

///|
fn validate_image_source_size(
  bundle : DeckBundle,
  page_path : String,
  element_id : String,
  spec : ImageSpec,
  errors : Array[Diagnostic],
) -> Unit {
  match spec.fit {
    StretchFit => ()
    CoverFit | ContainFit =>
      match resolve_existing_asset_path(bundle, spec.path) {
        None => ()
        Some(full_path) => {
          let bytes = @miniio.read_file(full_path) catch {
            err => {
              errors.push(
                error_diagnostic(
                  "PZ040",
                  "cannot read image asset: \{err}",
                  path=page_path,
                  element_id~,
                  field="elements.content.path",
                ),
              )
              return
            }
          }
          match image_source_size(spec.path, bytes.binary().to_fixedarray()) {
            Some(size) =>
              if size.width <= 0.0 || size.height <= 0.0 {
                errors.push(
                  error_diagnostic(
                    "PZ041",
                    "image dimensions must be positive",
                    path=page_path,
                    element_id~,
                    field="elements.content.path",
                  ),
                )
              }
            None =>
              errors.push(
                error_diagnostic(
                  "PZ041",
                  "image fit requires readable image dimensions",
                  path=page_path,
                  element_id~,
                  field="elements.content.fit",
                ),
              )
          }
        }
      }
  }
}

///|
fn resolve_existing_asset_path(
  bundle : DeckBundle,
  asset_path : String,
) -> String? {
  match resolve_source_path(bundle.deck_dir, asset_path) {
    None => None
    Some(full_path) => {
      let full_path_text = full_path.to_string()
      if (@miniio.is_file(full_path_text) catch { _ => false }) {
        Some(full_path_text)
      } else {
        None
      }
    }
  }
}

///|
fn element_base(element : Element) -> ElementBase {
  match element {
    TextElement(base, _) => base
    ShapeElement(base, _) => base
    ImageElement(base, _) => base
    IconElement(base, _) => base
    TableElement(base) => base
    ChartElement(base) => base
  }
}

///|
fn normal_path(value : String) -> @path.Path {
  let path : @path.Path = value
  path.normalize()
}

///|
fn resolve_source_path(base : @path.Path, value : String) -> @path.Path? {
  let relative : @path.Path = value
  if relative.is_absolute() || value.is_blank() {
    return None
  }
  let full_path = base.join(relative).normalize()
  let rel_text = full_path.relative(base~).to_string()
  if rel_text == ".." ||
    rel_text.has_prefix("../") ||
    rel_text.has_prefix("..\\") {
    None
  } else {
    Some(full_path)
  }
}

///|
fn token_name(value : String) -> String? {
  match value.strip_prefix("$") {
    None => None
    Some(name_view) => {
      let name = name_view.to_owned()
      if is_identifier(name) {
        Some(name)
      } else {
        None
      }
    }
  }
}

///|
fn is_hex_color(value : String) -> Bool {
  guard value.length() == 7 || value.length() == 9 else { return false }
  guard value.get_char(0) == Some('#') else { return false }
  for index in 1..<value.length() {
    match value.get_char(index) {
      Some(char) => if !char.is_ascii_hexdigit() { return false }
      None => return false
    }
  }
  true
}

///|
fn is_identifier(value : String) -> Bool {
  guard !value.is_empty() else { return false }
  let mut index = 0
  for char in value.iter() {
    if index == 0 {
      if !char.is_ascii_alphabetic() {
        return false
      }
    } else if !(char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '_' ||
      char == '-') {
      return false
    }
    index += 1
  }
  true
}

///|
fn error_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Error, code, message, path, element_id, field }
}

///|
fn warning_diagnostic(
  code : String,
  message : String,
  path? : String,
  element_id? : String,
  field? : String,
) -> Diagnostic {
  Diagnostic::{ severity: Warning, code, message, path, element_id, field }
}
