# Mansion generators

`Scenes/mansion.tscn`, `Scenes/props/*.tscn` and `Materials/*.tres` are all
**generated**. Do not hand-edit them, and do not leave the scene open in the
Godot editor while regenerating — the editor writes the whole thing back on save
and will silently undo the build.

    tools/build.sh --bake          # the normal loop: generate, then bake to meshes
    tools/build.sh                 # generate only, leaving live CSG
    tools/build.sh --scene-only    # just the mansion (materials/props unchanged)
    tools/build.sh -o /tmp/x.tscn  # dry run somewhere else

`--bake` needs a Godot binary; set `GODOT=/path/to/godot` if it is not on PATH.

## What generates what

| file                | emits                                                    |
|---------------------|----------------------------------------------------------|
| `gen_materials.sh`  | `Materials/*.tres` — noise textures and every material    |
| `gen_gate.sh`       | `Scenes/Gate.tscn` + `gate_leaf.tscn` — the estate gate    |
| `gen_car.sh`        | RETIRED — the car is Models/car/Car.fbx now; refuses to run |
| `bake_bookshelf.gd` | merges the 149-mesh bookshelf to 3 draw calls and tints every book |
| `extract_pine.gd`   | pulls the pine mesh out of the FBX for the forest MultiMesh |
| `pines.pl`          | swaps the generated CSG conifers for one MultiMeshInstance3D |
| `gen_menu.sh`       | `Scenes/menu.tscn` — the whole title screen as real nodes |
| `gen_stormdoor.sh`  | `Scenes/storm_door.tscn` — the cellar doors in the ground  |
| `gen_steps.sh`      | `Scenes/steps_porch.tscn`, `steps_cellar.tscn` — outdoor steps |
| `steps.awk`         | that geometry: bluestone treads, brick risers, cheeks      |
| `gen_cellargate.sh` | `Scenes/cellar_gate.tscn` — the barred gate at the stair head |
| `gen_surroundings.sh` | `Scenes/surroundings.tscn` — woods, ground, hedging     |
| `gen_occluders.sh`  | `Scenes/occluders.tscn` — boxes for occlusion culling      |
| `gen_audio.sh`      | `default_bus_layout.tres`, `Scenes/audio.tscn` — buses, zones |
| `decode_mp3.gd`     | an mp3 to a mono WAV, by playing it and capturing the mix  |
| `cut_sfx.gd`        | `Audio/sfx/*.wav` — trims and levels the library effects   |
| `gen_sfx.gd`        | the synthesised effects, superseded; writes `sfx_synth`    |
| `gen_stalker_sfx.gd` | the creature's four sounds — the one thing with no library recording |
| `ringtime.gd`       | how tonally a step set rings — the pipe detector           |
| `noisefloor.gd`     | hiss and attack brightness of the cut step sets            |
| `crop.gd`           | crops a region out of a screenshot, for looking closely    |
| `cut_footsteps.gd`  | `Audio/steps/*.wav` — one file per footfall, three surfaces |
| `wavlib.gd`         | WAV read/write and the offline DSP the cut uses            |
| `check_steps.gd`    | proves the three step sets are measurably different        |
| `spectrum.gd`       | band energy of a source or a cut, for retuning             |
| `probe_floors.gd`   | every surface under a point — where the storeys are        |
| `probe_bounds.gd`   | world-space AABBs of the house and the cellar              |
| `probe_cellar_map.gd` | ASCII plan of the cellar — walls, doorways, landmarks  |
| `probe_cellar_paths.gd` | floods the cellar; proves one route to the generator |
| `probe_hunt.gd`     | walks the creatures — do four of them patrol a real forest |
| `test_vision.tscn`  | the lens tags everything — a SCENE, see below |
| `test_code.tscn`    | the safe combination and the trail of clues to it |
| `test_car.gd`       | the car arrives, on the animator, and a skip still lands |
| `test_wake.gd`      | the wake-up runs off its animation and ends on the rest pose |
| `test_intro.gd`     | the intro overlay is a scene, and the hand-over lands |
| `test_subtitles.gd` | the Subtitle size dropdown actually resizes the label |
| `test_hud.gd`       | the HUD is a scene, and its layout has not drifted |
| `probe_hitboxes.gd` | every collider measured against the mesh it is the shape of |
| `gen_door_sfx.gd`   | the big top door coming down, and the switch that drops it |
| `rebuild_shell.sh`  | **just** the shell + exterior meshes, in place             |
| `gen_items.sh`      | `Scenes/items/*.tscn` — one scene per carried object      |
| `items.awk`         | that geometry: crowbar, keys, fuse, cell, can, lens, book  |
| `gen_items.awk`     | picks which item `items.awk` builds, by `-v WHICH=`        |
| `gen_safe.sh`       | `Scenes/safe.tscn` and `Scenes/safe_dial.tscn`             |
| `gen_props.sh`      | `Scenes/props/*.tscn` — one scene per reusable prop        |
| `gen_props.awk`     | picks which prop `props.awk` builds, by `-v WHICH=`        |
| `props.awk`         | reusable furniture geometry (baked into the prop scenes)   |
| `builtins.awk`      | bespoke geometry: counters, hearths, rugs, curtains, clutter |
| `gen_header.sh`     | the scene header, from a scan of what the nodes reference  |
| `gen_shell.sh`      | the `Shell` combiner: slabs, walls, doorways, windows      |
| `gen_stairs.awk`    | both staircases: treads, ramps, balustrades, landing guards |
| `gen_exterior.sh`   | roof, porch, trim, shutters, chimney, foundation           |
| `gen_interior.awk`  | architectural trim, room layout, lighting                  |
| `lib.awk`           | transforms and node emitters shared by the awk parts       |
| `bake.sh` / `bake.gd` | turns the generated CSG into `Meshes/*.res` + MeshInstance3D |
| `check_facing.awk`  | warns about props that face into a wall (run by `build.sh`) |
| `check_zfight.awk`  | warns about coplanar faces from different combiners        |
| `parts/props.part`  | **hand-authored**: doors, pickups, clues, triggers         |

`parts/props.part` is the only piece that is not generated. It holds the nodes
carrying authored text and puzzle state — door locks, pickup items, readables,
dialogue triggers, the generator, the stair obstacle — because no table can
express those. Edit it directly.

## How the furniture is organised

Repeated furniture is **not** built into the scene. `props.awk` holds the
geometry, `gen_props.sh` bakes it into one scene per prop under `Scenes/props/`,
and `gen_interior.awk` instances those. The house was carrying sixteen separate
copies of a bookcase and seventeen of a table before that split; now a bookcase
is one file, and swapping a primitive for a modelled mesh later is a per-prop
job rather than a scene-wide one.

The trade is that a baked scene is **one fixed size**. The catalogue at the top
of `gen_props.sh` is a short menu — three bookcases, six tables — and the layout
picks the variant that fits rather than naming arbitrary dimensions. Anything
genuinely sized to its location (a run of kitchen cabinetry, a chimney breast, a
rug) stays in `builtins.awk` and is emitted inline.

Materials live in `Materials/` so the prop scenes and the mansion share them.
Changing a material is one file, not thirty-eight.

Each room gets three groups:

- `<Room>` — built-in carcassing, collision on
- `<Room>Dress` — rugs, pictures, ceiling fittings, clutter; **no** collision
- `<Room>Props` — instances of the baked prop scenes

