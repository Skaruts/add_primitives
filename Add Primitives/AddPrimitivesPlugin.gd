#==============================================================================#
# Copyright (c) 2015 Franklin Sobrinho.                                        #
#                                                                              #
# Permission is hereby granted, free of charge, to any person obtaining        #
# a copy of this software and associated documentation files (the "Software"), #
# to deal in the Software without restriction, including without               #
# limitation the rights to use, copy, modify, merge, publish,                  #
# distribute, sublicense, and/or sell copies of the Software, and to           #
# permit persons to whom the Software is furnished to do so, subject to        #
# the following conditions:                                                    #
#                                                                              #
# The above copyright notice and this permission notice shall be               #
# included in all copies or substantial portions of the Software.              #
#                                                                              #
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,              #
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF           #
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.       #
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY         #
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,         #
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE            #
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                       #
#==============================================================================#

tool
extends EditorPlugin

class DirectoryUtilities extends Directory:
	
	# Get plugin folder path
	func get_data_dir():
		var path
		
		# X11 and OSX
		if OS.has_environment('HOME'):
			path = OS.get_environment('HOME').plus_file('.godot')
			 
		# Windows
		elif OS.has_environment('APPDATA'):
			path = OS.get_environment('APPDATA').plus_file('Godot')
			
		path = path.plus_file('plugins/Add Primitives')
		
		return path
		
	func get_file_list(path, extension = ''):
		var list = []
		
		if dir_exists(path):
			open(path)
			
			list_dir_begin()
			
			var next = get_next()
			
			while next:
				if not current_is_dir():
					if extension != '' and next.extension() == extension:
						list.push_back(next)
						
					else:
						list.push_back(next)
						
				next = get_next()
				
			list_dir_end()
			
		return list
		
# End DirectoryUtilities

