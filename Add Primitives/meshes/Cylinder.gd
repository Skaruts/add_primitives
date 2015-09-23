extends "../Primitive.gd"

var radius = 1.0
var height = 2.0
var sides = 16
var height_segments = 1
var slice = 0
var generate_caps = true
var generate_ends = true

static func get_name():
	return "Cylinder"
	
func create():
	var angle = 360 - slice
	
	var circumference = (angle * PI * radius)/180
	
	var h = height
	var sa = deg2rad(angle)
	
	var circle = Utils.build_circle_verts(Vector3(0, h/2, 0), sides, radius, sa)
	var uv = Utils.build_circle_verts(Vector3(0.5, 0, 0.5), sides, radius, sa)
	
	var pos = Vector3(0, -h, 0)
	
	begin(VS.PRIMITIVE_TRIANGLES)
	
	add_smooth_group(false)
	
	if generate_caps:
		var top = Vector3(0, h/2, 0)
		
		var c = Vector2(0.5, 0.5)
		
		for idx in range(sides):
			add_tri([top, circle[idx], circle[idx + 1]],\
			        [c, Vector2(uv[idx].x, uv[idx].z), Vector2(uv[idx + 1].x, uv[idx + 1].z)])
			add_tri([pos/2, circle[idx + 1] + pos, circle[idx] + pos],\
			        [c, Vector2(uv[idx + 1].x, uv[idx + 1].z), Vector2(uv[idx].x, uv[idx].z)])
			
	if generate_ends and slice:
		var t = Vector3(0, h/2, 0)
		
		var p = Vector3()
		
		for i in range(height_segments): 
			var n = -Vector3(0, height/height_segments * (i + 1), 0)
			
			var v1 = i/height_segments * height
			var v2 = (i + 1)/height_segments * height
			
			var uv = [Vector2(0, v1),
			          Vector2(radius, v1),
			          Vector2(radius, v2),
			          Vector2(0, v2)]
			
			add_quad([circle[0] + p, t + p, t + n, circle[0] + n], uv)
			add_quad([t + p, circle[sides] + p, circle[sides] + n, t + n], uv)
			
			p = n
			
	var next = pos + Vector3(0, h/height_segments, 0)
	
	h /= height_segments
	
	add_smooth_group(smooth)
	
	for i in range(height_segments):
		if i == height_segments - 1:
			next.y = 0
			
		i = float(i)
		
		var v1 = i/height_segments * height
		var v2 = (i+1)/height_segments * height
		
		for idx in range(sides):
			idx = float(idx)
			
			var u1 = idx/sides * circumference
			var u2 = (idx+1)/sides * circumference
			
			add_quad([circle[idx + 1] + pos, circle[idx + 1] + next, circle[idx] + next, circle[idx] + pos],\
			         [Vector2(u2, v1), Vector2(u2, v2), Vector2(u1, v2), Vector2(u1, v1)])
			
		pos = next
		next.y += h
		
	var mesh = commit()
	
	return mesh
	
func mesh_parameters(editor):
	editor.add_tree_range('Radius', radius)
	editor.add_tree_range('Height', height)
	editor.add_tree_range('Sides', sides, 1, 3, 64)
	editor.add_tree_range('Height Segments', height_segments, 1, 1, 64)
	editor.add_tree_range('Slice', slice, 1, 0, 359)
	editor.add_tree_empty()
	editor.add_tree_check('Generate Caps', generate_caps)
	editor.add_tree_check('Generate Ends', generate_ends)
	