All three are plain `Node3D`s, and **every item under them is its own
combiner**, opened by `group()` in `lib.awk`. The first two used to be one big
`CSGCombiner3D` each, which baked a room's entire dressing into a single mesh:
you could not move one candle, hide one picture or delete one pile of dust
sheets without regenerating the whole house, and in the editor a room selected
as one welded object. Now a rug is a node, a fireplace is a node, a door case
is a node. The cost is about thirty draw calls a room where there was one.

If you add a dressing function to `builtins.awk`, **open a `group()` first**.
A bare `CSGBox3D` under a room Node3D bakes to a mesh with no collision —
which is right for a rug and wrong for a heap of coal.

## Carried items

`Scenes/items/it_*.tscn` are the things the player picks up, generated by
`gen_items.sh` from `items.awk` and baked like the props. Each one is used
three times over: as the mesh on the pickup lying in the world, as the mesh
that spawns when the player drops it, and as the live 3D icon in the journal's
inventory grid. `Items/*.tres` points at them through `ItemData.model`.

One model for all three is the point. There is no icon atlas to keep in step
with the geometry, and an item cannot look like one object on the floor and a
different one in your bag.

Items are modelled to a tighter standard than furniture — a key fills half the
journal page, where a chair is only ever a silhouette at two metres — so they
use the tight-uv materials from the "carried items" block of
`gen_materials.sh` and real CSG subtraction for holes.

## The bake step

The generators emit CSG because CSG is a good way to *describe* geometry from a
table of numbers. It is a bad way to *ship* it: the scene was carrying ~215 live
CSG trees and the editor re-evaluates those on any change, which made it crawl.
`bake.gd` walks each generated scene, calls `bake_static_mesh()` on every CSG
root and swaps in a `MeshInstance3D` plus trimesh collision, writing the meshes
to `Meshes/`. Node names and transforms survive, so every NodePath still works.

Result: `mansion.tscn` goes from 1864 nodes of CSG to 374 nodes of meshes, and
`Scenes/props/pf_chair.tscn` from a 20-box combiner to a single mesh reference.

Baking is idempotent — a second run finds no CSG and does nothing.

## Things that have already bitten

**Transform3D is serialised ROW-major.** The three triples in a `.tscn`
`Transform3D(...)` are the matrix *rows*, not the axis vectors — unlike the
GDScript constructor. Getting this backwards transposes the rotation, which is
what made the first staircase slope the wrong way. `lib.awk` has `Tyaw`,
`Tpitch` and `Troll` so nobody has to think about it again.

**Props are built facing +Z**, at the origin. `open_prop` / `pbox` put a prop's
back at negative local Z. A yaw of 0 therefore faces +Z, 90 faces +X.

**CharacterBody3D has no step-up.** The player walks on the ramp colliders under
each flight, not on the treads; the treads have no collision at all.
`gen_stairs.awk` derives both from one pair of endpoints so they cannot drift.
The same rule is why rugs, pictures and table clutter live in the `*Dress`
combiners: a 2cm rug lip would stop the player dead at the edge of every carpet
in the house.

**A ramp may only overhang at its bottom end.** Extending the top end raises the
walking surface above the landing and puts an invisible lip in the floor.

**CSG cuts only apply inside their own combiner.** `CutCellarWell` lives in the
`Shell`, so it never touched `Exterior/Foundation`, and a solid 34.8×34.8
foundation slab sealed the cellar stairwell shut — the basement was unreachable
for the entire demo. The foundation is a ring now. Anything that needs to be cut
by the shell has to be a child of the `Shell` combiner. The same thinking keeps
ceiling joists out of the stair wells: nothing cuts them, so they are emitted in
spans that stop either side.

**Wall trim has to break around openings.** Skirting, dado and wainscot run
below every door head, so `gen_interior.awk` registers each hole with
`opening()` and `wallsegs()` splits the run. Skip that and you look into the
next room over a solid panelled wall. Cornice and picture rail sit above the
heads and run unbroken.

**`material`, never `material_override`.** The override is a render-time thing
that the CSG bake does not carry into the mesh, so anything using it comes out
untextured white. The collapsed bookcase on the stairs did.

**A prop instance must not be a child of a CSG combiner.** It gets folded into
the combiner's brush, and the bake then swallows it whole — eight prop types
vanished from the house that way. Instances live in the `<Room>Props` node.

**A wall run is named by which wall it is, not which way it faces.** The first
version took the facing direction and every north/south run was labelled
backwards, which buried the skirting and wainscot inside the wall. `sideyaw()`
takes N/S/E/W meaning the wall's position in the room.

**Two nodes with the same name bake to the same file.** `MainStairs/Steps` and
`CellarStairs/Steps` collided, and the loser ended up embedded in the scene as
700KB of text. `bake.gd` keys mesh files on the full node path.

**A tabletop is placed at the height its face lands at, not at the height it
is centred on.** Four things in the house were out by exactly the thickness of
the furniture under them: the mantel candlesticks were 4cm *inside* the marble,
the piano candlestick 3cm into the lid, a cellar bottle floated 9cm above its
shelf. `builtins.awk` now has a `TOP_*()` per surface — `TOP_mantel()`,
`TOP_piano()`, `TOP_counter()` — and `gen_interior.awk` uses those instead of
numbers. Add a new surface, add a `TOP_`.

**Euler angles compose as Ry·Rx·Rz, so a second rotation channel is not a
second free axis.** The safe dial was a cylinder pitched -90° about X that the
script spun by setting `rotation.z`; with the pitch already in place, a Z angle
turns the disc about its own *sideways* axis and it tumbled end over end like a
flipped coin. Neither channel gives a true spin once a pitch is present. The fix
is structural: `safe_dial.tscn` puts the pitch on a `Spin` node and leaves the
`Ring` square, so Ring's local Y really is the cylinder's axis.

**No `uid=` in the generated header.** A uid that is not in the project's
`uid_cache.bin` makes Godot warn "invalid UID … using text path instead" on
every load, and the cache goes stale whenever a script arrives outside the
editor. Paths always resolve.

**A generator that writes a `.tres` must re-emit the uid that file already
had.** Drop it and the editor assigns a fresh random one on the next import,
while every already-baked mesh in `Meshes/` goes on referencing the previous
one — so Godot falls back to the text path and warns, once per reference. One
run of `gen_materials.sh` was worth 120 warnings in the error panel that way.
`keep_uid()` in that script reads the uid back off the old file; note that it
is called *before* the `{ ... } > file` block, because the redirection
truncates the file first and a lookup from inside the block reads an empty one.
The 23 material uids the baked meshes depend on are therefore load-bearing:
`Materials/*.tres` can be regenerated freely, but the first line of each must
not change.

**A `roughness_texture` multiplies the roughness value.** A mid-grey noise map
roughly halves it, so 0.5 plus a map lands near 0.25 — lacquer. Base values in
`gen_materials.sh` are chosen knowing that.

**`cond && cmd` as the last statement of a shell function** returns 1 when the
condition is false, which `set -e` treats as failure. Use `if`.

## Checking the result

`tools/build.sh -o` somewhere, point a Godot copy at it and walk the house.
`build.sh` refuses to write if a node's parent is missing or a `SubResource` is
undeclared, because Godot reports those as a warning per node and then silently
drops half the house.

A flood-fill walkability probe was used to find the sealed basement; if a room
ever becomes unreachable again, that is the tool to rebuild — raycast down on a
0.25m grid, test the player capsule seated along the surface normal (not
straight up, or every ramp reads as solid), then flood from the spawn.