class AddPrimitives extends HBoxContainer:
	
	var current_module = ""
	
	var undo_redo
	
	var popup_menu
	var mesh_dialog
	
	var builder
	var base_mesh
	var mesh_instance
	
	var primitives = {}
	var modules = {}
	
	# Function reference
	var get_selected
	
	# Utilites
	var Dir = DirectoryUtilities.new()
	
	static func safe_call(object, method, args = []):
		if object and object.has_method(method):
			return object.callv(method, args)
			
		return null
		
	func set_state(state):
		mesh_dialog.set_state(state)
		
	func get_state(state):
		mesh_dialog.get_state(state)
		
	func clear_state():
		mesh_dialog.clear_state()
		
	func modify_mesh():
		var new_mesh = base_mesh.duplicate()
		mesh_instance.set_mesh(new_mesh)
		
		var modifiers = mesh_dialog.get_editor("modifiers").get_modifiers()
		
		for mod in modifiers:
			if not mod.is_enabled():
				continue
				
			mod.set_mesh(new_mesh)
			mod.set_aabb(mesh_instance.get_aabb())
			
			mod.modify()
			
			mod.clear()
			
	func _update_mesh():
		var start = OS.get_ticks_msec()
		
		builder.update()
		modify_mesh()
		
		_display_info(start)
		
	func _modify_mesh():
		var start = OS.get_ticks_msec()
		
		modify_mesh()
		
		_display_info(start)
		
	func _display_info(start = 0):
		var mesh = mesh_instance.get_mesh()
		
		var exec_time = OS.get_ticks_msec() - start
		
		var vertex_count = 0
		var triangle_count = 0
		
		for i in range(mesh.get_surface_count()):
			var surf_v = mesh.surface_get_array_len(i)
			
			vertex_count += surf_v
			
			var surf_idx = mesh.surface_get_array_index_len(i)
			
			if surf_idx == Mesh.NO_INDEX_ARRAY:
				surf_idx = surf_v
				
			triangle_count += surf_idx/3
			
		var text = "Verts: %d | Triangles: %d\nGeneration time: %d ms" % [vertex_count, triangle_count, exec_time]
		
		mesh_dialog.display_text(text)
		
	func _popup_signal(index, menu):
		var command = menu.get_item_text(index)
		
		if command == 'Edit Primitive':
			_edit_primitive()
			
		else:
			_create_primitive(command)
			
	func _load_modules():
		modules.clear()
		
		var path = Dir.get_data_dir().plus_file('modules')
		var mods = Dir.get_file_list(path, 'gd')
		
		for m in mods:
			var module = load(path.plus_file(m))
			
			modules[module.get_name()] = module.new(self)
			
	func _update_menu():
		builder = null
		
		popup_menu.clear()
		primitives.clear()
		
		for c in popup_menu.get_children():
			if c extends PopupMenu:
				c.free()
				
		var submenus = {}
		
		var path = Dir.get_data_dir()
		
		var scripts = Dir.get_file_list(path.plus_file('primitives'), 'gd')
		scripts.sort()
		
		for f_name in scripts:
			var p = path.plus_file('primitives'.plus_file(f_name))
			
			var script = load(p)
			var name = script.get_name()
			
			if not name:
				continue
				
			var container = script.get_container()
			
			if container:
				container = container.replace(' ', '_').to_lower()
				
				if not submenus.has(container):
					submenus[container] = []
					
				submenus[container].push_back(name)
				
			else:
				popup_menu.add_item(name)
				
			primitives[name] = script
			
		if not submenus.empty():
			popup_menu.add_separator()
			
			for sub in submenus.keys():
				var submenu = PopupMenu.new()
				submenu.set_name(sub)
				popup_menu.add_child(submenu)
				
				submenu.connect("item_pressed", self, "_popup_signal", [submenu])
				
				var n = sub.capitalize()
				
				popup_menu.add_submenu_item(n, sub)
				
				for name in submenus[sub]:
					submenu.add_item(name)
					
		if not modules.empty():
			popup_menu.add_separator()
			
			for m in modules:
				popup_menu.add_item(m)
				
		popup_menu.add_separator()
		
		popup_menu.add_icon_item(get_icon('Edit', 'EditorIcons'), 'Edit Primitive', -1, KEY_MASK_SHIFT + KEY_E)
		
		_set_edit_disabled(true)
		
		if not popup_menu.is_connected("item_pressed", self, "_popup_signal"):
			popup_menu.connect("item_pressed", self, "_popup_signal", [popup_menu])
			
	func _create_primitive(name):
		var node = get_selected.call_func()
		var edited_scene = get_tree().get_edited_scene_root()
		
		if not node and edited_scene:
			return
			
		mesh_instance = MeshInstance.new()
		
		undo_redo.create_action("Create " + name)
		
		if edited_scene:
			undo_redo.add_do_method(node, "add_child", mesh_instance)
			undo_redo.add_do_method(mesh_instance, "set_owner", edited_scene)
			undo_redo.add_do_reference(mesh_instance)
			
			undo_redo.add_undo_method(node, "remove_child", mesh_instance)
			
		else:
			var editor = get_tree().get_root().get_node("EditorNode")
			
			undo_redo.add_do_method(editor, "set_edited_scene", mesh_instance)
			undo_redo.add_do_reference(mesh_instance)
			
			undo_redo.add_undo_method(editor, "set_edited_scene", Object(null))
			
		undo_redo.commit_action()
		
		if modules.has(name):
			current_module = name
			
			safe_call(modules[name], "create", [mesh_instance])
			
			_set_edit_disabled(mesh_instance == null)
			
			return
			
		if current_module:
			safe_call(modules[current_module], "clear")
			
			current_module = ""
			
		mesh_instance.set_name(name)
		
		var start = OS.get_ticks_msec()
		
		builder = primitives[name].new()
		builder.update()
		
		base_mesh = builder.get_mesh()
		
		mesh_instance.set_mesh(base_mesh)
		
		_display_info(start)
		
		if builder.has_method('mesh_parameters'):
			mesh_dialog.edit(mesh_instance, builder)
			_set_edit_disabled(false)
			
			mesh_dialog.show_dialog()
			
	func _set_edit_disabled(disable):
		set_process_unhandled_key_input(not disable)
		
		var count = popup_menu.get_item_count()
		
		if not count:
			return
			
		popup_menu.set_item_disabled(count - 1, disable)
		
	func _edit_primitive():
		if not mesh_instance:
			return
			
		if current_module:
			safe_call(modules[current_module], "edit_primitive")
			
			return
			
		if mesh_dialog.is_hidden():
			mesh_dialog.show_dialog()
			
	func _unhandled_key_input(key_event):
		if key_event.pressed and not key_event.echo:
			if key_event.scancode == KEY_ESCAPE and mesh_dialog.is_visible():
				mesh_dialog.hide()
				
				accept_event()
				
			elif key_event.scancode == KEY_E and key_event.shift:
				_edit_primitive()
				
				accept_event()
				
	func _node_removed(node):
		if node == mesh_instance:
			_set_edit_disabled(true)
			
			if current_module:
				safe_call(modules[current_module], "node_removed")
				
				current_module = ""
				
			if mesh_dialog.is_visible():
				mesh_dialog.hide()
			
			mesh_instance = null
			
	func _visibility_changed():
		if is_visible():
			_set_edit_disabled(mesh_instance == null)
			
		else:
			_set_edit_disabled(true)
			
			mesh_dialog.hide()
			
	func _enter_tree():
		_load_modules()
		_update_menu()
		
		var base = get_node("/root/EditorNode").get_gui_base()
		
		mesh_dialog = preload("MeshDialog.gd").new(base)
		base.add_child(mesh_dialog)
		
		mesh_dialog.connect_editor("parameters", self, "_update_mesh")
		mesh_dialog.connect_editor("modifiers", self, "_modify_mesh")
		
		get_tree().connect("node_removed", self, "_node_removed")
		
		connect("visibility_changed", self, "_visibility_changed")
		
	func _exit_tree():
		popup_menu.clear()
		mesh_dialog.clear()
		
		builder = null
		base_mesh = null
		
		primitives.clear()
		modules.clear()
		
		get_tree().disconnect("node_removed", self, "_node_removed")
		
	func _init():
		add_child( VSeparator.new() )
		
		var spatial_menu = MenuButton.new()
		spatial_menu.set_button_icon(preload('icon_mesh_instance_add.png'))
		spatial_menu.set_tooltip("Add New Primitive")
		add_child(spatial_menu)
		
		popup_menu = spatial_menu.get_popup()
		
