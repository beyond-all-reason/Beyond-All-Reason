"""
Blender Batch Decimate & COLLADA (.dae) Export Script for BAR / Recoil Engine.
Usage (if running inside Blender CLI):
  blender --background --python blender_decimate_export.py
"""

import os
import bpy

ASSETS_ROOT = r"C:\Users\akihungac\.gemini\antigravity\scratch\game-assets-3d"
OUT_DIR = r"C:\Users\akihungac\.gemini\antigravity\scratch\recoil-bin\games\bar-zombie-defense.sdd\objects3d\Units"

TARGETS = [
    ("zdef_zombie_walker", r"characters\zombies\models\zombie-walker.glb", 0.025),
    ("zdef_zombie_brute", r"characters\zombies\models\zombie-brute.glb", 0.035),
    ("zdef_zombie_soldier", r"characters\zombies\models\zombie-soldier.glb", 0.025),
    ("zdef_tank", r"vehicles\military\models\battle-tank.glb", 0.20),
    ("zdef_c130", r"vehicles\bombers-and-transport-planes\models\four-turboprop-airlifter.glb", 0.50),
]


def process_glb(out_name, rel_path, ratio):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    glb_path = os.path.join(ASSETS_ROOT, rel_path)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    for obj in list(bpy.data.objects):
        if obj.type == "ARMATURE":
            # Strip finger bones for RTS performance
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.mode_set(mode="EDIT")
            for bone in list(obj.data.edit_bones):
                if any(k in bone.name for k in ("Thumb", "Index", "Middle", "Ring", "Pinky")):
                    obj.data.edit_bones.remove(bone)
            bpy.ops.object.mode_set(mode="OBJECT")
        elif obj.type == "MESH":
            bpy.context.view_layer.objects.active = obj
            mod = obj.modifiers.new(name="RecoilDecimate", type="DECIMATE")
            mod.ratio = ratio
            bpy.ops.object.modifier_apply(modifier=mod.name)

    os.makedirs(OUT_DIR, exist_ok=True)
    dae_path = os.path.join(OUT_DIR, f"{out_name}.dae")
    bpy.ops.wm.collada_export(filepath=dae_path, apply_modifiers=True, triangulate=True)
    print(f"Exported {dae_path}")


if __name__ == "__main__":
    for name, rel, ratio in TARGETS:
        process_glb(name, rel, ratio)
