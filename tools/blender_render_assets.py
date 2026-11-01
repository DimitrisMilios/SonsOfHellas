"""
Blender 5.2 Headless Asset Generator for Sons of Hellas.
Procedurally models, materials, lights, and renders classical Hellenic UI and Map assets.
Outputs lightweight, mobile-optimized transparent PNGs into assets/ui and assets/map.
"""

import bpy
import math
import os
import sys

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderSettings') and 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'

    # World background
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.05, 0.05, 0.06, 1.0)
        bg.inputs[1].default_value = 0.5

    # Camera
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 3.2
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = (0, -4.5, 3.2)
    cam_obj.rotation_euler = (math.radians(52), 0, 0)

    # Key light
    key_light_data = bpy.data.lights.new("KeyLight", type='SUN')
    key_light_data.energy = 4.0
    key_light_data.color = (1.0, 0.95, 0.88)
    key_light = bpy.data.objects.new("KeyLight", key_light_data)
    scene.collection.objects.link(key_light)
    key_light.rotation_euler = (math.radians(45), math.radians(25), math.radians(-35))

    # Fill / Rim light
    fill_light_data = bpy.data.lights.new("FillLight", type='SUN')
    fill_light_data.energy = 1.8
    fill_light_data.color = (0.7, 0.82, 1.0)
    fill_light = bpy.data.objects.new("FillLight", fill_light_data)
    scene.collection.objects.link(fill_light)
    fill_light.rotation_euler = (math.radians(-30), math.radians(-40), math.radians(130))

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
    print(f"Rendered: {scene.render.filepath} ({resolution[0]}x{resolution[1]})")

# --- Generators ---

def generate_shield(emblem_type="sparta", output_path="assets/ui/sparta_shield.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -3.8, 2.8)
    scene.camera.rotation_euler = (math.radians(55), 0, 0)
    scene.camera.data.ortho_scale = 2.4

    # Outer bronze rim
    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.1, vertices=32, location=(0, 0, 0))
    rim = bpy.context.active_object
    rim_mat = make_pbr_material("BronzeRim", (0.85, 0.65, 0.25, 1.0), metallic=0.85, roughness=0.25)
    rim.data.materials.append(rim_mat)

    # Convex shield center
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.92, segments=32, ring_count=16, location=(0, 0, 0.05))
    shield_face = bpy.context.active_object
    shield_face.scale = (1.0, 1.0, 0.22)

    color_map = {
        "sparta": (0.65, 0.08, 0.08, 1.0),    # Crimson
        "athens": (0.12, 0.32, 0.68, 1.0),    # Azure blue
        "thebes": (0.75, 0.55, 0.12, 1.0),    # Boeotian ochre
        "corinth": (0.15, 0.58, 0.62, 1.0)    # Corinthian teal
    }
    face_color = color_map.get(emblem_type, (0.5, 0.1, 0.1, 1.0))
    face_mat = make_pbr_material("ShieldFace", face_color, metallic=0.2, roughness=0.35)
    shield_face.data.materials.append(face_mat)

    # Emblem in center
    gold_mat = make_pbr_material("EmblemGold", (0.92, 0.76, 0.28, 1.0), metallic=0.9, roughness=0.2)
    if emblem_type == "sparta":
        # Greek Lambda (inverted V)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.75, vertices=16, location=(-0.16, 0, 0.24))
        left_leg = bpy.context.active_object
        left_leg.rotation_euler = (0, math.radians(-26), 0)
        left_leg.data.materials.append(gold_mat)

        bpy.ops.mesh.primitive_cylinder_add(radius=0.08, depth=0.75, vertices=16, location=(0.16, 0, 0.24))
        right_leg = bpy.context.active_object
        right_leg.rotation_euler = (0, math.radians(26), 0)
        right_leg.data.materials.append(gold_mat)
    else:
        # Central raised bronze boss / emblem
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.32, segments=24, ring_count=12, location=(0, 0, 0.22))
        boss = bpy.context.active_object
        boss.scale = (1.0, 1.0, 0.4)
        boss.data.materials.append(gold_mat)

    render_to(output_path, (128, 128))

