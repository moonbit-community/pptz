///|
test "contain image placement preserves source aspect" {
  let placement = image_placement(
    Bounds::{ x: 0.0, y: 0.0, width: 400.0, height: 400.0 },
    ContainFit,
    Some(ImageSourceSize::{ width: 400.0, height: 200.0 }),
    None,
  ) catch {
    err => abort("placement failed: \{err}")
  }
  assert_eq(placement.bounds.x, 0.0)
  assert_eq(placement.bounds.y, 100.0)
  assert_eq(placement.bounds.width, 400.0)
  assert_eq(placement.bounds.height, 200.0)
  match placement.crop {
    None => ()
    Some(_) => abort("expected no crop")
  }
}

///|
test "cover image placement converts overflow to crop" {
  let placement = image_placement(
    Bounds::{ x: 0.0, y: 0.0, width: 400.0, height: 400.0 },
    CoverFit,
    Some(ImageSourceSize::{ width: 400.0, height: 200.0 }),
    None,
  ) catch {
    err => abort("placement failed: \{err}")
  }
  match placement.crop {
    Some(crop) => {
      assert_eq(crop.left, 0.25)
      assert_eq(crop.top, 0.0)
      assert_eq(crop.right, 0.25)
      assert_eq(crop.bottom, 0.0)
    }
    None => abort("expected crop")
  }
}

///|
test "svg size parser reads width and height" {
  let bytes = @miniio.read_file("examples/minimal/images/badge.svg") catch {
    err => abort("read svg failed: \{err}")
  }
  match image_source_size("images/badge.svg", bytes.binary().to_fixedarray()) {
    Some(size) => {
      assert_eq(size.width, 560.0)
      assert_eq(size.height, 110.0)
    }
    None => abort("expected svg size")
  }
}
