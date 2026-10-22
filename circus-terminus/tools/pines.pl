#!/usr/bin/env perl
# Replaces the generated CSG conifers in a scene with ONE MultiMeshInstance3D
# drawing the hand-modelled pine (Models/pine/Pine_4m.fbx, extracted to
# Meshes/pine.res by tools/extract_pine.gd).
#
#   perl tools/pines.pl <scene.tscn> <ParentNode> [<ParentNode> ...]
#
# WHY A MULTIMESH. The circus forest is 1436 trees. As CSG they baked down to a
# single Woods mesh, which is one draw call; as 1436 instanced prop scenes they
# would be 1436 draw calls and 1.8M vertices, and tools/bake.gd cannot merge
# anything that is not CSG. A MultiMesh is one draw call and one copy of the
# mesh however many trees stand in it, which is exactly the problem it exists
# for. The .res it writes is text, so it diffs.
#
# HOW IT FINDS TREES. tree_conifer() in tools/surroundings.awk emits one
# `Trunk` cylinder of height h*0.16 and three `Bough` cones per tree, all
# directly under the parent it was given. So every Trunk under `Woods` or
# `Treeline` is one conifer and its height is trunk_height / 0.16. Only the
# named parents are touched, which is what keeps tree_bare()'s deciduous trunks
# in `NearTrees` out of it -- those are a different tree and stay CSG.
#
# Run AFTER the generator and BEFORE tools/bake.sh.
use strict;
use warnings;

my $scene = shift or die "usage: pines.pl <scene.tscn> <Parent> [...]\n";
my @parents = @ARGV;
die "usage: pines.pl <scene.tscn> <Parent> [...]\n" unless @parents;

open(my $fh, "<", $scene) or die "cannot read $scene: $!\n";
my $text = do { local $/; <$fh> };
close $fh;

