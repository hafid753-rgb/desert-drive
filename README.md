# Desert Drive (prototype)

Top-down desert driving prototype, split out of the Hafid project. It
reuses Hafid's desert: the courtyard, oasis, dunes, Journey-style sand,
wind, dust, light and lens flare.

- **Main scene:** `game/drive/drive_test.tscn`. Arrow keys or the touch
  stick steer and accelerate; Space is the handbrake.
- **Teaser:** `godot --path . res://game/drive/drive_test.tscn -- teaser`
  runs drifts, the oasis pond, then getting stuck in soft sand.
- **Dune run:** `godot --path . res://game/drive/dune_run.tscn [-- teaser]`. A 1.3 km
  dune sea, crest jumps, a flooded sebkha (salt flat), crate walls and a
  shed that breaks apart (rigid-body physics). Video: `media/desert_drive_dune_run.mp4`.
- **The car** is an original voxel 1980s sedan built in code
  (`game/drive/voxel_car.gd`), with no brand marks.
- **The handling** is in `game/drive/desert_car.gd`; see `game/drive/README.md`.
- **Engine:** Godot 4.6, Mobile renderer, Android export preset.

The rest of `game/` is the shared Hafid desert code the scene depends on.