def generate_drachma_coin(output_path="assets/ui/coin_drachma.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -3.2, 2.6)
    scene.camera.rotation_euler = (math.radians(52), 0, 0)
    scene.camera.data.ortho_scale = 2.2

    # Coin body
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=0.14, vertices=36, location=(0, 0, 0))
    coin = bpy.context.active_object
    gold_mat = make_pbr_material("DrachmaGold", (0.96, 0.78, 0.24, 1.0), metallic=0.92, roughness=0.22)
    coin.data.materials.append(gold_mat)

    # Raised inner rim
    bpy.ops.mesh.primitive_torus_add(major_radius=0.78, minor_radius=0.06, major_segments=32, minor_segments=12, location=(0, 0, 0.08))
    rim = bpy.context.active_object
    rim.data.materials.append(gold_mat)

    # Central classical crest
    bpy.ops.mesh.primitive_cylinder_add(radius=0.45, depth=0.08, vertices=24, location=(0, 0, 0.09))
    crest = bpy.context.active_object
    crest.data.materials.append(gold_mat)

    render_to(output_path, (128, 128))

def generate_food_amphora(output_path="assets/ui/food_amphora.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -3.4, 1.8)
    scene.camera.rotation_euler = (math.radians(30), 0, 0)
    scene.camera.data.ortho_scale = 2.6

    clay_mat = make_pbr_material("TerracottaClay", (0.78, 0.38, 0.20, 1.0), metallic=0.05, roughness=0.6)

    # Amphora belly
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.65, segments=24, ring_count=16, location=(0, 0, 0.4))
    belly = bpy.context.active_object
    belly.scale = (1.0, 1.0, 1.35)
    belly.data.materials.append(clay_mat)

    # Neck
    bpy.ops.mesh.primitive_cylinder_add(radius=0.28, depth=0.55, vertices=24, location=(0, 0, 1.25))
    neck = bpy.context.active_object
    neck.data.materials.append(clay_mat)

    # Lip
    bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.07, major_segments=24, minor_segments=10, location=(0, 0, 1.52))
    lip = bpy.context.active_object
    lip.data.materials.append(clay_mat)

    # Base foot
    bpy.ops.mesh.primitive_cylinder_add(radius=0.24, depth=0.25, vertices=20, location=(0, 0, -0.4))
    foot = bpy.context.active_object
    foot.data.materials.append(clay_mat)

    # Handles
    for side in [-1, 1]:
        bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.05, major_segments=16, minor_segments=8, location=(side * 0.52, 0, 0.95))
        handle = bpy.context.active_object
        handle.scale = (0.5, 0.5, 1.4)
        handle.data.materials.append(clay_mat)

    render_to(output_path, (128, 128))

def generate_settlement_fort(output_path="assets/map/settlement_fort.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -4.0, 3.0)
    scene.camera.rotation_euler = (math.radians(48), 0, 0)
    scene.camera.data.ortho_scale = 3.2

    stone_mat = make_pbr_material("FortStone", (0.55, 0.53, 0.50, 1.0), metallic=0.1, roughness=0.7)
    wood_mat = make_pbr_material("FortTimber", (0.42, 0.28, 0.16, 1.0), metallic=0.0, roughness=0.8)

    # Circular stone tower base
    bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=1.2, vertices=28, location=(0, 0, 0.6))
    tower = bpy.context.active_object
    tower.data.materials.append(stone_mat)

    # Timber upper battlement
    bpy.ops.mesh.primitive_cylinder_add(radius=1.05, depth=0.45, vertices=28, location=(0, 0, 1.35))
    battlement = bpy.context.active_object
    battlement.data.materials.append(wood_mat)

    # Conical tiled roof
    bpy.ops.mesh.primitive_cone_add(radius1=1.15, depth=0.75, vertices=28, location=(0, 0, 1.85))
    roof = bpy.context.active_object
    roof_mat = make_pbr_material("RedRoof", (0.68, 0.22, 0.15, 1.0), metallic=0.05, roughness=0.65)
    roof.data.materials.append(roof_mat)

    # Watchtower flag pole
    bpy.ops.mesh.primitive_cylinder_add(radius=0.04, depth=0.9, vertices=12, location=(0, 0, 2.5))
    pole = bpy.context.active_object
    pole.data.materials.append(wood_mat)

    render_to(output_path, (128, 128))