**Two solids from different combiners must never share a face plane.** The
depth buffer cannot separate them and which one wins flips as the camera
moves, which is the shimmer people report as "the textures are flickering".
Inside one `CSGCombiner3D` it is harmless -- the boolean resolves the
coincidence before anything is rasterised -- so this is specifically a
cross-combiner problem, and the house is full of pairs that qualify: the
Shell's walls against the Trim's architraves, the Exterior's window jambs
against the Interior's window linings, the Deck against the foundation.

`tools/check_zfight.awk` finds them and `build.sh` runs it on every build. It
reports same-facing coplanar pairs with real overlap area, skipping undersides
(everything in the house rests on the same floor plane and none of those faces
is ever drawn). The rule of thumb when it fires: do not make two things flush,
make one of them overlap the other by a few millimetres.

**Do not case the same opening twice.** The house has exactly one door-case
builder, `doorcase()` in `gen_interior.awk`, and the front door's outside face
is cased by `gen_exterior.sh` instead -- hence the `faces` argument. A second
set of architraves was once added from `builtins.awk` in its own combiner, and
every doorway in the house carried two of them, 20cm apart.

**A door case is positioned on the wall CENTRELINE and told the wall's full
thickness.** Internal partitions are 0.3. The front and back walls are two
0.2 skins either side of the centreline and so are 0.4 through. The front
door was cased at -0.20 -- an inner face, not a centreline -- so its surround
came out 0.2 adrift in both directions.

## Once the house has been arranged by hand

`build.sh` **refuses to run** on a `Scenes/mansion.tscn` that has been baked
and then edited — it checks for CSG and stops if there is none, because
regenerating throws away every piece of furniture that was moved in the
editor. That has already happened once.

What to use instead, in order of how much you are changing:

| you want to change | use |
|--------------------|-----|
| one thing in the house | edit `Scenes/mansion.tscn` |
| a wall, a window, the roof | `tools/rebuild_shell.sh` |
| the yard, the woods, the gate, the car | the `gen_*.sh` for that scene |
| the whole layout, from scratch | `FORCE=1 tools/build.sh --bake` |

`rebuild_shell.sh` works because the building is two nodes pointing at two
mesh files. It regenerates `Meshes/mansion_{Shell,Exterior}{,_col}.res` and
leaves the scene alone, so the shell can be changed under a hand-arranged
interior without disturbing it.

`bake.gd` also takes `BAKE_ONLY=res://Scenes/foo.tscn` to bake a single scene.

## Adding something to the hand-arranged house

The steps and the cellar gate are the pattern to copy. Each is a small
generator that writes ONE scene in **mansion-local coordinates**, bakes it,
and is then instanced in `mansion.tscn` at the origin with no transform:

    GODOT=/path/to/godot tools/gen_steps.sh
    GODOT=/path/to/godot tools/gen_cellargate.sh

Instancing at the origin rather than positioning the instance is deliberate.
The mansion sits at world `(0, 0.35, -41.5)`, so mansion-local is the frame
every other number in this directory is written in, and a piece placed by its
own coordinates cannot drift when somebody nudges the instance in the editor.
The conversions worth remembering:

| mansion-local | world | what it is |
|---|---|---|
| `y  0.00` | `0.35` | ground floor, and the porch deck |
| `y -0.30` | `0.05` | the lawn |
| `y -3.60` | `-3.25` | the cellar floor |
| `z  4.00` | `-37.50` | the front edge of the porch deck |
| `z -26.80` | `-68.30` | the head of the cellar stairs |

## Checking it by machine

Things in `tools/` that run headless and print PASS / FAIL:

    godot --headless --path . --script tools/probe_walk.gd     # can you get there
    godot --headless --path . --script tools/test_cellar.gd    # the key puzzle
    godot --headless --path . --script tools/test_controls.gd  # the input map
    godot --headless --path . --script tools/test_sprint.gd    # running
    godot --headless --path . --script tools/test_journal.gd   # every book page builds
    godot --headless --path . --script tools/test_menu.gd     # the title screen
    godot --headless --path . --script tools/test_audio.gd    # zones, bed, footsteps
    godot --headless --path . --script tools/test_safe.gd     # you can get back out of it
    godot --headless --path . --script tools/test_stamina.gd  # the tank and the bar
    godot --headless --path . --script tools/test_ending.gd   # the book ends the demo
    godot --headless --path . --script tools/test_held.gd     # the in-hand corner
    godot --headless --path . --script tools/test_sfx.gd      # effects, and the loops loop
    godot --headless --path . --script tools/test_hunt.gd     # the thing in the woods
    godot --headless --path . --script tools/test_door.gd     # the way into the big top
    godot --headless --path . --script tools/test_car.gd      # the arrival, end to end
    godot --headless --path . --script tools/test_wake.gd     # waking up in the woods
    godot --headless --path . --script tools/test_intro.gd    # the opening overlay and hand-over
    godot --headless --path . --script tools/test_subtitles.gd # the subtitle size setting
    godot --headless --path . --script tools/test_hud.gd       # the HUD scene, pinned to the pixel

Two of them are SCENES, not --script tools, and that is load-bearing:

    godot --headless --path . tools/test_vision.tscn   # the lens tags everything
    godot --headless --path . tools/test_code.tscn     # the safe and its clues

A `--script` SceneTree adds its level before the autoloads have finished
starting, so VisionTags' `refresh_tags()` sweeps a tree that is already
complete and everything looks tagged whatever the truth is. The real game loads
autoloads FIRST and the main scene after, so tagging rests entirely on the
`node_added` signal. Both bugs those files cover passed a `--script` check
while being completely broken in the game.
    godot --headless --path . --script tools/test_carry.gd    # the lens survives a level change
    godot --headless --path . --script tools/probe_cellar_paths.gd  # one route to the generator
    godot --headless --path . --script tools/probe_hunt.gd    # ...and it walks a real forest

`probe_walk.gd` is the flood fill this file used to only describe. It rays
down on a 0.2 m grid, keeps EVERY surface in each column, joins the ones the
player could step between and floods from the spawn.

    MAP=1 ...                       print a plan of what is reachable
    TRACE="the entrance hall" ...    print the route it took to get somewhere
    SEED="the head of the cellar stairs" ...  flood from there instead
    SHUT_GATE=1 ...                  leave the cellar gate locked

Four things it has been wrong about, all of them worth knowing:

- **One surface per column is not enough.** A ray from above stops on the
  ground-floor slab, so the cellar was invisible to it and it reported the
  house reachable while a slab lay across the cellar stairs.
- **0.5 m is too coarse.** A three-riser stoop climbs 0.17 m per cell at that
  pitch, which is indistinguishable from a wall.
- **A point is not a body.** A dimensionless flood walks through the bolted
  front door, because the leaf is 1.30 m in a 1.75 m opening. It tests the
  player capsule now.
- **...but only the capsule from the knee up.** The whole capsule, lower
  hemisphere and all, overlaps any kerb beside it, which turned every kerb in
  the level into a wall. Vertical movement is the rise test's job.

`tools/route.tscn` is the ground truth the grid only approximates: it drives
the REAL player body along a list of waypoints with `move_and_slide` and says
where it got stuck.

    ROUTE=stairs godot --path . tools/route.tscn

`tools/shot.gd` + `shot.tscn` render a still of any scene from anywhere:

    SHOT_SCENE=res://demo_level.tscn SHOT_CAM=0,1.6,-33 SHOT_AT=0,0.9,-38 \
    SHOT_OUT=/tmp/x.png godot --path . --resolution 1280x720 tools/shot.tscn

