"""
Generate high-fidelity 2D campaign world map from open-source relief data.
Processes ETOPO1 Mediterranean relief into classical antique cartography.
Enforces mobile budget <= 2048x2048 (scaled to 2048x1006).
"""
import bpy
import numpy as np
import os

MAP_INPUT = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\assets\map\mediterranean_relief_2560.png"
MAP_OUTPUT = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\assets\map\world_campaign_map.png"
MAP_TERRAIN = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\assets\map\greece_terrain.png"
MASK_OUTPUT = r"c:\Users\dimit\Documents\GitHub\SonsOfHellas\assets\map\world_land_mask.png"

TARGET_W = 2048
TARGET_H = 1006

def process_map():
    print("Loading source map:", MAP_INPUT)
    img = bpy.data.images.load(MAP_INPUT)
    w = img.size[0]
    h = img.size[1]
    print(f"Loaded source image: {w}x{h}")
    
    # Scale within Blender to target mobile budget
    img.scale(TARGET_W, TARGET_H)
    w = TARGET_W
    h = TARGET_H
    
    raw_pixels = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(raw_pixels)
    rgba = raw_pixels.reshape((h, w, 4))
    
    # Flip vertically to top-down
    rgba = np.flipud(rgba)
    
    r = rgba[:, :, 0]
    g = rgba[:, :, 1]
    b = rgba[:, :, 2]
    
    # Land vs water mask
    is_water = (b > (r + 0.08)) & (b > (g * 0.92))
    is_land = ~is_water
    
    out_rgba = np.zeros_like(rgba)
    
    # Antique warm Hellenic terrain
    land_lum = (r * 0.35 + g * 0.55 + b * 0.10)
    out_rgba[:, :, 0] = np.where(is_land, np.clip(land_lum * 1.15 + 0.15, 0.2, 0.98) * 0.92, 0.0)
    out_rgba[:, :, 1] = np.where(is_land, np.clip(land_lum * 1.10 + 0.12, 0.2, 0.95) * 0.84, 0.0)
    out_rgba[:, :, 2] = np.where(is_land, np.clip(land_lum * 0.95 + 0.08, 0.15, 0.88) * 0.68, 0.0)
    
    # Deep Mediterranean azure
    sea_lum = (b * 0.7 + g * 0.3)
    out_rgba[:, :, 0] += np.where(is_water, np.clip(sea_lum * 0.40 + 0.05, 0.05, 0.45), 0.0)
    out_rgba[:, :, 1] += np.where(is_water, np.clip(sea_lum * 0.65 + 0.15, 0.12, 0.65), 0.0)
    out_rgba[:, :, 2] += np.where(is_water, np.clip(sea_lum * 0.90 + 0.25, 0.25, 0.88), 0.0)
    out_rgba[:, :, 3] = 1.0
    
    out_pixels_save = np.flipud(out_rgba).flatten()
    
    out_img = bpy.data.images.new("StyledWorldMap", width=w, height=h, alpha=True)
    out_img.pixels.foreach_set(out_pixels_save)
    out_img.filepath_raw = MAP_OUTPUT
    out_img.file_format = 'PNG'
    out_img.save()
    print(f"Saved styled world map ({w}x{h}) to:", MAP_OUTPUT)
    
    # Also save as greece_terrain.png
    out_img.filepath_raw = MAP_TERRAIN
    out_img.save()
    print(f"Saved terrain map ({w}x{h}) to:", MAP_TERRAIN)
    
    # Land mask 512x251
    mask_w = 512
    mask_h = 251
    land_mask = np.zeros((h, w, 4), dtype=np.float32)
    land_mask[:, :, 0] = np.where(is_land, 1.0, 0.0)
    land_mask[:, :, 1] = np.where(is_land, 1.0, 0.0)
    land_mask[:, :, 2] = np.where(is_land, 1.0, 0.0)
    land_mask[:, :, 3] = 1.0
    
    mask_img = bpy.data.images.new("LandMask", width=w, height=h, alpha=True)
    mask_img.pixels.foreach_set(np.flipud(land_mask).flatten())
    mask_img.scale(mask_w, mask_h)
    mask_img.filepath_raw = MASK_OUTPUT
    mask_img.file_format = 'PNG'
    mask_img.save()
    print(f"Saved land mask ({mask_w}x{mask_h}) to:", MASK_OUTPUT)

if __name__ == "__main__":
    process_map()