def generate_settlement_acropolis(output_path="assets/map/settlement_acropolis.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -4.8, 3.4)
    scene.camera.rotation_euler = (math.radians(46), 0, 0)
    scene.camera.data.ortho_scale = 3.6

    marble_mat = make_pbr_material("GreekMarble", (0.92, 0.90, 0.86, 1.0), metallic=0.08, roughness=0.35)
    tile_mat = make_pbr_material("TerracottaTile", (0.75, 0.28, 0.18, 1.0), metallic=0.05, roughness=0.6)

    # Stepped temple base (Stylobate)
    for i, (w, h) in enumerate([(2.2, 0.15), (2.05, 0.15), (1.9, 0.15)]):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, i * 0.14))
        step = bpy.context.active_object
        step.scale = (w, w * 0.65, 0.14)
        step.data.materials.append(marble_mat)

    # Doric columns
    col_positions = [
        (-0.8, -0.45), (-0.4, -0.45), (0.0, -0.45), (0.4, -0.45), (0.8, -0.45),
        (-0.8, 0.45), (-0.4, 0.45), (0.0, 0.45), (0.4, 0.45), (0.8, 0.45)
    ]
    for px, py in col_positions:
        bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=0.85, vertices=16, location=(px, py, 0.78))
        col = bpy.context.active_object
        col.data.materials.append(marble_mat)

    # Entablature / Roof beam
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.25))
    beam = bpy.context.active_object
    beam.scale = (1.85, 1.15, 0.18)
    beam.data.materials.append(marble_mat)

    # Pediment roof
    bpy.ops.mesh.primitive_cone_add(radius1=1.1, depth=0.45, vertices=4, location=(0, 0, 1.5))
    roof = bpy.context.active_object
    roof.scale = (1.75, 1.1, 0.8)
    roof.rotation_euler = (0, 0, math.radians(45))
    roof.data.materials.append(tile_mat)

    render_to(output_path, (160, 160))

def generate_hoplite_avatar(output_path="assets/map/hoplite_avatar.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, -4.2, 2.2)
    scene.camera.rotation_euler = (math.radians(35), 0, 0)
    scene.camera.data.ortho_scale = 3.2

    bronze_mat = make_pbr_material("CuirassBronze", (0.82, 0.58, 0.22, 1.0), metallic=0.88, roughness=0.28)
    tunic_mat = make_pbr_material("SpartanCrimson", (0.65, 0.08, 0.08, 1.0), metallic=0.05, roughness=0.6)
    plinth_mat = make_pbr_material("MarblePlinth", (0.88, 0.86, 0.82, 1.0), metallic=0.1, roughness=0.4)

    # Round marble plinth base
    bpy.ops.mesh.primitive_cylinder_add(radius=1.1, depth=0.2, vertices=32, location=(0, 0, -0.1))
    plinth = bpy.context.active_object
    plinth.data.materials.append(plinth_mat)

    # Legs & Tunic
    bpy.ops.mesh.primitive_cylinder_add(radius=0.32, depth=0.7, vertices=16, location=(0, 0, 0.45))
    tunic = bpy.context.active_object
    tunic.data.materials.append(tunic_mat)

    # Bronze Cuirass (Torso)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.36, depth=0.65, vertices=18, location=(0, 0, 1.0))
    torso = bpy.context.active_object
    torso.scale = (1.0, 0.8, 1.0)
    torso.data.materials.append(bronze_mat)

    # Corinthian Helmet
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.28, segments=20, ring_count=14, location=(0, 0, 1.55))
    helmet = bpy.context.active_object
    helmet.scale = (1.0, 1.15, 1.15)
    helmet.data.materials.append(bronze_mat)

    # Horsehair Crest
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 1.8))
    crest = bpy.context.active_object
    crest.scale = (0.08, 0.48, 0.22)
    crest_mat = make_pbr_material("BlackHorsehair", (0.1, 0.1, 0.1, 1.0), metallic=0.0, roughness=0.9)
    crest.data.materials.append(crest_mat)

    # Round Shield (Aspis) on left arm
    bpy.ops.mesh.primitive_cylinder_add(radius=0.55, depth=0.08, vertices=24, location=(-0.52, 0.1, 0.95))
    shield = bpy.context.active_object
    shield.rotation_euler = (0, math.radians(78), 0)
    shield.data.materials.append(bronze_mat)

    # Dory spear in right hand
    bpy.ops.mesh.primitive_cylinder_add(radius=0.03, depth=2.4, vertices=12, location=(0.48, 0.1, 1.1))
    spear = bpy.context.active_object
    spear.rotation_euler = (math.radians(-8), math.radians(12), 0)
    wood_mat = make_pbr_material("SpearWood", (0.45, 0.32, 0.18, 1.0), metallic=0.0, roughness=0.7)
    spear.data.materials.append(wood_mat)

    render_to(output_path, (160, 160))