It frees the `Intro` node first -- the cutscene takes the camera and fades to
black, so every shot of the level came out as a black frame -- and
`SHOT_LIGHT=1` clips a lamp to the camera for the cellar, which is genuinely
pitch dark.

## Every cutscene runs off an AnimationPlayer

There are three, and none of them builds its choreography out of tweens any
more. The split is the same in all three: **the animator owns timing, easing
and running order; the script owns the geometry a keyframe cannot know.**

| cutscene | animation | what the animation writes |
| --- | --- | --- |
| `WakeUp.gd` | `Scenes/anim/wake.tscn` | `look`, `stand`, `sway` |
| `Intro.gd` | `Scenes/ui/intro_overlay.tscn` | the Control fades, keyed directly |
| `BookEnding.gd` | `Scenes/anim/book_ending.tscn` | `lean`, `lift`, `book_rise`, `retreat`, `glow`, `book_lift`, `throw`, `flare`, `pull`, `tunnel_run`, `tunnel_clear`, `fall` |

Each animation is instanced as a child called `Anim`, so its tracks address
`.:property` on the cutscene node and the owning level needs one line. The
intro is the odd one out: its overlay was ninety lines of Control construction
inside the script, so the whole overlay became a scene and the fades are keyed
on the real Controls.

**A keyframe cannot know where this player's eye is.** Each phase captures what
it needs first -- the rest pose, the direction to the book, which way the book
must turn to face the player -- and the animation then writes a plain 0..1
float that a setter turns into a pose. That split is what lets a curve live in
a .tscn at all, and it is why the shape exports (`down_height`,
`lean_distance`, `rise_tilt`) survive while the duration exports did not.

**ONE WRITER AT A TIME.** A value track writes every frame, clamped to its
first key, so a track whose phase has not started yet still stamps its opening
value over whatever owns that property now. `sway` would flatten the roll
`stand` is easing out; `tunnel_run` would slam the tunnel to full while `pull`
is still dragging the camera in; `glow` would pull the explosion back to a
gentle flicker. Each of those setters returns early until its phase owns the
property. If a cutscene grows a one-frame twitch, look here first.

**Hurrying one in a test means `speed_scale`, not the exports.** The durations
are keys now. `test_cutscene.gd` and `test_circus.gd` both run the animation at
60x. Setting a `*_time` export instead does nothing except raise an error that
swallows the rest of the test's stage -- which is how `test_circus.gd` came to
print one passing assertion 6042 times and still report zero failures.

## The car is a model, and .tscn comments do not survive

`Scenes/car.tscn` is `Models/car/Car.fbx` now -- a hand-modelled 1930s coupe --
and `tools/gen_car.sh` is retired and refuses to run. The numbers that matter,
because there is nowhere in the scene file to write them down (see below):

  * **scale 0.48.** The model is 10.56 x 5.43 x 3.70 in its own units, which
    comes out 5.07 long, 2.61 wide and 1.78 tall. The car it replaced was
    5.10 x 2.14 x 2.05, so the LENGTH matches and the approach still reads the
    same; it is half a metre wider across the flared wings, which the 15 m road
    in `demo_level.tscn` and the 6.8 m one on the title screen both swallow.
  * **lifted 0.2894** (= 0.603 * 0.48), the wheel bottom, so the tyres sit on
    y = 0 -- both scenes place the car on the road surface, not in it.
  * **it faces -Z**, the same way the old one did, so nothing needed turning.
  * **the lamps moved with it.** The headlamp pods are at x +/-0.958, y 1.394,
    z -4.152 in model units, so the beams sit at x +/-0.46, y 0.96, z -2.12 --
    just clear of the pod face at -2.084. The glass runs z 0.34..4.47, so the
    dome lamp is at z 1.15.
  * **the wheels do not spin, and nothing is lost by it.** All four are one
    mesh, so `CarArrival._ready()` finds no child called `Wheel` and the spin
    loop does nothing. They are smooth 32-segment revolves -- no spokes, no
    tread, no lug nuts -- so a turning wheel is pixel-identical to a still one.
    Put a valve stem or a spoke on one and it becomes worth splitting the mesh
    into four `Wheel` nodes.
  * **materials**: body `Mat_carnavy` (new -- the model's own navy, wearing the
    house grain), windows `Mat_carglass`, wings and running boards and lamp
    housings `Mat_carpaint`, tyres `Mat_tyre`, hubcaps `Mat_chrome`, whitewalls
    left as the model's own white. Assigned per-mesh on an editable instance,
    because the importer has no material names to key on.

### Godot strips every comment from a .tscn it re-saves

It also stamps each node with a `unique_id=`, which is how to tell: a scene
file with `unique_id=` in it has been through the editor or the importer and
has NO comments left, whatever was written in it. `mansion.tscn` (475 ids) and
`Scenes/props/pf_armchair_leather.tscn` (4) lost theirs long ago;
`Scenes/car.tscn` lost its on the import that brought the model in.
`fall_door.tscn` and `pf_generator_model.tscn` have never been re-saved and
still carry their 41 and 23 lines.

So: **a .tscn is not a place to document anything that matters.** It goes in
the generator that writes the scene, in the script attached to it, or here.
`Scripts/CarArrival.gd` carries the note about where the arrival animation
lives for exactly this reason.

## The cellar is a corridor, not a ring

There is exactly ONE route from the cellar door to the generator: west and
south through `CutBasementCross2` at (-9, -22), then east through
`CutBasementMid` at (0, -14). `tools/probe_cellar_paths.gd` proves it rather
than asserting it — it blocks each doorway in turn and checks the generator
goes out of reach. A doorway on the route that can be blocked without
disconnecting the generator means a second path has appeared.

It used to be a ring, three ways round, for two reasons that both looked
harmless in the table:

- **`BS_Mid` stopped at z=-28** while the cellar runs to z=-33.8, so the
  northern six metres were open right across x=0. That is not visible anywhere
  in the wall list; you only see it by scanning the wall for gaps.
- **`CutBasementMid2` (0, -26) and `CutBasementCross` (9, -22)** closed the
  loop. Mid2 in particular sat five metres from the iron gate and let you walk
  straight round it.

The iron gate now stands in the mid wall at (0, -30.99) as its only opening.
The doorway is cut 4.4 m against the gate's 4.6 m jamb-to-jamb, so the gate's
two fixed side panels bury 0.1 m into the masonry instead of meeting it face to
face — coplanar faces are what `check_zfight.awk` exists to complain about.

**The key cannot live behind the gate it opens.** `cellar_key` was in the coal
heap at (15, -31.3), which is on the far side of that wall: once the gate was
the only way through, the key was locked behind the lock it opened and the
house became unreachable forever. It is in `SearchBarrels` (-15.6, -23.6) now,
on the entry side. The chain is: in at the cellar door, west and south to the
generator, lights on, search, key, back up to the gate, through it to the
stairs. `test_cellar.gd` looks up whichever spot holds the key rather than
naming one, so moving it again does not break the test.

## Cylinders could not lie down, and everything round in the house was wrong

`cyl()` in `lib.awk` took a `yaw` and nothing else. A `CSGCylinder3D` points
along its own Y axis — so yawing one spins it about the very axis it already
points down, which does precisely nothing to its orientation. **Every cylinder
in the house was structurally incapable of being anything but upright.**

That is not a cosmetic slip, it is a missing degree of freedom, and it was
quietly wrong in every fitting that needed a horizontal round part:

