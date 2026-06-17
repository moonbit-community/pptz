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
test "image fit defaults to stretch" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "hero"
      #|    type: "image"
      #|    bounds: [0, 0, 640, 360]
      #|    content:
      #|      path: "images/hero.png"
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    ImageElement(_, spec) =>
      match spec.fit {
        StretchFit =>
          match spec.crop {
            None => ()
            Some(_) => abort("expected no crop")
          }
        _ => abort("expected stretch fit")
      }
    _ => abort("expected image element")
  }
}

///|
test "parse image crop" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "hero"
      #|    type: "image"
      #|    bounds: [0, 0, 640, 360]
      #|    content:
      #|      path: "images/hero.png"
      #|      fit: "cover"
      #|      crop:
      #|        left: 0.1
      #|        top: 0.2
      #|        right: 0.3
      #|        bottom: 0.4
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    ImageElement(_, spec) => {
      match spec.fit {
        CoverFit => ()
        _ => abort("expected cover fit")
      }
      match spec.crop {
        Some(crop) => {
          assert_eq(crop.left, 0.1)
          assert_eq(crop.top, 0.2)
          assert_eq(crop.right, 0.3)
          assert_eq(crop.bottom, 0.4)
        }
        None => abort("expected crop")
      }
    }
    _ => abort("expected image element")
  }
}

///|
test "parse minimal shapes page" {
  let source = @miniio.read_text_file("examples/minimal/pages/shapes.page.yaml") catch {
    err => abort("read page failed: \{err}")
  }
  let page = parse_page_yaml(source) catch {
    err => abort("parse page failed: \{err}")
  }
  assert_eq(page.elements.length(), 9)
  match page.elements[1] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "panel")
      assert_eq(spec.shape, "round_rect")
      match spec.shadow {
        Some(shadow) => assert_eq(shadow.blur, 14.0)
        None => abort("expected panel shadow")
      }
    }
    _ => abort("expected shape element")
  }
  match page.elements[3] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "outline")
      match spec.fill {
        Some(NoFill) => ()
        _ => abort("expected no fill")
      }
    }
    _ => abort("expected outline element")
  }
  match page.elements[4] {
    ShapeElement(base, spec) => {
      assert_eq(base.id, "diamond")
      assert_eq(spec.shape, "diamond")
    }
    _ => abort("expected diamond element")
  }
  match page.elements[5] {
    ConnectorElement(id, spec) => {
      assert_eq(id, "flow")
      assert_eq(spec.kind, "straight")
      match spec.start {
        ElementEndpoint(target) => assert_eq(target, "panel")
        _ => abort("expected element start endpoint")
      }
      match spec.end_arrow {
        Some(arrow) => assert_eq(arrow, "triangle")
        None => abort("expected end arrow")
      }
      match spec.shadow {
        Some(shadow) => assert_eq(shadow.distance, 3.0)
        None => abort("expected connector shadow")
      }
    }
    _ => abort("expected connector element")
  }
  match page.elements[6] {
    IconElement(base, spec) => {
      assert_eq(base.id, "cube_icon")
      assert_eq(spec.name, "fas:cube")
    }
    _ => abort("expected icon element")
  }
}

///|
test "parse connector endpoint anchor" {
  let page = parse_page_yaml(
    (
      #|elements:
      #|  - id: "flow"
      #|    type: "connector"
      #|    content:
      #|      kind: "straight"
      #|      start: { element: "source", anchor: "bottom" }
      #|      end: { element: "target" }
    ),
  ) catch {
    err => abort("parse page failed: \{err}")
  }
  match page.elements[0] {
    ConnectorElement(_, spec) =>
      match spec.start {
        AnchoredElementEndpoint(target, BottomAnchor) =>
          assert_eq(target, "source")
        _ => abort("expected anchored start endpoint")
      }
    _ => abort("expected connector element")
  }
}