def generate_greece_terrain(output_path="assets/map/greece_terrain.png"):
    clear_mesh_objects()
    scene = bpy.context.scene
    scene.camera.location = (0, 0, 5.0)
    scene.camera.rotation_euler = (0, 0, 0)
    scene.camera.data.ortho_scale = 10.0

    # Sea base plane (parchment/mediterranean sea)
    bpy.ops.mesh.primitive_plane_add(size=10.0, location=(0, 0, 0))
    sea = bpy.context.active_object
    sea_mat = make_pbr_material("AegeanSea", (0.10, 0.18, 0.26, 1.0), metallic=0.05, roughness=0.5)
    sea.data.materials.append(sea_mat)

    # Classical Greek landmasses (Peloponnese, Attica, Boeotia)
    land_mat = make_pbr_material("GreekHills", (0.22, 0.26, 0.20, 1.0), metallic=0.0, roughness=0.85)
    mountain_mat = make_pbr_material("TaygetosRock", (0.42, 0.38, 0.32, 1.0), metallic=0.0, roughness=0.9)

    # Peloponnese mass
    bpy.ops.mesh.primitive_circle_add(radius=2.8, vertices=32, fill_type='NGON', location=(-1.4, -1.2, 0.05))
    pelo = bpy.context.active_object
    pelo.scale = (1.2, 1.0, 1.0)
    pelo.data.materials.append(land_mat)

    # Attica & Boeotia mass
    bpy.ops.mesh.primitive_circle_add(radius=2.4, vertices=32, fill_type='NGON', location=(1.2, 0.8, 0.05))
    attica = bpy.context.active_object
    attica.scale = (1.1, 0.85, 1.0)
    attica.data.materials.append(land_mat)

    # Mountain ranges
    for mx, my, sz in [(-1.8, -1.0, 0.7), (-0.8, -0.6, 0.5), (0.8, 1.2, 0.6), (1.5, 0.5, 0.55)]:
        bpy.ops.mesh.primitive_cone_add(radius1=sz, depth=0.4, vertices=8, location=(mx, my, 0.15))
        mnt = bpy.context.active_object
        mnt.data.materials.append(mountain_mat)

    render_to(output_path, (512, 512))

def main():
    print("Initializing Blender Asset Pipeline...")
    setup_scene()

    generate_shield("sparta", "assets/ui/sparta_shield.png")
    generate_shield("athens", "assets/ui/athens_shield.png")
    generate_shield("thebes", "assets/ui/thebes_shield.png")
    generate_shield("corinth", "assets/ui/corinth_shield.png")
    generate_drachma_coin("assets/ui/coin_drachma.png")
    generate_food_amphora("assets/ui/food_amphora.png")
    generate_settlement_fort("assets/map/settlement_fort.png")
    generate_settlement_acropolis("assets/map/settlement_acropolis.png")
    generate_hoplite_avatar("assets/map/hoplite_avatar.png")
    generate_greece_terrain("assets/map/greece_terrain.png")

    print("ALL BLENDER ASSETS RENDERED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