| what | was | is |
| --- | --- | --- |
| chandelier arms | six brass posts standing on the hub | arms radiating to each candle |
| sconce arm | a pin standing on the wall plate | an arm projecting from the wall |
| range handle | a post up the oven door | a rail across it |
| sink spout | a second pin behind the basin | a spout reaching over it |

The big wheel hub and the trailer wheels were wrong the same way and were fixed
too; they went when the fairground did.

The fix is `rx`/`rz` on `cyl()` and `pcyl()`, which meant lifting the rotation
maths out of `items.awk` and into `lib.awk` where `cyl()` could reach it. The
rule worth remembering, because it is not guessable from the two rotations on
their own:

    rx = 90              lays a cylinder along +Z
    rz = 90              lays it along -X
    rx = 90, rz = a-90   lays it along a horizontal bearing `a` from +X

That last one is what every radial fitting wants — chandelier arms, wheel
spokes, anything spoked or splayed.

The car and the storm door were always right, because they were built with
`icyl`/`dcyl`, which had full rotations from the start.

## Presentation belongs in the engine, mechanics belong in code

The rule: **if a designer would want to drag it, it should be a resource in a
scene.** Layout, keyframes, easing, the timing between a door landing and the
dust going up — none of that wants to be a number buried in an export where
nobody can see it.

The falling big top door is the worked example. It used to be a tween plus an
`await` on a `SceneTreeTimer`, so the door turned in one place, the dust fired
in another, and the relationship between them existed only as `dust_at = 0.82`.
It is now an `Animation` in `Scenes/fall_door.tscn`: five rotation keys for the
fall, and two **method tracks** that call `_burst()` and `_landed()`. The whole
choreography is one editable resource, and `drop()` is `_anim.play("fall")`.

**Not every tween should become an animation, and converting the rest would be
a mistake.** An `Animation` is fixed keyframes. These are not:

| stays in code | because |
| --- | --- |
| `BookEnding` (13 tweens) | aimed at a point computed from where the player is standing |
| `TokenGate`, `LeverLock` | slide to `position + offset`, unknown until it runs |
| `Stalker` voice | pitch and volume track a continuous awareness value |
| `Ambience` | audio crossfades driven by which zone you are in |
| `Lever`, `Door`, `Cabinet` | the angles are per-instance exports and genuinely vary |

Those are tweens because the target is not known until the moment it starts,
which is exactly what a tween is for. Forcing them into keyframes would mean
baking in values that are supposed to be live.

**Still to do: the UI.** `InteractionHUD.gd` (584 lines) builds 19 Control
nodes in code, `Journal.gd` (795) builds 21, `KeybindsPanel.gd` (263) builds 8.
All of that structure — panels, labels, anchors, StyleBoxFlat — should be a
`.tscn` with the scripts reduced to `@onready` lookups and behaviour. The
menu already works this way, which is the pattern to copy. It is a real
refactor rather than a tidy-up, and half-doing it leaves the game unplayable,
so it wants its own pass.

## Bringing in a modelled asset

`Models/` holds the hand-modelled assets — chair, couch, tablechair,
walllight, oillamp and generator. Everything else in the project is generated.
Between them they have replaced every seat, every light fitting and the
generator: the club chair for the four armchairs, the couch for the sofa, the
dining chair for all fifteen `pf_chair`, the lantern for nineteen sconces, the
oil lamp for eight, and the generator for the baked hull in the cellar.

**An FBX can smuggle things in.** The dining chair carries a
`DirectionalLight3D` called `Sun` inside it, left over from the Blender scene.
Instanced fifteen times that is fifteen suns, and it would have flattened the
lighting of the whole house with nothing obviously to blame. `_subresources`
in the `.import` skips that node:

    "nodes": { "PATH:Sun": { "import/skip_import": true } }

Check what is actually in a model before instancing it — `probe_hitboxes.gd`
would not have caught this one, and a screenshot of one chair would have looked
fine.

**Replacing the visual of something the game RUNS on is a different job.** The
generator is not furniture: it carries `Generator.gd`, the fuel check, the
starter prompt and the NodePath to the cellar lights. So the model went in as
a child of that node and the baked hull came out; the script, the collider and
every export stayed exactly where they were. Check afterwards that it is still
an `Interactable`, still in the group, still has an enabled collider and still
has its targets — a prop that looks right and no longer works is worse than one
that looks wrong.

**A model with no texture is not a model with no material.**
 The wall light and
the oil lamp both arrived bare, to be dressed in what the house already owns —
`Mat_brass` for the metal, `Mat_glass` for a chimney, `Mat_lamp` (the emissive
one the festoon bulbs use) for anything that is meant to be lit. That is better
than a bespoke texture per fitting: the brass matches the chandeliers it shares
a room with, for free.

Those two could not be mapped through the importer the way the leather was,
because their meshes carry **unnamed** materials — there is no name to key on.
They are assigned per-mesh on an editable instance instead, which is still data
in a scene rather than a script reaching in at runtime.

**Two materials, one atlas.**
 That model names its surfaces `Wood` and
`Material.001` and gives them different diffuse tints, but both are mapped to
the same texture and the atlas already carries the colour. Both names point at
one `.tres` with a neutral base, so the tints cannot fight the texture.

**Pieces of a set must share a scale.** Both models arrive 2.421 x 2.202 in
their own units and differ only along their length — the couch is the chair
stretched. Scaled differently they end up in the same room with different seat
heights and different arm thicknesses, which reads as a mistake instantly. So
`pf_sofa_leather` tracks whatever `pf_armchair_leather` is set to, and the
comment in each says so.

Four things had to be corrected, and **none of them belong in the .fbx**, which
is overwritten every time the model is re-exported:

- **The material.** The FBX carries a material named `Leather` with no maps on
  it. `Chair.fbx.import` maps that name to `Models/chair/leather.tres` through
  the importer's `_subresources`, so the mesh arrives already wearing it and
  anything that instances it gets the skin for free. Not a `material_override`
  in the prop, and not a script — the engine has a slot for exactly this.
- **The import flags.** A normal map has to be imported *as* one or Godot
  compresses it like colour and the lighting goes mushy at glancing angles, and
  roughness is data rather than a picture so it must not get an sRGB curve.
- **The scale.** It arrives 2.42 x 2.20 x 2.80 in its own units.
- **The origin and the facing.** Its bounds are not centred on its own origin,
  and it is modelled facing +X where every prop in this house faces +Z.

**Measure the vertices, not the AABB.** `get_aabb()` through a rotated
transform returns the axis-aligned bound *of the rotated box*, which is
inflated — it reported this chair as 4.41 m tall. Walking the actual vertices
gave 2.202, and the difference is the whole of the fitting.

## Hitboxes, and a probe that does not cry wolf

`tools/probe_hitboxes.gd` instantiates every scene in `Scenes/` and measures
each collider against the mesh it is supposed to be the shape of. Two numbers,
because neither alone works: a 3x ratio on a 2 cm plaque is nothing, a 1.4x
ratio on a 9 m door is most of a metre of invisible wall.

It found the wall switch carrying a collider 1.1 m deep pushed 0.4 m forward,
for a switch 0.28 m deep — half a metre of invisible wall in the air in front
of the only door out of the level — and the creature wearing a capsule three
times its own thickness, which is what kept snagging it on trunks.

Five scenes are exempt, with the reason written next to each: a whole level is
not an object, the player's "mesh" is the glass held in front of the camera,
and the porch and cellar steps carry a deliberately thick ramp buried under the
treads because `CharacterBody3D` has no step-up. A probe that reports four
known-fine things every run teaches everyone to ignore it.

