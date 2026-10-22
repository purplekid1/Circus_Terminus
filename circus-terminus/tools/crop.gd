extends SceneTree
## Crops a region out of a PNG, for looking closely at one corner of a shot.
##   CROP_IN=a.png CROP_OUT=b.png CROP_RECT=x,y,w,h CROP_ZOOM=3
func _initialize() -> void:
	var img := Image.load_from_file(OS.get_environment("CROP_IN"))
	var r := OS.get_environment("CROP_RECT").split(",")
	var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var out := img.get_region(rect)
	var z := OS.get_environment("CROP_ZOOM")
	var zoom := int(z) if z != "" else 1
	if zoom > 1:
		out.resize(rect.size.x * zoom, rect.size.y * zoom, Image.INTERPOLATE_NEAREST)
	out.save_png(OS.get_environment("CROP_OUT"))
	print("cropped %s -> %s" % [rect, OS.get_environment("CROP_OUT")])
	quit()
