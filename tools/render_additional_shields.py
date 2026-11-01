"""
Render additional Mediterranean faction shields in Blender 5.2.
Outputs 128x128 PNGs for Rome, Carthage, Egypt, Macedon, Seleucid.
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
    cam_data.ortho_scale = 2.4
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = (0, -3.2, 2.4)
    cam_obj.rotation_euler = (math.radians(52), 0, 0)

    # Key light
    sun1_data = bpy.data.lights.new("Sun1", type='SUN')
    sun1_data.energy = 4.2
    sun1_data.color = (1.0, 0.95, 0.88)
    sun1 = bpy.data.objects.new("Sun1", sun1_data)
    scene.collection.objects.link(sun1)
    sun1.rotation_euler = (math.radians(45), math.radians(25), math.radians(-35))

    # Fill light
    sun2_data = bpy.data.lights.new("Sun2", type='SUN')
    sun2_data.energy = 2.0
    sun2_data.color = (0.7, 0.82, 1.0)
    sun2 = bpy.data.objects.new("Sun2", sun2_data)
    scene.collection.objects.link(sun2)
    sun2.rotation_euler = (math.radians(-30), math.radians(-40), math.radians(130))

    return scene, cam_obj

def make_pbr_material(name, base_color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = base_color
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return mat

def clear_mesh_objects():
    for obj in list(bpy.context.scene.collection.objects):
        if obj.type == 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)

def render_shield(color, emblem_style, out_file):
    clear_mesh_objects()
    bronze_mat = make_pbr_material("RimBronze", (0.85, 0.65, 0.22, 1.0), metallic=0.85, roughness=0.28)
    face_mat = make_pbr_material("FaceMat", color, metallic=0.25, roughness=0.35)
    gold_mat = make_pbr_material("GoldEmblem", (0.95, 0.80, 0.25, 1.0), metallic=0.92, roughness=0.20)

    # Outer bronze rim
    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.18, vertices=32, location=(0, 0, 0))
    rim = bpy.context.active_object
    rim.data.materials.append(bronze_mat)

    # Torus border
    bpy.ops.mesh.primitive_torus_add(major_radius=0.92, minor_radius=0.08, major_segments=32, minor_segments=12, location=(0, 0, 0.08))
    torus = bpy.context.active_object
    torus.data.materials.append(bronze_mat)

    # Convex face
    bpy.ops.mesh.primitive_cylinder_add(radius=0.88, depth=0.12, vertices=32, location=(0, 0, 0.08))
    face = bpy.context.active_object
    face.data.materials.append(face_mat)

    # Center Boss / Symbol
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.35, segments=24, ring_count=12, location=(0, 0, 0.22))
    boss = bpy.context.active_object
    boss.scale = (1.0, 1.0, 0.4)
    boss.data.materials.append(gold_mat)

    # Rays / Details based on emblem_style
    if emblem_style == "macedon":
        for i in range(8):
            ang = math.radians(i * 45)
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(math.sin(ang)*0.55, math.cos(ang)*0.55, 0.20))
            ray = bpy.context.active_object
            ray.scale = (0.06, 0.35, 0.06)
            ray.rotation_euler = (0, 0, -ang)
            ray.data.materials.append(gold_mat)
    elif emblem_style == "thunderbolt": # Rome
        for ang in [math.radians(30), math.radians(-30), math.radians(150), math.radians(-150)]:
            bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.55, vertices=8, location=(math.sin(ang)*0.45, math.cos(ang)*0.45, 0.20))
            wing = bpy.context.active_object
            wing.rotation_euler = (0, 0, -ang)
            wing.data.materials.append(gold_mat)

    scene = bpy.context.scene
    scene.render.resolution_x = 128
    scene.render.resolution_y = 128
    scene.render.filepath = os.path.abspath(out_file)
    bpy.ops.render.render(write_still=True)
    print("Rendered:", out_file)

def main():
    setup_scene()
    factions = [
        ("rome", (0.75, 0.10, 0.12, 1.0), "thunderbolt", "assets/ui/rome_shield.png"),
        ("carthage", (0.50, 0.15, 0.45, 1.0), "crescent", "assets/ui/carthage_shield.png"),
        ("egypt", (0.10, 0.55, 0.60, 1.0), "sun", "assets/ui/egypt_shield.png"),
        ("macedon", (0.35, 0.15, 0.50, 1.0), "macedon", "assets/ui/macedon_shield.png"),
        ("seleucid", (0.80, 0.45, 0.15, 1.0), "sun", "assets/ui/seleucid_shield.png"),
    ]
    for fid, color, style, path in factions:
        render_shield(color, style, path)

if __name__ == "__main__":
    main()