## Two ways to be invisible, and both of them happened

**The lens stopped showing anything, and nothing reported it.** Two separate
causes, one shape: `VisionTags` only ever looked once, and only at what the
scene declared.

- A pickup carries a placeholder box in its scene. In `_ready` it throws that
  away and instantiates the real item model — which is strictly after
  VisionTags tagged the placeholder. So every item had a dozen meshes and not
  one of them carried the overlay. `Pickup._build_visual` now asks to be
  tagged again once there is something to tag.
- Group membership written into a `.tscn` is lost whenever a node is rebuilt
  or the scene is re-saved by hand. Six of the mansion's twenty-seven
  interactables had lost it, the debris across the stairs among them.
  `Interactable._enter_tree` now joins the group in code, so a scene cannot
  forget. In `_enter_tree` rather than `_ready` because five subclasses
  override `_ready` and cannot all be relied on to call `super()`.

Both failures are completely silent — no error, no missing resource, nothing in
the source that looks wrong. The thing simply stops existing to the one tool
the game is built around. `tools/test_vision.tscn` counts meshes rather than
trusting that the system is wired up.

## The safe combination is rolled fresh every run

**The puzzle was already here and it is a good one.** A note pinned in the
dining room, in handwriting too small to read without the glass, says:

> In order, left to right: the hour the clock died. The last figure on the
> newest portrait. And however many marks she cut into the bureau.

Three objects, three rooms, and the note is the only thing that gives the
order. The player needs the lens to read it, has to work out which portrait is
the newest, and has to count.

**One link was missing, and it was fatal.** The bureau's `reveals` named
`Lid/TallyClue` and no such node had ever been built. Opening the bureau
revealed nothing, the third dial existed nowhere in the world, and the safe
could not be opened by fair means — the only way in was to already know the
answer. Nothing reported it: no error, no missing resource, just a NodePath
pointing at a hole.

`Scripts/SafeCode.gd` now rolls all three numbers on every run and writes them
back into the clock, the portraits and the tally, so the answer cannot be
looked up once and known forever. The one rule it follows: **every number it
picks is written into all three sources AND into the lock.** A clue that
disagrees with the lock is worse than no clue, because the player trusts it,
tries it, and concludes the game is broken.

`tools/test_code.tscn` guards exactly that, by solving the puzzle the way a
player does — read the hour off the clock, find the newest portrait, count the
marks — and then checking that what it worked out actually opens the safe.

## The walk ends at the tent

There used to be a fairground between the woods and the big top: its own level,
handed over to two thirds of the way down the walk. It is gone. It was a second
place grafted onto the front of the first — the player crossed 500 m of forest
toward a circus tent and was then made to walk a fair before they could reach
it, and the moment of arriving happened twice, weakly, in two different places.

So the route runs to the canvas now, 512 m of it, and platform three is the
BACK OF HOUSE rather than a show: the stakes the guy lines are pegged to, the
flight cases the rigging came out of, and a cable feeding whatever is lit
inside. Nobody sells anything at the back of a tent. `tent_yard()` in
`circus.awk`.

**The way in is a switch and a door that falls.** A knife switch low on the
canvas — the one piece of machinery out there built for someone the player's
size, when everything else in this game is a counter over their head — drops
nine metres of braced timber flat, with dust and splinters and a crash built in
four layers. `Scripts/FallDoor.gd`, and it is the only thing in the level made
of real nodes rather than CSG, because a baked mesh keeps its vertices in world
coordinates and cannot be turned about its own bottom edge.

Its collision has to *go* once it is down: a panel lying flat is still 0.35 m
thick and `CharacterBody3D` here has no step-up, so the player would walk up to
the fallen door and stop dead against it. `tools/test_door.gd` covers all of
that, and `probe_circus.gd` drops the door before walking so the route check
asks the honest question — can the player get through once they have done what
the level asks.

## The thing in the woods

The circus level's first two platforms are a stealth loop, and the whole of it
rests on one asymmetry: **the creature is invisible, and the lens is the only
way to look at it.** Everything else exists to keep that trade honest.

`Scripts/Stalker.gd` is one creature. `Scripts/Hunt.gd` is the director that
owns all of them and decides what a catch costs. `Scenes/stalker.tscn` is the
body. `tools/circus.awk` generates the arenas and the patrols; the four lines
of `HW[]` / `HN[]` at the top of `gen_circus.sh` are the only place any of it
is configured — move a waypoint number there and the clearing, the markers,
the thickets and the creature all move together.

Four things that are the way they are on purpose:

- **Awareness is a number, not a state.** It fills while the player is exposed
  and drains while they are not, so half a second in the open is survivable
  and standing still in the open is not. States are bookkeeping on top of it.
  Without this, every sighting is instant and the level is a stealth game with
  no margin, which reads as unfair rather than tense.
- **It is slower than a sprint.** 4.6 against the player's 5.0. Running buys
  distance and costs stamina, so escaping means "sprint until you can break
  line of sight", not "hold shift". A creature faster than the player removes
  the decision and just punishes being seen.
- **It breathes, and the breath loops.** An invisible enemy that is also
  silent can only be found by walking the level with the lens up, which is
  slow and narrow and would make the glass a tax instead of a tool. The breath
  is what tells the player *when* to raise it. This is also the most fragile
  part of the feature: see the note in `gen_stalker_sfx.gd` about the WAV
  importer's loop mode, which fails silently and takes the whole mechanic with
  it.
- **Glades, not corridor.** `glade()` registers a clearing before `forest()`
  runs and the trees keep out of it. In a 9 m corridor every creature is a
  tollbooth — wait for it to turn, walk past. Open ground with cover in it
  turns the same creature into a choice about which side to take.

Two failure modes are worth knowing because neither shows up in play:

- **A creature wedged against a trunk** is worse than no creature: the player
  learns the woods are safe and the level goes slack. `_stuck` gives up on a
  marker after a few seconds of no progress, and `probe_hunt.gd` drops four of
  them into the real forest and checks they get round.
- **Two catches on one frame** produce two fades, a respawn landing mid-fade,
  and a black screen with no controls — which reads as a hang. `Hunt` is the
  single writer for a death and drops the second. `test_hunt.gd` covers it,
  because a convergence is not something a playtest reliably produces.

## Audio

Three things, and they are deliberately not solved the same way.

**The bed** (`Audio/ambience.mp3`) is one recording, filtered at runtime. Going
indoors does not change what the weather is doing — it puts a wall between the
player and it — so there is no second recording. `Scripts/Ambience.gd` closes
the Ambience bus's low-pass from 20.5 kHz on the lawn to 1.1 kHz in the hall to
420 Hz in the cellar, drops the level, and brings the bus reverb up. The cutoff
is swept **in log space**: a linear sweep from 20500 to 420 spends nearly all
its time in the top octave where nothing is audible and then falls through the
entire useful range in the last few milliseconds, which sounds like a switch
being thrown rather than a door closing.

The bed is 10.15 s and was not authored as a loop, so it is **not** looped. Two
`AudioStreamPlayer`s crossfade past each other before the first runs out. No
importer setting can fix an arbitrary end meeting an arbitrary start; there is
no loop point that makes those samples line up, and the click is there every
ten seconds forever if you pretend otherwise.

**The footsteps** are the opposite call: three sets of baked files, not one set
through a filter. A bus effect can make a sound duller, and duller is not what
a different floor is. Boards ring at 150 Hz and gravel does not; a cellar
answers off the far wall 68 ms later and a lawn has nothing to answer with.
`tools/cut_footsteps.gd` finds the fifteen footfalls in the raw take and bakes
each one three times:

    godot --headless --path . --script tools/cut_footsteps.gd

