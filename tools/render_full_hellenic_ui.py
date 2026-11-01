"""
Blender 5.2 Full Hellenic UI Renderer for Sons of Hellas.
Renders sculpted Greek bronze, marble stone, and parchment UI elements
into lightweight 9-slice and sprite PNGs for mobile 60 FPS performance.
"""

import bpy
import math
import os

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderSettings') and 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.05, 0.05, 0.07, 1.0)
        bg.inputs[1].default_value = 0.6

    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 2.0
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = (0, 0, 3.5)
    cam_obj.rotation_euler = (0, 0, 0)

    # Key Sun Light (Warm Aegean Sunlight)
    sun1_data = bpy.data.lights.new("Sun1", type='SUN')
    sun1_data.energy = 4.5
    sun1_data.color = (1.0, 0.94, 0.82)
    sun1 = bpy.data.objects.new("Sun1", sun1_data)
    scene.collection.objects.link(sun1)
    sun1.rotation_euler = (math.radians(45), math.radians(20), math.radians(-30))

    # Rim / Ambient Light (Cool Blue Sky Fill)
    sun2_data = bpy.data.lights.new("Sun2", type='SUN')
    sun2_data.energy = 2.2
    sun2_data.color = (0.65, 0.8, 1.0)
    sun2 = bpy.data.objects.new("Sun2", sun2_data)
    scene.collection.objects.link(sun2)
    sun2.rotation_euler = (math.radians(-35), math.radians(-30), math.radians(140))

    return scene, cam_obj

def clear_mesh_objects():
    for obj in list(bpy.context.scene.collection.objects):
        if obj.type == 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)

def make_pbr_material(name, base_color, metallic=0.0, roughness=0.4):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = base_color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
    return mat

def render_to(filepath, resolution=(128, 128)):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.filepath = os.path.abspath(filepath)
    os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered UI Asset: {scene.render.filepath} ({resolution[0]}x{resolution[1]})")

# --- UI Assets ---

def render_panel_stone():
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.1

    # Outer bronze / dark iron frame
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.05))
    frame = bpy.context.active_object
    frame.scale = (2.0, 2.0, 0.1)
    frame_mat = make_pbr_material("BronzeFrame", (0.24, 0.18, 0.12, 0.96), metallic=0.7, roughness=0.35)
    frame.data.materials.append(frame_mat)

    # Inner carved limestone slab
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.02))
    stone = bpy.context.active_object
    stone.scale = (1.82, 1.82, 0.08)
    stone_mat = make_pbr_material("CarvedStone", (0.13, 0.14, 0.17, 0.94), metallic=0.1, roughness=0.6)
    stone.data.materials.append(stone_mat)

    # Gold corner rivets
    gold_mat = make_pbr_material("CornerGold", (0.9, 0.72, 0.22, 1.0), metallic=0.9, roughness=0.25)
    for cx in [-0.88, 0.88]:
        for cy in [-0.88, 0.88]:
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.06, location=(cx, cy, 0.08))
            rivet = bpy.context.active_object
            rivet.data.materials.append(gold_mat)

    render_to("assets/ui/ui_panel_stone.png", (128, 128))

def render_panel_topbar():
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.2

    # Topbar header slab
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    bar = bpy.context.active_object
    bar.scale = (2.16, 1.0, 0.1)
    bar_mat = make_pbr_material("TopbarBronze", (0.14, 0.13, 0.16, 0.96), metallic=0.6, roughness=0.38)
    bar.data.materials.append(bar_mat)

    # Gold border trim along bottom and top
    gold_mat = make_pbr_material("GoldTrim", (0.88, 0.70, 0.22, 1.0), metallic=0.92, roughness=0.25)
    for ypos in [-0.48, 0.48]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, ypos, 0.06))
        trim = bpy.context.active_object
        trim.scale = (2.16, 0.04, 0.04)
        trim.data.materials.append(gold_mat)

    render_to("assets/ui/ui_panel_topbar.png", (256, 64))

