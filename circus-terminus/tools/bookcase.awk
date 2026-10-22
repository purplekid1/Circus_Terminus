# Emits Scenes/props/pf_bookcase_model_<size>.tscn: the hand-modelled
# BookShelf.fbx, baked, scaled and offset onto the footprint of the CSG
# bookcase it replaces.
#
# Run from tools/gen_bookcases.sh with the OUTER dimensions of the old prop as
# W (width, along x), H (height) and D (depth, along z), and SIZE naming which
# baked books mesh to use.
#
# IT DOES NOT INSTANCE THE FBX. The model is 149 MeshInstance3Ds -- a carcass
# and 148 separate books, each with a cover surface and a page surface -- which
# is ~297 draw calls for one bookcase, and sixteen of them stand in the house.
# tools/bake_bookshelf.gd merges that down to a carcass mesh and a books mesh
# and writes them into Meshes/, so a bookcase is THREE draw calls. RE-RUN THAT
# TOOL if the model is ever re-exported; nothing here will notice on its own.
#
# THE BOOKS ARE ALL DIFFERENT COLOURS and it still costs one draw call: the
# bake writes a per-book tint into the vertex colours and Mat_bookspine
# multiplies it into a white albedo. Each size gets its own colour run, so a
# wall of bookcases does not repeat the same shelf three times.
#
# Measured off the imported mesh by walking vertices:
#   x -1.060 .. 0.147   depth 1.207, and the ORIGIN IS AT THE FRONT FACE
#   y -0.008 .. 4.218   height 4.226
#   z -3.228 .. 3.213   width 6.441
# It faces +X, so it takes a -90 yaw to face +Z like every other prop here.
#
# Scale is UNIFORM and matched to WIDTH, so the unit spans exactly the same
# piece of wall and cannot grow into whatever stands beside it. Height then
# lands a little under the old prop, which is safe -- nothing can hit a ceiling
# it used to clear -- and depth a little over, which only means it stands
# slightly further into the room.
#
# The Z OFFSET puts the model's back panel where the old back panel was.
# Without it the model reaches 0.28 m further back, because its origin is at
# the front face and not the centre, and it goes through the wall.
BEGIN {
  MW = 6.441; MH = 4.226; MD = 1.207; MBACK = -1.060; MYMIN = -0.008

  s   = W / MW
  oy  = -MYMIN * s
  oz  = (-D / 2) - (MBACK * s)
  hgt = MH * s
  dep = MD * s
  cz  = ((MBACK + 0.147) / 2) * s + oz

  print "[gd_scene load_steps=7 format=3]"
  print ""
  print "[ext_resource type=\"ArrayMesh\" path=\"res://Meshes/bookshelf_case.res\" id=\"1_case\"]"
  print "[ext_resource type=\"ArrayMesh\" path=\"res://Meshes/bookshelf_books_" SIZE ".res\" id=\"2_books\"]"
  print "[ext_resource type=\"Material\" path=\"res://Materials/Mat_walnut.tres\" id=\"3_walnut\"]"
  print "[ext_resource type=\"Material\" path=\"res://Materials/Mat_bookspine.tres\" id=\"4_spine\"]"
  print "[ext_resource type=\"Material\" path=\"res://Materials/Mat_bookpage.tres\" id=\"5_page\"]"
  print ""
  printf "[sub_resource type=\"BoxShape3D\" id=\"Box_case\"]\nsize = Vector3(%.4f, %.4f, %.4f)\n\n", W, hgt, dep
  print "[node name=\"" NAME "\" type=\"Node3D\"]"
  print ""
  # ROW-MAJOR. The 12-float Transform3D in a .tscn is three basis ROWS, not
  # three basis vectors, so this is M = [[0,0,-s],[0,s,0],[s,0,0]] and it sends
  # local +X (the shelf front) to world +Z. Writing it the other way round
  # turns the bookcase to face the wall AND puts its back 0.78 m out into the
  # room, which is what it did the first time.
  print "[node name=\"Model\" type=\"Node3D\" parent=\".\"]"
  printf "transform = Transform3D(0, 0, %.6f, 0, %.6f, 0, %.6f, 0, 0, 0, %.4f, %.4f)\n\n", -s, s, s, oy, oz

  print "[node name=\"Case\" type=\"MeshInstance3D\" parent=\"Model\"]"
  print "mesh = ExtResource(\"1_case\")"
  print "material_override = ExtResource(\"3_walnut\")"
  print ""
  # Surface 0 is every cover in the case, surface 1 every block of pages.
  print "[node name=\"Books\" type=\"MeshInstance3D\" parent=\"Model\"]"
  print "mesh = ExtResource(\"2_books\")"
  print "surface_material_override/0 = ExtResource(\"4_spine\")"
  print "surface_material_override/1 = ExtResource(\"5_page\")"
  print ""

  # The CSG bookcases carried use_collision; a MeshInstance cannot, so the box
  # the player bumps into is explicit here. It is the outer case, books inside.
  print "[node name=\"Body\" type=\"StaticBody3D\" parent=\".\"]"
  print ""
  print "[node name=\"Box\" type=\"CollisionShape3D\" parent=\"Body\"]"
  printf "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, %.4f, %.4f)\n", hgt / 2 + oy, cz
  print "shape = SubResource(\"Box_case\")"
}
