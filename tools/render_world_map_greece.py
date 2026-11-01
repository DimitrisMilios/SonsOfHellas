"""
Blender 5.2 High-Resolution Cartographic Greece Campaign Map Renderer.
Generates an authentic ancient Hellenic campaign world map with realistic
coastlines (Peloponnese, Attica, Boeotia, Thessaly, Macedonia, Crete, Cyclades),
mountain elevation relief, Aegean coastal shallows, and classical cartography styling.
Renders to assets/map/greece_terrain.png at 2048x1536 resolution.
"""

import bpy
import math
import os

def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'RenderSettings') and 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGB'
    scene.render.image_settings.color_depth = '8'

    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        # Deep Aegean sea ambient
        bg.inputs[0].default_value = (0.06, 0.12, 0.18, 1.0)
        bg.inputs[1].default_value = 0.5

    # Orthographic Top-Down Map Camera
    cam_data = bpy.data.cameras.new("Camera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 16.0
    cam_obj = bpy.data.objects.new("Camera", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    cam_obj.location = (0, 0, 10.0)
    cam_obj.rotation_euler = (0, 0, 0)

    # Warm Classical Mediterranean Sun
    sun_data = bpy.data.lights.new("Sun", type='SUN')
    sun_data.energy = 4.2
    sun_data.color = (1.0, 0.95, 0.85)
    sun = bpy.data.objects.new("Sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(25), math.radians(-40))

    # Rim sky fill
    fill_data = bpy.data.lights.new("Fill", type='SUN')
    fill_data.energy = 1.8
    fill_data.color = (0.65, 0.82, 1.0)
    fill = bpy.data.objects.new("Fill", fill_data)
    scene.collection.objects.link(fill)
    fill.rotation_euler = (math.radians(-30), math.radians(-30), math.radians(140))

    return scene, cam_obj

def make_pbr_material(name, base_color, metallic=0.0, roughness=0.5):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs['Base Color'].default_value = base_color
        bsdf.inputs['Metallic'].default_value = metallic
        bsdf.inputs['Roughness'].default_value = roughness
    return mat

def create_greece_geography():
    # 1. Aegean & Ionian Sea Floor
    bpy.ops.mesh.primitive_plane_add(size=24.0, location=(0, 0, -0.2))
    sea = bpy.context.active_object
    sea_mat = make_pbr_material("AegeanDeepSea", (0.08, 0.16, 0.24, 1.0), metallic=0.08, roughness=0.45)
    sea.data.materials.append(sea_mat)

    # 2. Coastal Turquoise Shallows (submerged coastal shelves around Greece)
    shallow_mat = make_pbr_material("CoastalShallows", (0.12, 0.28, 0.36, 1.0), metallic=0.05, roughness=0.55)
    shallows_data = [
        # Peloponnese coastal shelf
        (-2.2, -1.8, 3.8, 3.2),
        # Central Greece shelf
        (0.6, 0.5, 4.4, 2.8),
        # Northern Greece shelf
        (-0.2, 3.2, 5.2, 2.6),
        # Crete shelf
        (3.0, -4.8, 4.2, 1.2),
        # Cyclades shelf
        (2.6, -1.4, 3.0, 2.6)
    ]
    for sx, sy, sw, sh in shallows_data:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.05, vertices=28, location=(sx, sy, -0.05))
        c_shelf = bpy.context.active_object
        c_shelf.scale = (sw / 2.0, sh / 2.0, 1.0)
        c_shelf.data.materials.append(shallow_mat)

    # 3. Landmass Materials
    land_mat = make_pbr_material("HellenicLowland", (0.24, 0.28, 0.20, 1.0), metallic=0.0, roughness=0.85)
    highland_mat = make_pbr_material("HellenicHighland", (0.34, 0.36, 0.26, 1.0), metallic=0.0, roughness=0.9)
    mountain_mat = make_pbr_material("MountainRock", (0.48, 0.44, 0.38, 1.0), metallic=0.05, roughness=0.95)
    snow_mat = make_pbr_material("MountOlympusSnow", (0.92, 0.94, 0.96, 1.0), metallic=0.0, roughness=0.6)

    # 4. Peloponnese Mainland (Realistic 3-Finger Peninsula)
    # Core Peloponnese
    bpy.ops.mesh.primitive_cylinder_add(radius=1.8, depth=0.25, vertices=32, location=(-2.2, -1.6, 0.1))
    pelo_core = bpy.context.active_object
    pelo_core.scale = (1.2, 1.1, 1.0)
    pelo_core.data.materials.append(land_mat)

    # Peloponnese Peninsulas (Messenia, Mani/Taygetos, Cape Maleas, Argolis)
    pelo_fingers = [
        # Messenia (Southwest finger)
        (-3.2, -3.2, 0.6, 1.4, math.radians(-15)),
        # Mani / Laconia (Central southern finger)
        (-2.2, -3.6, 0.55, 1.6, math.radians(5)),
        # Cape Maleas (Southeast finger)
        (-1.2, -3.4, 0.5, 1.5, math.radians(20)),
        # Argolis peninsula (Northeast finger toward Saronic gulf)
        (-0.6, -1.4, 1.1, 0.8, math.radians(40)),
        # Achaea & Elis (Northwest coasts)
        (-3.4, -0.8, 1.2, 0.9, math.radians(-25))
    ]
    for fx, fy, fw, fl, fang in pelo_fingers:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.22, vertices=24, location=(fx, fy, 0.1))
        finger = bpy.context.active_object
        finger.scale = (fw, fl, 1.0)
        finger.rotation_euler = (0, 0, fang)
        finger.data.materials.append(land_mat)

    # 5. Isthmus of Corinth (Connecting corridor)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-0.9, -0.2, 0.12))
    isthmus = bpy.context.active_object
    isthmus.scale = (0.55, 0.35, 0.22)
    isthmus.rotation_euler = (0, 0, math.radians(35))
    isthmus.data.materials.append(land_mat)

    # 6. Central Greece: Attica, Boeotia, Phocis, Aetolia
    central_regions = [
        # Attica peninsula (Athens, Piraeus, Sounion)
        (0.8, -0.4, 1.2, 0.75, math.radians(-30)),
        # Boeotia (Thebes, Lake Copais basin)
        (0.2, 0.6, 1.4, 0.9, math.radians(10)),
        # Phocis & Delphi (Mountainous central gateway)
        (-1.0, 0.8, 1.2, 0.8, math.radians(-10)),
        # Aetolia & Acarnania (Western Greece)
        (-2.4, 1.2, 1.4, 1.1, math.radians(20))
    ]
    for cx, cy, cw, cl, cang in central_regions:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.24, vertices=24, location=(cx, cy, 0.11))
        creg = bpy.context.active_object
        creg.scale = (cw, cl, 1.0)
        creg.rotation_euler = (0, 0, cang)
        creg.data.materials.append(land_mat)

    # 7. Island of Euboea (Long island flanking eastern mainland)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.22, vertices=28, location=(1.5, 0.9, 0.11))
    euboea = bpy.context.active_object
    euboea.scale = (0.45, 2.4, 1.0)
    euboea.rotation_euler = (0, 0, math.radians(-38))
    euboea.data.materials.append(land_mat)

    # 8. Northern Greece: Thessaly Plains, Epirus, Macedonia
    north_regions = [
        # Thessaly fertile plain
        (-0.4, 2.2, 2.0, 1.4, math.radians(5)),
        # Epirus mountains (West)
        (-2.2, 2.6, 1.5, 1.6, math.radians(30)),
        # Macedonia (Pella, Thermaic gulf)
        (0.2, 3.8, 2.6, 1.5, math.radians(-5)),
        # Chalkidiki peninsula (3-pronged northern peninsula)
        (2.0, 3.6, 1.0, 0.8, math.radians(-15))
    ]
    for nx, ny, nw, nl, nang in north_regions:
        bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.25, vertices=28, location=(nx, ny, 0.12))
        nreg = bpy.context.active_object
        nreg.scale = (nw, nl, 1.0)
        nreg.rotation_euler = (0, 0, nang)
        nreg.data.materials.append(land_mat)

    # 9. Aegean Archipelago & Crete
    # Crete (Long southern barrier island)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.0, depth=0.24, vertices=32, location=(2.8, -4.8, 0.12))
    crete = bpy.context.active_object
    crete.scale = (3.8, 0.8, 1.0)
    crete.rotation_euler = (0, 0, math.radians(12))
    crete.data.materials.append(land_mat)

    # Cyclades Islands (Scattered Aegean jewels)
    islands = [
        (2.0, -1.8, 0.4),   # Melos
        (2.8, -1.4, 0.55),  # Paros & Naxos
        (2.5, -0.6, 0.35),  # Delos / Mykonos
        (1.8, -0.7, 0.45),  # Syros / Kea
        (3.6, -2.4, 0.4),   # Thera / Santorini
        (5.2, -3.2, 0.65),  # Rhodes (Eastern bastion)
        (4.2, 1.2, 0.6),    # Chios
        (3.8, 2.6, 0.7)     # Lesbos
    ]
    for ix, iy, irad in islands:
        bpy.ops.mesh.primitive_cylinder_add(radius=irad, depth=0.2, vertices=16, location=(ix, iy, 0.1))
        isl = bpy.context.active_object
        isl.data.materials.append(land_mat)

    # 10. Mountain Ranges Elevation Relief (Cones & Ridges)
    mountain_peaks = [
        # Taygetos Range (Laconia/Sparta)
        (-2.3, -2.2, 0.65, 0.65),
        (-2.5, -1.6, 0.55, 0.55),
        # Pindus Spine (Central Greece backbone)
        (-1.4, 1.4, 0.7, 0.75),
        (-1.2, 2.2, 0.8, 0.85),
        # Mount Parnassus (Delphi)
        (-0.7, 0.9, 0.6, 0.65),
        # Mount Olympus (Macedonia/Thessaly border) - Majestic snow-capped peak!
        (0.0, 3.2, 0.95, 1.1),
        # Mount Cithaeron (Boeotia/Attica border)
        (0.3, 0.2, 0.5, 0.5),
        # Cretan White Mountains (Lefka Ori)
        (2.0, -4.9, 0.6, 0.6),
        (3.2, -4.7, 0.65, 0.7)
    ]
    for px, py, prad, ph in mountain_peaks:
        bpy.ops.mesh.primitive_cone_add(radius1=prad, depth=ph, vertices=12, location=(px, py, 0.2 + ph/2.0))
        peak = bpy.context.active_object
        peak.data.materials.append(mountain_mat)

    # Mount Olympus snow cap
    bpy.ops.mesh.primitive_cone_add(radius1=0.45, depth=0.35, vertices=12, location=(0.0, 3.2, 1.0))
    olympus_snow = bpy.context.active_object
    olympus_snow.data.materials.append(snow_mat)

    # 11. Classical Compass Rose / Sunburst in upper Aegean
    gold_mat = make_pbr_material("CartoGold", (0.88, 0.72, 0.25, 1.0), metallic=0.9, roughness=0.3)
    bpy.ops.mesh.primitive_cylinder_add(radius=1.2, depth=0.08, vertices=32, location=(5.0, 3.0, 0.05))
    compass = bpy.context.active_object
    compass.data.materials.append(gold_mat)

    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=(5.0 + math.cos(rad) * 0.7, 3.0 + math.sin(rad) * 0.7, 0.1))
        arrow = bpy.context.active_object
        arrow.scale = (0.1, 0.9, 0.06)
        arrow.rotation_euler = (0, 0, rad)
        arrow.data.materials.append(gold_mat)

def render_map(output_path="assets/map/greece_terrain.png", resolution=(2048, 1536)):
    scene = bpy.context.scene
    scene.render.resolution_x = resolution[0]
    scene.render.resolution_y = resolution[1]
    scene.render.filepath = os.path.abspath(output_path)
    os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
    print(f"Rendering High-Res Cartographic Greece Campaign Map ({resolution[0]}x{resolution[1]})...")
    bpy.ops.render.render(write_still=True)
    print(f"Map successfully rendered to: {scene.render.filepath}")

def main():
    setup_scene()
    create_greece_geography()
    render_map("assets/map/greece_terrain.png", (2048, 1536))

if __name__ == "__main__":
    main()