def render_button_bronze(state="normal"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.0

    z_depth = 0.04 if state == "normal" else (-0.02 if state == "pressed" else 0.06)
    btn_color = (0.48, 0.32, 0.15, 1.0) if state == "normal" else ((0.28, 0.18, 0.08, 1.0) if state == "pressed" else (0.60, 0.42, 0.18, 1.0))
    roughness = 0.3 if state != "pressed" else 0.55

    # Beveled bronze button body
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_depth / 2.0))
    btn = bpy.context.active_object
    btn.scale = (1.92, 0.92, 0.12)
    b_mat = make_pbr_material("BtnBronze", btn_color, metallic=0.82, roughness=roughness)
    btn.data.materials.append(b_mat)

    # Inner raised face
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, z_depth + 0.04))
    face = bpy.context.active_object
    face.scale = (1.78, 0.78, 0.06)
    f_mat = make_pbr_material("BtnFace", (btn_color[0]*1.1, btn_color[1]*1.1, btn_color[2]*1.1, 1.0), metallic=0.75, roughness=0.3)
    face.data.materials.append(f_mat)

    # Gold rim border
    gold_mat = make_pbr_material("BtnRimGold", (0.92, 0.76, 0.26, 1.0), metallic=0.95, roughness=0.2)
    for bx in [-0.88, 0.88]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(bx, 0, z_depth + 0.05))
        rim = bpy.context.active_object
        rim.scale = (0.04, 0.82, 0.04)
        rim.data.materials.append(gold_mat)
    for by in [-0.40, 0.40]:
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, by, z_depth + 0.05))
        rim = bpy.context.active_object
        rim.scale = (1.78, 0.04, 0.04)
        rim.data.materials.append(gold_mat)

    filename = f"assets/ui/btn_bronze_{state}.png"
    render_to(filename, (128, 64))

def render_end_turn_medallion():
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.2)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.4

    gold_mat = make_pbr_material("MedallionGold", (0.94, 0.76, 0.22, 1.0), metallic=0.94, roughness=0.2)
    crimson_mat = make_pbr_material("MedallionCrimson", (0.6, 0.1, 0.1, 1.0), metallic=0.3, roughness=0.4)

    # Outer cog/sunburst ring
    bpy.ops.mesh.primitive_cylinder_add(radius=1.05, depth=0.1, vertices=36, location=(0, 0, 0))
    rim = bpy.context.active_object
    rim.data.materials.append(gold_mat)

    # Inner raised medallion ring
    bpy.ops.mesh.primitive_torus_add(major_radius=0.92, minor_radius=0.08, major_segments=36, minor_segments=12, location=(0, 0, 0.08))
    torus = bpy.context.active_object
    torus.data.materials.append(gold_mat)

    # Crimson central disc
    bpy.ops.mesh.primitive_cylinder_add(radius=0.86, depth=0.1, vertices=32, location=(0, 0, 0.06))
    disc = bpy.context.active_object
    disc.data.materials.append(crimson_mat)

    # Greek Laurel Wreath leaves / Laurel crown
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        lx = math.cos(rad) * 0.65
        ly = math.sin(rad) * 0.65
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(lx, ly, 0.14))
        leaf = bpy.context.active_object
        leaf.scale = (0.5, 1.2, 0.3)
        leaf.rotation_euler = (0, 0, rad)
        leaf.data.materials.append(gold_mat)

    # Golden central Sparta/Hourglass seal
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.24, location=(0, 0, 0.15))
    center = bpy.context.active_object
    center.scale = (1.0, 1.0, 0.35)
    center.data.materials.append(gold_mat)

    render_to("assets/ui/btn_end_turn_medallion.png", (128, 128))

