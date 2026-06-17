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
test "parser rejects unknown fields" {
  let message = deck_parse_error(
    (
      #|size: [1280, 720]
      #|pages:
      #|  - path: "pages/cover.page.yaml"
      #|camelCase: true
    ),
  )
  assert_true(message.contains("unknown field"))
}

///|
test "parser reports nested unknown field path" {
  let message = page_parse_error(
    (
      #|elements:
      #|  - id: "title"
      #|    type: "text"
      #|    bounds: [0, 0, 100, 100]
      #|    content:
      #|      text: "Hello"
      #|      extra: true
    ),
  )
  assert_true(message.contains("elements[0].content.extra: unknown field"))
}

///|
test "parser rejects paragraph text and runs together" {
  let message = page_parse_error(
    (
      #|elements:
      #|  - id: "title"
      #|    type: "text"
      #|    bounds: [0, 0, 100, 100]
      #|    content:
      #|      paragraphs:
      #|        - text: "Hello"
      #|          runs:
      #|            - text: "World"
    ),
  )
  assert_true(message.contains("use either text or runs, not both"))
}

///|
test "parser rejects unknown element type" {
  let message = page_parse_error(
    (
      #|elements:
      #|  - id: "mystery"
      #|    type: "video"
      #|    bounds: [0, 0, 100, 100]
    ),
  )
  assert_true(message.contains("unsupported element type"))
}

///|
test "parser rejects mixed table text color aliases" {
  let message = deck_parse_error(
    (
      #|size: [1280, 720]
      #|pages:
      #|  - path: "pages/cover.page.yaml"
      #|theme:
      #|  colors:
      #|    text: "#111827"
      #|  text_styles:
      #|    body:
      #|      color: "$text"
      #|  table_styles:
      #|    compact:
      #|      header_text_color: "$text"
      #|      header_color: "$text"
    ),
  )
  assert_true(message.contains("use either header_text_color or header_color"))
}