# End AddPrimitives

var add_primitives

var tree

static func get_name():
	return "add_primitives"
	
func set_state(state):
	add_primitives.set_state(state)
	
func get_state():
	var state = {}
	
	add_primitives.get_state(state)
	
	return state
	
func clear():
	add_primitives.clear_state()
	
func _find_node(type, node):
	if node.is_type(type):
		return node
		
	for i in range(node.get_child_count()):
		var n = _find_node(type, node.get_child(i))
		
		if n:
			return n
			
	return null
	
func _get_selected():
	var item = tree.get_selected()
	
	if not item:
		return
		
	var path = item.get_metadata(0)
	
	if has_node(path):
		return get_node(path)
		
	return null
	
func _enter_tree():
	add_primitives = AddPrimitives.new()
	add_primitives.undo_redo = get_undo_redo()
	add_primitives.get_selected = funcref(self, "_get_selected")
	add_custom_control(CONTAINER_SPATIAL_EDITOR_MENU, add_primitives)
	
	add_primitives.get_parent().move_child(add_primitives, 5)
	
	var scene_editor = _find_node("SceneTreeEditor", _find_node("SceneTreeDock", get_parent()))
	tree = _find_node("Tree", scene_editor)
	
	print("ADD PRIMITIVES INIT")
	