def render_building_slots():
    # 1. Empty slot frame
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.0

    frame_mat = make_pbr_material("SlotBronze", (0.35, 0.25, 0.15, 1.0), metallic=0.8, roughness=0.35)
    inner_mat = make_pbr_material("SlotDark", (0.08, 0.09, 0.11, 0.95), metallic=0.0, roughness=0.8)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    slot_outer = bpy.context.active_object
    slot_outer.scale = (1.8, 1.8, 0.1)
    slot_outer.data.materials.append(frame_mat)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.04))
    slot_inner = bpy.context.active_object
    slot_inner.scale = (1.56, 1.56, 0.08)
    slot_inner.data.materials.append(inner_mat)

    render_to("assets/ui/building_slot_empty.png", (96, 96))

    # 2. Agora / Market icon
    gold_mat = make_pbr_material("SlotGold", (0.9, 0.72, 0.22, 1.0), metallic=0.9, roughness=0.25)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.15, vertices=24, location=(0, 0, 0.12))
    coin_icon = bpy.context.active_object
    coin_icon.data.materials.append(gold_mat)
    render_to("assets/ui/building_slot_agora.png", (96, 96))

    # 3. Barracks / Weapons icon
    clear_mesh_objects()
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.0

    frame_mat3 = make_pbr_material("SlotBronze3", (0.35, 0.25, 0.15, 1.0), metallic=0.8, roughness=0.35)
    inner_mat3 = make_pbr_material("SlotDark3", (0.08, 0.09, 0.11, 0.95), metallic=0.0, roughness=0.8)
    gold_mat3 = make_pbr_material("SlotGold3", (0.9, 0.72, 0.22, 1.0), metallic=0.9, roughness=0.25)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0))
    slot_outer = bpy.context.active_object
    slot_outer.scale = (1.8, 1.8, 0.1)
    slot_outer.data.materials.append(frame_mat3)

    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 0.04))
    slot_inner = bpy.context.active_object
    slot_inner.scale = (1.56, 1.56, 0.08)
    slot_inner.data.materials.append(inner_mat3)

    # Crossed hoplite spears
    for ang in [math.radians(45), math.radians(-45)]:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=1.4, vertices=12, location=(0, 0, 0.12))
        spear = bpy.context.active_object
        spear.rotation_euler = (0, 0, ang)
        spear.data.materials.append(gold_mat3)
    render_to("assets/ui/building_slot_barracks.png", (96, 96))

def render_public_order_masks():
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.0

    gold_mat = make_pbr_material("MaskGold", (0.92, 0.74, 0.24, 1.0), metallic=0.9, roughness=0.25)

    # Laurel victory wreath (Happy public order)
    for side in [-1, 1]:
        for i in range(8):
            ang = math.radians(side * (25 + i * 18))
            px = math.sin(ang) * 0.65
            py = math.cos(ang) * 0.65 - 0.2
            bpy.ops.mesh.primitive_uv_sphere_add(radius=0.09, location=(px, py, 0.05))
            leaf = bpy.context.active_object
            leaf.scale = (0.6, 1.4, 0.3)
            leaf.rotation_euler = (0, 0, -ang + math.radians(side * 20))
            leaf.data.materials.append(gold_mat)

    render_to("assets/ui/icon_order_positive.png", (64, 64))

    # Unrest fire / sword icon (Negative public order)
    clear_mesh_objects()
    scene.camera.location = (0, 0, 3.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 2.0

    fire_mat = make_pbr_material("FireRuby", (0.85, 0.15, 0.10, 1.0), metallic=0.3, roughness=0.3)
    gold_mat_fire = make_pbr_material("FireGold", (0.92, 0.74, 0.24, 1.0), metallic=0.9, roughness=0.25)
    bpy.ops.mesh.primitive_cone_add(radius1=0.45, depth=1.1, vertices=16, location=(0, 0.1, 0.05))
    cone = bpy.context.active_object
    cone.data.materials.append(fire_mat)

    bpy.ops.mesh.primitive_cone_add(radius1=0.28, depth=0.7, vertices=16, location=(0, -0.15, 0.08))
    cone2 = bpy.context.active_object
    cone2.data.materials.append(gold_mat_fire)

    render_to("assets/ui/icon_order_negative.png", (64, 64))

def main():
    print("Rendering Full Classical Hellenic UI Kit...")
    setup_scene()

    render_panel_stone()
    render_panel_topbar()
    render_button_bronze("normal")
    render_button_bronze("pressed")
    render_button_bronze("hover")
    render_end_turn_medallion()
    render_building_slots()
    render_public_order_masks()

    print("ALL HELLENIC UI ASSETS RENDERED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