|          | length | attack air >2k | body <250 | tail past 150 ms | tail hiss >2k |
|----------|--------|----------------|-----------|------------------|---------------|
| `out`    | 218 ms |           9.0% |     25.2% |             0.1% |        -78 dB |
| `house`  | 631 ms |           0.2% |     29.8% |             4.9% |        -91 dB |
| `cellar` | 865 ms |           0.3% |     57.8% |            13.5% |        -95 dB |

Brightness is measured over the first 60 ms and hiss over the last quarter, on
purpose. Measured over the whole file, a set whose grit decays in 35 ms looks
dull — which is the opposite of what it sounds like. `tools/noisefloor.gd`
prints both.

**The zones** are Area3Ds in `Scenes/audio.tscn`, not a test on the player's Y
coordinate, so the house can move without anybody remembering to update a magic
number. They are split just under the ground-floor slab; the heights come from
`tools/probe_floors.gd`, which casts down through the house and prints every
surface it passes (lawn 0.05, ground floor 0.35, upper floors 3.95 and 7.55,
cellar floor -3.25).

### The effects are library recordings

`Audio/sfx/` holds six short effects cut from Pixabay recordings by
`tools/cut_sfx.gd`, plus two long looping ones left as mp3. The synthesised set
that preceded them is still in `tools/gen_sfx.gd`, writing to `Audio/sfx_synth`,
and is not used — its engine and creak recipes are worth keeping even though
they did not survive contact with an ear.

**A library recording is not a game asset.** These opened with a second of room
before anything happened, several held three takes of the same event back to
back, and they arrived between -12 dBFS and -0.06 dBFS peak. Dropped in as they
came, one door was inaudible and the next made you jump. `cut_sfx.gd` finds the
onset, takes ONE event, trims the room off the end and puts them all at the same
peak; the per-file "how much to keep" figures are the only hand-tuning.

`tools/decode_mp3.gd` is how anything gets from mp3 into the offline tools: it
plays the file on a bus of its own and reads the decoded frames back off an
`AudioEffectCapture`. Real time, so a twenty-second file takes twenty seconds,
and it must run WINDOWED — the dummy audio driver does not turn the mixer.

### Three ambience beds, two buses

Night outside, room tone in the house, water and wind in the cellar. The outdoor
bed plays all the time and is filtered: indoors it is the night heard through a
wall. The interior beds fade in on top of it, unfiltered, because the room you
are standing in is not on the other side of anything. That is why there are two
buses — `Ambience` carries the filter, `Interior` is clean, and one bus with one
filter cannot do both at once.

Measured on both buses, which is the only way to know:

| zone    | night (filtered) | room (clean) |
|---------|------------------|--------------|
| outside |       -29.6 dBFS |       silent |
| house   |       -58.4 dBFS |   -31.0 dBFS |
| cellar  |       -69.9 dBFS |   -33.6 dBFS |

**`resonance = 0` on an AudioEffectLowPassFilter costs 27 dB of insertion loss**
even wide open at 20.5 kHz. That one mistake in the bus layout bent every other
audio number in the project out of shape: the ambience had to be pushed to
+21 dB to be audible, and the indoor cutoffs had to be dragged from 1100 Hz up
to 7000 Hz to stop "muffled" turning into "silent". It is 0.5 now, the engine
default, and the cutoffs and trims are back to textbook values. If an audio
level ever looks absurd, suspect the chain before compensating for it.

### Things that bit, in the audio

**There is no ffmpeg, sox or Python on this machine.** All of it — decoding,
onset detection, filtering, reverb, resampling, writing — is `tools/wavlib.gd`
driven by headless Godot. Do not reach for a shell audio tool; it is not there.

**Gentle, sensible-looking EQ did nothing.** The source take is a midrange thud:
53% of its energy sits between 250 Hz and 1 kHz and under 4% above 2 kHz. A
first pass at the recipes moved things by 3 and 6 dB and measured out almost
identical to the raw file, because it was politely adjusting bands the recording
has no content in. To make one pair of shoes sound like three floors you have to
scoop the band it actually lives in and build the new character somewhere else —
`scatter()` for gravel, `resonator()` for boards.

**An EQ cannot make a floor ring.** Peaking EQ amplifies what is already there,
and there is nothing below 120 Hz in the source to amplify. The wooden floor's
thump is a high-Q bandpass rung by the transient (`resonator()`), which is a
different thing entirely.

**One property, one writer.** `Ambience.gd` originally tweened `volume_db` on
the players directly while also assigning it from the zone code, and the opening
three-second fade-in was destroyed without a word — the bed just appeared at
full level. Everything audible is now a plain float that `_push()` copies into
the players and effects once a frame.

**The bed was playing the whole time; nobody could hear it.** `ambience.mp3`
runs -44 to -64 dBFS RMS across its length and peaks near -33; the menu music
sits at -23. At the -11 dB the bed started on, it landed around -60 dBFS. Worse,
a sweep through the bus showed it loses 20 dB the moment the low-pass drops to
8 kHz and then barely changes down to 420 Hz -- there is almost nothing in it
below 8 kHz. The textbook indoor numbers (1100 Hz, 420 in the cellar) measured
-88 and -102 dBFS: not muffled, gone. Hence `BED_DB` of +16 and positive indoor
trims. Measure a replacement recording before trusting any of those numbers.

**Normalising a quiet recording normalises its room tone too.** The footstep
source peaks at -24 dBFS, so every slice is multiplied by about 15 -- and the
hiss with it. It only showed on the outdoor set, because that is the only one
not low-passed down to 5 kHz, where it measured 30 dB more high-frequency tail
energy than the other two and read as "a ton of background sound". Two fixes:
`gate()` after the normalise, and `scatter()` decaying over 35 ms instead of
running the length of the tail. Grit belongs on the impact.

**Measure the thing you actually mean.** The first check of the three step sets
reported "time to fall 20 dB" and got 18 ms for all three. That is true and
useless: it is the heel landing, and every floor does that fast. What separates
them is what happens afterwards.

**The level opens in a cutscene.** `Intro.gd` calls `begin_focus()`, and
`PlayerController._physics_process` returns before it touches velocity while
focus is held. A test that drops the player into a room and waits will find it
hanging in the air forever. Call `end_focus()` first.

## Performance

Measured at the foot of the entrance hall stairs, 1600x900, RX 580, with the
house lights on — which is the worst case, and the case that was reported as
lag:

| | frame | fps |
|---|---|---|
| before | 31.9 ms | 31 |
| after | 22.0 ms | 45 |

Two things did nearly all of it:

**SDFGI cost 6.7 ms.** Cheapening it (2 cascades, no occlusion, no bounce
feedback) still cost 4.7. It is off, and SSIL does the job for 3 ms — in a
house lit by a torch, the bounce you notice is off the surface the beam is
pointing at, and that is on screen by definition. Ambient went up from 0.16
to 0.34 to cover the long-range fill SDFGI was providing.

**Twenty-seven shadow-casting omni lights cost 12.9 ms and 6400 draw calls.**
A shadowed omni renders everything in range into a cube map, which is six
passes each. Six of them keep shadows now — the ones with a shape worth
casting, the stair light, the hearth, the generator — and those six fade
their shadows out past 9 m. The other twenty-one are ceiling fills whose
shadows nobody could pick out.