# Split into the header (everything before the first [node) and node blocks.
my $split = index($text, "\n[node ");
die "$scene: no nodes\n" if $split < 0;
my $header = substr($text, 0, $split + 1);
my $body   = substr($text, $split + 1);
my @blocks = split /(?=^\[node )/m, $body;

my %want = map { $_ => 1 } @parents;
my (@trees, @kept);
my $removed = 0;

for my $b (@blocks) {
  if ($b =~ /^\[node name="(Trunk[^"]*)" type="CSGCylinder3D" parent="([^"]+)"/ && $want{$2}) {
    my ($x, $z) = $b =~ /transform = Transform3D\((?:[^,]+,\s*){9}([^,]+),\s*[^,]+,\s*([^)]+)\)/;
    my ($h) = $b =~ /^height = ([0-9.eE+-]+)/m;
    unless (defined $x && defined $h) { push @kept, $b; next; }
    push @trees, [$x + 0, $z + 0, ($h + 0) / 0.16];
    $removed++;
    next;
  }
  if ($b =~ /^\[node name="Bough[^"]*" type="CSGCylinder3D" parent="([^"]+)"/ && $want{$1}) {
    $removed++;
    next;
  }
  push @kept, $b;
}

die "$scene: found no conifers under @parents\n" unless @trees;

# ---- the MultiMesh -------------------------------------------------------
# Buffer layout for TRANSFORM_3D is 12 floats per instance, the three ROWS of
# a 3x4 matrix. Each tree gets a yaw derived from its own position, so the
# forest is not 1436 copies of one tree all facing the same way, and stays the
# same on every regeneration.
my $PINE_H    = 4.198;   # measured height of Meshes/pine.res, trunk spire trimmed
my $PINE_BASE = -0.173;  # its lowest vertex, so the lift puts the trunk on y=0
my @f;
for my $t (@trees) {
  my ($x, $z, $h) = @$t;
  my $s = $h / $PINE_H;
  # deterministic pseudo-random yaw from the position
  my $a = sin($x * 12.9898 + $z * 78.233) * 43758.5453;
  $a = ($a - int($a)) * 6.2831853;
  my ($c, $sn) = (cos($a), sin($a));
  push @f, map { sprintf("%.4f", $_) }
    ($s * $c, 0, $s * $sn, $x,
     0, $s, 0, -$PINE_BASE * $s,
     -$s * $sn, 0, $s * $c, $z);
}

(my $stem = $scene) =~ s{.*/}{};
$stem =~ s/\.tscn$//;
my $mmpath = "Meshes/${stem}_pines.tres";
open(my $out, ">", $mmpath) or die "cannot write $mmpath: $!\n";
print $out qq{[gd_resource type="MultiMesh" load_steps=2 format=3]\n\n};
print $out qq{[ext_resource type="ArrayMesh" path="res://Meshes/pine.res" id="1_pine"]\n\n};
print $out qq{[resource]\n};
print $out qq{transform_format = 1\n};
print $out qq{instance_count = } . scalar(@trees) . qq{\n};
print $out qq{mesh = ExtResource("1_pine")\n};
print $out qq{buffer = PackedFloat32Array(} . join(", ", @f) . qq{)\n};
close $out;

# ---- wire it into the scene ----------------------------------------------
# Mat_pine, NOT Mat_foliage. The pine is built from flat planes and needs
# cull_mode disabled or the canopy vanishes when you are under it; the cone
# trees and the scrub are closed shapes and keep their culling. Added as its
# own ext_resource because nothing else in the scene wears it.
my $folid = "Mat_pine";
unless ($header =~ /path="res:\/\/Materials\/Mat_pine\.tres"/) {
  $header =~ s/(\[ext_resource [^\n]*\]\n)/$1 . qq{[ext_resource type="Material" path="res:\/\/Materials\/Mat_pine.tres" id="Mat_pine"]\n}/e;
}
# ---- collision ------------------------------------------------------------
# THE TREES HAVE TO BE SOLID. The CSG combiner they used to live in carried
# use_collision, so the baked wood came with a trimesh and you could not walk
# through a trunk. A MultiMesh carries no collision at all, and when this tool
# first ran it emptied the combiner and left `use_collision = true` on a node
# with nothing in it -- every tree in the circus silently became a hologram,
# in the one level built around hiding behind them.
#
# One upright cylinder per trunk, under a single StaticBody3D. Not a trimesh
# of the foliage: at head height the only thing you ever touched was the
# trunk anyway, because the lowest bough starts at 0.16 of the tree's height,
# which is above the player on everything shorter than eleven metres.
#
# The shapes are BUCKETED. A CylinderShape3D per tree would be N resources in
# the file for no gain; eight sizes across the range is under half a metre of
# radius between neighbours and nobody can feel that.
my $BUCKETS = 8;
my ($hmin, $hmax) = ($trees[0][2], $trees[0][2]);
for my $t (@trees) {
  $hmin = $t->[2] if $t->[2] < $hmin;
  $hmax = $t->[2] if $t->[2] > $hmax;
}
my $span = ($hmax - $hmin) || 1;
my $shapes = "";
for my $b (0 .. $BUCKETS - 1) {
  my $h = $hmin + $span * ($b + 0.5) / $BUCKETS;
  $shapes .= sprintf(qq{[sub_resource type="CylinderShape3D" id="Trunk_%d"]\nradius = %.3f\nheight = %.3f\n\n},
    $b, $h * 0.045, $h);
}

# The combiner is empty now -- every brush in it was a tree -- so it stops
# being one. A CSGCombiner3D with no CSG children still rebuilds itself at
# load, and this one was carrying `use_collision = true` while containing
# nothing, which is a node that costs something and does nothing.
for my $blk (@kept) {
  next unless $blk =~ /^\[node name="\Q$parents[0]\E" type="CSGCombiner3D"/;
  $blk =~ s/ type="CSGCombiner3D"/ type="Node3D"/;
  $blk =~ s/^use_collision = true\n//m;
}

my $bodies = qq{\n[node name="Trunks" type="StaticBody3D" parent="$parents[0]"]\n};

my $ti = 0;
for my $t (@trees) {
  my ($x, $z, $h) = @$t;
  my $b = int(($h - $hmin) / $span * $BUCKETS);
  $b = $BUCKETS - 1 if $b > $BUCKETS - 1;
  $b = 0 if $b < 0;
  $bodies .= sprintf(qq{\n[node name="T%d" type="CollisionShape3D" parent="%s/Trunks"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.3f, %.3f, %.3f)\nshape = SubResource("Trunk_%d")\n},
    $ti++, $parents[0], $x, $h / 2, $z, $b);
}

my $mmid = "MM_pines";

my $mmline = qq{[ext_resource type="MultiMesh" path="res://$mmpath" id="$mmid"]\n};
# after the FIRST ext_resource line, so it lands in the block with the others
$header =~ s/(\[ext_resource [^\n]*\]\n)/$1 . $mmline/e
  or $header =~ s/(\n)(\[sub_resource|\z)/$1$mmline$2/;
$header .= $shapes;

my $node = qq{\n[node name="Pines" type="MultiMeshInstance3D" parent="$parents[0]"]\n}
         . qq{multimesh = ExtResource("$mmid")\n}
         . qq{material_override = ExtResource("$folid")\n};

open($out, ">", $scene) or die "cannot write $scene: $!\n";
print $out $header, join("", @kept), $node, $bodies;
close $out;

printf STDERR "%s: %d conifers -> %s (removed %d CSG nodes)\n",
  $scene, scalar(@trees), $mmpath, $removed;