Occlusion culling is on (`Scenes/occluders.tscn`, generated) and worth about
0.5 ms and 150 draw calls. It is a small win because most of the remaining
draws are shadow passes rather than geometry.

Things that were tried and **made it worse**: `visibility_range_end` on the
small clutter. The dithered fade costs more than the cull saves, and the draw
count barely moved. Do not re-add it without measuring.

**A hole in the lawn has to be cut in every ground plane, not just one.** The
cellar pit and its storm doors sit outside the house at (-10, -81.5), and the
level's own `Lawn` carries a `CellarCut` for them. `Scenes/surroundings.tscn`
added a second, much larger ground plate underneath everything and roofed the
pit straight over — the doors opened onto solid earth. Its `Ground` is a
combiner with the same cut in it now. Anything else that lays ground down out
there needs the cut too.

## Things outside this directory that these scenes depend on

**The walkway is a ramp now, and the porch has steps.** `demo_level.tscn`'s
`Walkway` used to run all the way in and meet the deck flush at 0.344, which
meant the only way up to the front door was a raised paved terrace that never
read as a way up -- and the lawn either side of it stopped dead against a
30 cm invisible wall, because `CharacterBody3D` has no step-up. The walkway
stops at `z = -32` now, `WalkRamp` carries it down to the grass, and
`Mansion/PorchSteps` is the flight you climb. Change any one of those three
and re-run `probe_walk.gd`.

**The cellar is gated.** `Mansion/CellarGate` is locked with `cellar_key`,
which is in the coal heap, which cannot be searched until the generator is
running. The five `Search*` nodes are `Scripts/SearchSpot.gd` and each one
points at `../Generator` through `light_source`. Adding a sixth means giving
it a `light_source` too, or it is searchable in the dark and the generator
stops being a puzzle.

**Search spots need a body, and a slightly bigger one than the prop.** The
player raycasts, hits a collider and then walks UP the tree looking for an
`Interactable`. A crate's own collider is not a child of the search spot, so
the spot carries its own `StaticBody3D` a few centimetres larger than the
prop it sits on -- otherwise the ray stops on the crate and the spot is
unreachable.

**The input map is not in `project.godot`.** `Scripts/Controls.gd` is an
autoload that erases and rewrites every action at startup from one table, and
saves the player's rebinds to `user://controls.cfg`. The `[input]` section
in `project.godot` is left there for the editor's benefit and is not what the
game runs on. Anything that prints a control asks `Controls.glyph()` rather
than typing `[E]` into a string -- that was how the HUD ended up telling a
pad user to press Tab.

**The surroundings' ground plate is not "the ground" as far as the house is
concerned.** It sits at y -0.22..-0.02, which is three metres ABOVE the cellar
floor and a third of a metre BELOW the ground storey, so without a hole cut in
it it lays a solid 20 cm slab through the middle of the cellar and across the
flight of stairs that leads up out of it. The player ran out of headroom about
two thirds of the way up, and since the cellar was the only way in, the house
could not be entered at all. `gen_surroundings.sh` cuts `HouseCut` for this,
34.8 m square -- bigger than the level's own `Lawn/HouseCut` at 34.0, because
the lawn only has to stop at the wall line while this has to clear the
foundation ring at x +-17.225 as well.

The lesson generalises: anything laid down at a height between two storeys
has to be cut for every storey it passes through, not just for the holes in
the lawn.

**The cellar hatch has a rim you cannot walk over.** The stone coping round the
storm doors tops out at y 0.20 and the pit walls at 0.25, against a lawn at
0.05 -- so 15 to 20 cm of vertical lip on all four sides, and there is no
step-up. `ROUTE=cellar` and `ROUTE=east-into-pit` both stop dead against it.
Getting into the cellar therefore needs a JUMP, which works but is not
signposted anywhere. Opening the doors does not help: at 104 degrees each leaf
stands up past vertical and blocks the end it hinges on, which is what
`ROUTE=deck-to-cellar` runs into.

**An mp3 loops where its BEAT COUNT says, not where the file ends.** The menu
track (`Audio/menu_theme.mp3`) is a sixteen-second loop, but the file decodes
to 16.152 s: measured in 25 ms windows it holds full level right through
16.000 and then decays over about 130 ms to -42 dBFS. That last 130 ms is a
tail, so looping the whole file dips audibly once a pass. Godot's importer has
no "loop end" -- `loop_offset` is where playback jumps back TO -- but setting

    bpm=120
    beat_count=32

in the `.import` gives 32/120*60 = 16.000 s and the stream wraps there. The
measurement that settled it is an `AudioEffectCapture` on the Master bus,
reading `get_buffer()` every frame and printing RMS per window; without it
this is guesswork about whether the tail is music or padding.

Do not "fix" this by watching `get_playback_position()` and calling `seek()`.
That runs on the main thread, so it is late by however long the frame was, and
a seek restarts the decoder.

**`ibox` and `icyl` wrote everything to the scene root.** The car's ninety
brushes were emitted with `parent="."` while `gen_car.sh` also emitted a `Body`
combiner for them to live in, so **Body came out empty**. Two consequences, and
the first went unnoticed for a long time:

- `CarArrival` collects the wheels from `Body`'s children, so the list was
  always empty and **the car's wheels have never turned** -- not on the title
  screen, and not in the opening cutscene either.
- Ninety loose CSG roots instead of one combiner, which is not what that
  script's own header claims it builds.

`items.awk` has `IPAR()` now and `gen_car.sh` passes `-v IPARENT=Body`. Item
scenes are unaffected: their root IS the combiner, so `.` is right for them and
that is what IPAR() still returns by default. `tools/test_menu.gd` asserts the
wheel list is non-empty and that the wheels actually move, so this cannot come
back quietly.

**"1 resources still in use at exit" is Godot, not us.** Quitting while an
`AudioStreamPlayer` is playing prints it. A bare scene containing nothing but
one playing player reproduces it, and the same scene with the `play()` removed
does not; stopping the player or clearing its stream in `_exit_tree` changes
nothing, because what is holding the stream is the resource cache rather than
the node. The title screen plays music, so the message is there on every exit
from it. Do not go looking for a leak in the menu.

## The title screen is a scene now, not a script

`Scenes/menu.tscn` used to contain one node. `MainMenu.gd` built the road, the
woods, the car, the camera, the lights and every label and button in `_ready()`,
which meant there was nothing to select in the editor and no way to see the
title screen without running the game. `tools/gen_menu.sh` writes the whole
thing out as real nodes; the script now only scrolls the scenery, weaves the
car, aims the camera and runs the departure.

**Under `Scroll`, a node's authored Z is its PHASE in the loop, not a place.**
Everything there recycles -- it travels from the fog line to just behind the
shot and wraps -- so `MainMenu` overwrites z every frame and reads the authored
value as the offset. x and y are real. Move a tree sideways in the editor and
it stays moved; move it along the road and you have changed when it arrives.

Two things that bit while generating it:

**Sibling nodes must have unique names.** Eighteen dashes all called `Dash` is
not eighteen nodes, and the road markings, kerb lines and verge kerbstones all
vanished from the scene -- one of each survived. `piece()` numbers them.

**`TextureRect.stretch_mode = 1` is TILE, not SCALE.** The menu's gradient
vignette repeated its 256 px ramp four times across the screen and came out as
vertical banding. SCALE is 0.

And one worth copying: write light angles as `rotation_degrees`, not as a
hand-multiplied `Transform3D` basis. Composing Ry·Rx by hand in a generator is
how the first version lit the scene from 41 degrees when it meant 34.
