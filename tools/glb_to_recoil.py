#!/usr/bin/env python3
"""
GLB & GoldSrc StudioMDL (.mdl) -> BAR / Recoil Engine (.s3o & .dae) Converter
+ Articulated 11-Bone Skeleton & Embedded Animation Extractor.
- Converts guer_arno.mdl (GoldSrc StudioMDL v10) into articulated zdef_infantry & zdef_paratrooper
  with its 4 embedded BMP textures, attached assault rifle, and embedded RLE animations (idle1, walk, run, ref_shoot_rifle).
- Deforms skinned GLB zombie meshes into their embedded Idle pose via 4-bone Linear Blend Skinning (no T-pose!)
  and extracts embedded GLB animations (Idle, Walk, Run, Attack).
- Applies realistic, harmonized military scales across Infantry, Zombies, Brute, MRAP, M1 Tank, A-10, C-130, and HQ.
"""

import io
import json
import math
import os
import struct
from PIL import Image
import numpy as np


COMPONENT_TYPES = {
    5120: (np.int8, 1),
    5121: (np.uint8, 1),
    5122: (np.int16, 2),
    5123: (np.uint16, 2),
    5125: (np.uint32, 4),
    5126: (np.float32, 4),
}

TYPE_COUNTS = {
    "SCALAR": 1,
    "VEC2": 2,
    "VEC3": 3,
    "VEC4": 4,
    "MAT4": 16,
}

PIECE_ORDER = [
    "hips",
    "torso",
    "head",
    "uarm_l",
    "larm_l",
    "uarm_r",
    "larm_r",
    "uleg_l",
    "lleg_l",
    "uleg_r",
    "lleg_r",
]

PIECE_PARENTS = {
    "hips": None,
    "torso": "hips",
    "head": "torso",
    "uarm_l": "torso",
    "larm_l": "uarm_l",
    "uarm_r": "torso",
    "larm_r": "uarm_r",
    "uleg_l": "hips",
    "lleg_l": "uleg_l",
    "uleg_r": "hips",
    "lleg_r": "uleg_r",
}


def load_glb(path):
    with open(path, "rb") as f:
        magic, version, total_len = struct.unpack("<III", f.read(12))
        if magic != 0x46546C67:
            raise ValueError(f"Not a valid GLB file: {path}")
        jlen, jtype = struct.unpack("<II", f.read(8))
        gltf = json.loads(f.read(jlen).decode("utf-8"))
        blen, btype = struct.unpack("<II", f.read(8))
        bin_data = f.read(blen)
    return gltf, bin_data


def get_accessor_data(gltf, bin_data, accessor_idx):
    acc = gltf["accessors"][accessor_idx]
    bv = gltf["bufferViews"][acc["bufferView"]]
    dtype, elem_bytes = COMPONENT_TYPES[acc["componentType"]]
    num_comp = TYPE_COUNTS[acc["type"]]
    count = acc["count"]
    offset = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = bv.get("byteStride", elem_bytes * num_comp)

    item_size = elem_bytes * num_comp
    if stride == item_size:
        arr = np.frombuffer(bin_data, dtype=dtype, count=count * num_comp, offset=offset)
        return arr.reshape((count, num_comp)).copy() if num_comp > 1 else arr.copy()
    else:
        out = np.empty((count, num_comp), dtype=dtype)
        for i in range(count):
            start = offset + i * stride
            out[i] = np.frombuffer(bin_data, dtype=dtype, count=num_comp, offset=start)
        return out if num_comp > 1 else out[:, 0]


def quat_to_mat3(q):
    x, y, z, w = float(q[0]), float(q[1]), float(q[2]), float(q[3])
    n = math.sqrt(x * x + y * y + z * z + w * w)
    if n > 1e-8:
        x, y, z, w = x / n, y / n, z / n, w / n
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ],
        dtype=np.float32,
    )


def trs_to_mat4(t, r, s):
    m = np.eye(4, dtype=np.float32)
    rot = quat_to_mat3(r)
    m[:3, :3] = rot * np.array(s, dtype=np.float32)[None, :]
    m[:3, 3] = np.array(t, dtype=np.float32)
    return m


def classify_joint_to_piece(joint_name):
    jn = joint_name.split(":")[-1]
    if jn in ("Hips", "Bip01", "Bip01 Pelvis", "-- R Butt", "-- L butt"):
        return "hips"
    if jn in (
        "Spine",
        "Spine1",
        "Spine2",
        "Chest",
        "LeftShoulder",
        "RightShoulder",
        "Bip01 Spine",
        "Bip01 Spine1",
        "Bip01 Spine2",
        "Bip01 Spine3",
        "Bip01 L Clavicle",
        "Bip01 R Clavicle",
        "Bomb",
    ) or "Shoulder" in jn or "shoulder" in jn:
        return "torso"
    if jn in ("Neck", "Head", "HeadTop_End", "Jaw", "Bip01 Neck", "Bip01 Head", "-- Neck smooth"):
        return "head"
    if jn in ("LeftArm", "UpperArm_L", "Bip01 L UpperArm", "-- L bicep twist", "-- L Elbow"):
        return "uarm_l"
    if (
        jn.startswith("LeftForeArm")
        or jn.startswith("LeftHand")
        or jn in ("LowerArm_L", "Hand_L", "Bip01 L Forearm", "Bip01 L Hand", "-- L wrist", "-- L knuckle")
        or jn.startswith("Bip01 L Finger")
    ):
        return "larm_l"
    if jn in ("RightArm", "UpperArm_R", "Bip01 R UpperArm", "-- R bicep twist", "-- R Elbow"):
        return "uarm_r"
    if (
        jn.startswith("RightForeArm")
        or jn.startswith("RightHand")
        or jn in ("LowerArm_R", "Hand_R", "Bip01 R Forearm", "Bip01 R Hand", "-- R wrist", "-- R knuckle")
        or jn.startswith("Bip01 R Finger")
    ):
        return "larm_r"
    if jn in ("LeftUpLeg", "UpperLeg_L", "Bip01 L Thigh", "-- L Knee"):
        return "uleg_l"
    if jn in ("LeftLeg", "LeftFoot", "LeftToeBase", "LeftToe_End", "LowerLeg_L", "Foot_L", "Bip01 L Calf", "Bip01 L Foot", "Bip01 L Toe0", "-- L ankle"):
        return "lleg_l"
    if jn in ("RightUpLeg", "UpperLeg_R", "Bip01 R Thigh", "-- R Knee"):
        return "uleg_r"
    if jn in ("RightLeg", "RightFoot", "RightToeBase", "RightToe_End", "LowerLeg_R", "Foot_R", "Bip01 R Calf", "Bip01 R Foot", "Bip01 R Toe0", "-- R Ankle"):
        return "lleg_r"
    return "torso"


def primary_joint_for_piece(gltf, skin):
    canonical_targets = {
        "hips": ("Hips",),
        "torso": ("Spine1", "Chest", "Spine"),
        "head": ("Head", "Neck"),
        "uarm_l": ("LeftArm", "UpperArm_L"),
        "larm_l": ("LeftForeArm", "LowerArm_L"),
        "uarm_r": ("RightArm", "UpperArm_R"),
        "larm_r": ("RightForeArm", "LowerArm_R"),
        "uleg_l": ("LeftUpLeg", "UpperLeg_L"),
        "lleg_l": ("LeftLeg", "LowerLeg_L"),
        "uleg_r": ("RightUpLeg", "UpperLeg_R"),
        "lleg_r": ("RightLeg", "LowerLeg_R"),
    }
    joints = skin["joints"]
    jnames = [gltf["nodes"][j].get("name", "").split(":")[-1] for j in joints]
    piece_to_jidx = {}
    for pname, candidates in canonical_targets.items():
        for cand in candidates:
            if cand in jnames:
                piece_to_jidx[pname] = jnames.index(cand)
                break
        if pname not in piece_to_jidx:
            piece_to_jidx[pname] = 0
    return piece_to_jidx


def sample_animation_clip_transforms(gltf, bin_data, anim_clip, t_norm):
    nodes = gltf.get("nodes", [])
    n_nodes = len(nodes)
    local_t = [list(n.get("translation", [0.0, 0.0, 0.0])) for n in nodes]
    local_r = [list(n.get("rotation", [0.0, 0.0, 0.0, 1.0])) for n in nodes]
    local_s = [list(n.get("scale", [1.0, 1.0, 1.0])) for n in nodes]

    if anim_clip is not None:
        max_time = 0.0
        for samp in anim_clip.get("samplers", []):
            times = get_accessor_data(gltf, bin_data, samp["input"])
            if len(times) > 0:
                max_time = max(max_time, float(times[-1]))
        t_eval = t_norm * max_time

        for ch in anim_clip.get("channels", []):
            target = ch.get("target", {})
            node_idx = target.get("node")
            path = target.get("path")
            if node_idx is None or path not in ("translation", "rotation", "scale"):
                continue
            samp = anim_clip["samplers"][ch["sampler"]]
            times = get_accessor_data(gltf, bin_data, samp["input"])
            vals = get_accessor_data(gltf, bin_data, samp["output"])
            if len(times) == 0:
                continue
            idx = int(np.searchsorted(times, t_eval, side="right")) - 1
            idx = max(0, min(len(times) - 1, idx))
            next_idx = min(len(times) - 1, idx + 1)
            dt = float(times[next_idx] - times[idx])
            alpha = float((t_eval - times[idx]) / dt) if dt > 1e-6 else 0.0
            v = (1.0 - alpha) * vals[idx] + alpha * vals[next_idx]
            if path == "translation":
                local_t[node_idx] = [float(v[0]), float(v[1]), float(v[2])]
            elif path == "rotation":
                local_r[node_idx] = [float(v[0]), float(v[1]), float(v[2]), float(v[3])]
            elif path == "scale":
                local_s[node_idx] = [float(v[0]), float(v[1]), float(v[2])]

    parent_map = {}
    for i, n in enumerate(nodes):
        for ch in n.get("children", []):
            parent_map[ch] = i

    world_mats = [None] * n_nodes

    def get_world(idx):
        if world_mats[idx] is not None:
            return world_mats[idx]
        loc = trs_to_mat4(local_t[idx], local_r[idx], local_s[idx])
        if idx in parent_map:
            world_mats[idx] = get_world(parent_map[idx]) @ loc
        else:
            world_mats[idx] = loc
        return world_mats[idx]

    for i in range(n_nodes):
        get_world(i)

    return world_mats


def mat3_to_recoil_euler(R):
    sin_x = float(np.clip(-R[1, 2], -1.0, 1.0))
    rx = math.asin(sin_x)
    cos_x = math.cos(rx)
    if abs(cos_x) > 1e-4:
        ry = math.atan2(float(R[0, 2]), float(R[2, 2]))
        rz = math.atan2(float(R[1, 0]), float(R[1, 1]))
    else:
        ry = math.atan2(float(-R[2, 0]), float(R[0, 0]))
        rz = 0.0
    return (round(rx, 4), round(ry, 4), round(rz, 4))


class PieceNode:
    def __init__(self, name, offset=(0.0, 0.0, 0.0), pos=None, norm=None, uv=None, faces=None):
        self.name = name
        self.offset = (float(offset[0]), float(offset[1]), float(offset[2]))
        self.pos = pos if pos is not None else np.zeros((0, 3), dtype=np.float32)
        self.norm = norm if norm is not None else np.zeros((0, 3), dtype=np.float32)
        self.uv = uv if uv is not None else np.zeros((0, 2), dtype=np.float32)
        self.faces = faces if faces is not None else np.zeros((0, 3), dtype=np.uint32)
        self.children = []


# ==============================================================================
# GOLDSRC STUDIOMDL v10 (.mdl) CONVERTER FOR guer_arno.mdl
# ==============================================================================
def goldsrc_angle_mat4(pos, rot):
    rx, ry, rz = float(rot[0]), float(rot[1]), float(rot[2])
    sr, cr = math.sin(rx), math.cos(rx)
    sp, cp = math.sin(ry), math.cos(ry)
    sy, cy = math.sin(rz), math.cos(rz)
    m = np.eye(4, dtype=np.float32)
    m[0, 0] = cp * cy
    m[1, 0] = cp * sy
    m[2, 0] = -sp
    m[0, 1] = sr * sp * cy - cr * sy
    m[1, 1] = sr * sp * sy + cr * cy
    m[2, 1] = sr * cp
    m[0, 2] = cr * sp * cy + sr * sy
    m[1, 2] = cr * sp * sy - sr * cy
    m[2, 2] = cr * cp
    m[0, 3], m[1, 3], m[2, 3] = float(pos[0]), float(pos[1]), float(pos[2])
    return m


def goldsrc_read_anim_val(buf, base_off, rel_off, frame, base_val, scale_val):
    if rel_off == 0:
        return base_val
    cur = base_off + rel_off
    k = frame
    while True:
        valid, total = struct.unpack_from("<BB", buf, cur)
        if total == 0:
            return base_val
        if k < total:
            idx = k if k < valid else (valid - 1)
            val = struct.unpack_from("<h", buf, cur + 2 + idx * 2)[0]
            return base_val + val * scale_val
        k -= total
        cur += 2 + valid * 2


def convert_goldsrc_mdl(mdl_path, weapon_mdl_path, target_height_elmos=14.6, tint_rgb=(1.0, 1.0, 1.0)):
    """
    Loads GoldSrc v10 guer_arno.mdl + CS 1.6 p_ak47.mdl (AKS-74U):
    - Packs all 4 embedded textures of guer_arno.mdl (slots 0..3) AND all 8 embedded textures of p_ak47.mdl (slots 4..11)
      into a single 4x4 RGBA texture atlas (512x512).
    - Poses guer_arno.mdl in his CS 1.6 2-handed rifle combat stance (upper body from seq 33 ref_aim_rifle blend 4,
      lower body from seq 1 idle1) and merges p_ak47.mdl via GoldSrc StudioMergeBones onto Bip01 R Hand (larm_r).
    - Places weapon muzzle flare piece at p_ak47.mdl's exact 'flash' bone!
    - Extracts embedded GoldSrc RLE animation sequences (idle1, walk, run, ref_shoot_rifle).
    """
    with open(mdl_path, "rb") as f:
        buf = f.read()

    ints = struct.unpack_from("<19i", buf, 136)
    (
        flags,
        numbones,
        boneindex,
        numbc,
        bcindex,
        numhb,
        hbindex,
        numseq,
        seqindex,
        numsg,
        sgindex,
        numtex,
        texindex,
        texdataindex,
        numskinref,
        numskinfam,
        skinindex,
        numbodyparts,
        bodypartindex,
    ) = ints

    C_perm = np.array([[0.0, 1.0, 0.0], [0.0, 0.0, 1.0], [1.0, 0.0, 0.0]], dtype=np.float32)

    # 1. Build 4x4 texture atlas (slots 0..3 = guer_arno.mdl, slots 4..11 = p_ak47.mdl)
    atlas_size = 512
    grid_n = 4
    tile_sz = atlas_size // grid_n
    tex1 = Image.new("RGBA", (atlas_size, atlas_size), (90, 95, 85, 0))
    tex2 = Image.new("RGBA", (atlas_size, atlas_size), (0, 22, 195, 255))

    def paste_goldsrc_tex(src_buf, t_off_entry, slot_idx, apply_tint=True):
        tflags, tw, th, toff = struct.unpack_from("<iiii", src_buf, t_off_entry + 64)
        if slot_idx < grid_n * grid_n:
            indices = np.frombuffer(src_buf, dtype=np.uint8, count=tw * th, offset=toff).reshape((th, tw))
            pal = np.frombuffer(src_buf, dtype=np.uint8, count=256 * 3, offset=toff + tw * th).reshape((256, 3))
            rgb = pal[indices].astype(np.float32)
            if apply_tint:
                rgb[:, :, 0] = np.clip(rgb[:, :, 0] * tint_rgb[0], 0, 255)
                rgb[:, :, 1] = np.clip(rgb[:, :, 1] * tint_rgb[1], 0, 255)
                rgb[:, :, 2] = np.clip(rgb[:, :, 2] * tint_rgb[2], 0, 255)
            # Resize in RGB mode FIRST! Pillow's RGBA resize premultiplies by alpha=0 and wipes all RGB channels to (0,0,0)!
            t_img = Image.fromarray(rgb.astype(np.uint8), mode="RGB").resize((tile_sz, tile_sz), Image.Resampling.BILINEAR).convert("RGBA")
            t_img.putalpha(0)
            gx, gy = slot_idx % grid_n, slot_idx // grid_n
            tex1.paste(t_img, (gx * tile_sz, gy * tile_sz))
        return (tw, th)

    tex_dims = []
    for i in range(numtex):
        tex_dims.append(paste_goldsrc_tex(buf, texindex + i * 80, i, apply_tint=True))

    # 2. Evaluate bone transforms (supporting hybrid upper-body rifle aim + lower-body movement like CS 1.6!)
    bone_names = []
    bone_parents = []
    for b in range(numbones):
        bname, parent, _ = struct.unpack_from("<32sii", buf, boneindex + b * 112)
        bone_names.append(bname.split(b"\x00")[0].decode("latin1"))
        bone_parents.append(parent)

    upper_body_pieces = {"torso", "head", "uarm_l", "larm_l", "uarm_r", "larm_r"}
    bone_is_upper = [classify_joint_to_piece(bn) in upper_body_pieces for bn in bone_names]

    def eval_bones_recoil(lower_seq_id, lower_frame=0, lower_blend=0, upper_seq_id=33, upper_frame=0, upper_blend=4):
        soff_l = seqindex + lower_seq_id * 176
        anim_l = struct.unpack_from("<i", buf, soff_l + 124)[0] + lower_blend * numbones * 12
        soff_u = seqindex + upper_seq_id * 176
        anim_u = struct.unpack_from("<i", buf, soff_u + 124)[0] + upper_blend * numbones * 12

        wm_gold = [None] * numbones
        wm_rec = [None] * numbones
        for b in range(numbones):
            b_off = boneindex + b * 112
            parent = bone_parents[b]
            bvals = struct.unpack_from("<12f", buf, b_off + 64)
            use_upper = bone_is_upper[b] and (upper_seq_id is not None)
            a_off = (anim_u if use_upper else anim_l) + b * 12
            f_use = upper_frame if use_upper else lower_frame
            r_offs = struct.unpack_from("<6H", buf, a_off)
            p = [goldsrc_read_anim_val(buf, a_off, r_offs[j], f_use, bvals[j], bvals[6 + j]) for j in range(3)]
            r = [goldsrc_read_anim_val(buf, a_off, r_offs[3 + j], f_use, bvals[3 + j], bvals[9 + j]) for j in range(3)]
            loc = goldsrc_angle_mat4(p, r)
            wm_gold[b] = (wm_gold[parent] @ loc) if parent >= 0 else loc

            m_r = np.eye(4, dtype=np.float32)
            m_r[:3, :3] = C_perm @ wm_gold[b][:3, :3] @ C_perm.T
            m_r[:3, 3] = C_perm @ wm_gold[b][:3, 3]
            wm_rec[b] = m_r
        return wm_rec, wm_gold

    canonical_gold_bones = {
        "hips": "Bip01 Pelvis",
        "torso": "Bip01 Spine2",
        "head": "Bip01 Head",
        "uarm_l": "Bip01 L UpperArm",
        "larm_l": "Bip01 L Forearm",
        "uarm_r": "Bip01 R UpperArm",
        "larm_r": "Bip01 R Forearm",
        "uleg_l": "Bip01 L Thigh",
        "lleg_l": "Bip01 L Calf",
        "uleg_r": "Bip01 R Thigh",
        "lleg_r": "Bip01 R Calf",
    }
    piece_to_bidx = {}
    for pname, btarget in canonical_gold_bones.items():
        piece_to_bidx[pname] = bone_names.index(btarget) if btarget in bone_names else 0

    # Evaluate rest pose: lower body in seq 1 (idle1), upper body in seq 33 (ref_aim_rifle, blend 4) holding rifle in 2 hands!
    idle_wm, idle_wm_gold = eval_bones_recoil(1, 0, 0, 33, 0, 4)

    # 3. Decode guer_arno.mdl bodypart 0 model 0
    nummodels, _, modelindex = struct.unpack_from("<iii", buf, bodypartindex + 64)
    _, _, nummesh, meshindex, numverts, vertinfoindex, vertindex, numnorms, norminfoindex, normindex = struct.unpack_from(
        "<if8i", buf, modelindex + 64
    )
    v_bones = np.frombuffer(buf, dtype=np.uint8, count=numverts, offset=vertinfoindex)
    v_local_g = np.frombuffer(buf, dtype=np.float32, count=numverts * 3, offset=vertindex).reshape((numverts, 3))
    n_bones = np.frombuffer(buf, dtype=np.uint8, count=numnorms, offset=norminfoindex)
    n_local_g = np.frombuffer(buf, dtype=np.float32, count=numnorms * 3, offset=normindex).reshape((numnorms, 3))

    v_world = np.zeros_like(v_local_g)
    for i in range(numverts):
        M = idle_wm[v_bones[i]]
        v_rec_loc = C_perm @ v_local_g[i]
        v_world[i] = M[:3, :3] @ v_rec_loc + M[:3, 3]

    n_world = np.zeros_like(n_local_g)
    for i in range(numnorms):
        M = idle_wm[n_bones[i]]
        n_rec_loc = C_perm @ n_local_g[i]
        n_world[i] = M[:3, :3] @ n_rec_loc

    min_y_raw = float(v_world[:, 1].min())
    max_y_raw = float(v_world[:, 1].max())
    scale = target_height_elmos / max(1.0, max_y_raw - min_y_raw)
    v_world *= scale
    min_y = float(v_world[:, 1].min())
    v_world[:, 1] -= min_y

    out_pos, out_norm, out_uv, out_pid, out_faces = [], [], [], [], []
    bone_to_pidx = [PIECE_ORDER.index(classify_joint_to_piece(bn)) for bn in bone_names]

    def decode_mdl_tristrips(src_buf, n_mesh, m_idx, s_idx, v_w, n_w, v_b_pidx, t_dims, tex_slot_offset):
        for m in range(n_mesh):
            numtris, triindex, skinref, _, _ = struct.unpack_from("<5i", src_buf, m_idx + m * 20)
            local_tex_id = struct.unpack_from("<h", src_buf, s_idx + skinref * 2)[0]
            tw, th = t_dims[min(local_tex_id, len(t_dims) - 1)]
            slot_id = min(tex_slot_offset + local_tex_id, grid_n * grid_n - 1)
            gx, gy = slot_id % grid_n, slot_id // grid_n

            cur = triindex
            while True:
                cmd = struct.unpack_from("<h", src_buf, cur)[0]
                cur += 2
                if cmd == 0:
                    break
                is_fan = cmd < 0
                count = abs(cmd)
                strip_verts = []
                for _ in range(count):
                    vi, ni, s_px, t_px = struct.unpack_from("<4h", src_buf, cur)
                    cur += 8
                    u = (gx + 0.03 + np.clip(s_px / float(max(1, tw)), 0.0, 1.0) * 0.94) / float(grid_n)
                    v = (gy + 0.03 + np.clip(t_px / float(max(1, th)), 0.0, 1.0) * 0.94) / float(grid_n)
                    idx_new = len(out_pos)
                    out_pos.append(v_w[vi])
                    out_norm.append(n_w[ni])
                    out_uv.append((u, v))
                    out_pid.append(v_b_pidx[vi])
                    strip_verts.append(idx_new)

                for k in range(count - 2):
                    if is_fan:
                        i0, i1, i2 = strip_verts[0], strip_verts[k + 1], strip_verts[k + 2]
                    else:
                        if k % 2 == 0:
                            i0, i1, i2 = strip_verts[k], strip_verts[k + 1], strip_verts[k + 2]
                        else:
                            i0, i1, i2 = strip_verts[k + 1], strip_verts[k], strip_verts[k + 2]
                    # Enforce outward-facing CCW triangle winding for Recoil/OpenGL S3O
                    # (GoldSrc MDL strips use CW winding; fixing this eliminates inside-out backface culling on head/body!)
                    p0, p1, p2 = out_pos[i0], out_pos[i1], out_pos[i2]
                    fn = np.cross(p1 - p0, p2 - p0)
                    vn = out_norm[i0] + out_norm[i1] + out_norm[i2]
                    if float(np.dot(fn, vn)) < 0.0:
                        i1, i2 = i2, i1
                    out_faces.append((i0, i1, i2))

    decode_mdl_tristrips(buf, nummesh, meshindex, skinindex, v_world, n_world, [bone_to_pidx[b] for b in v_bones], tex_dims, 0)

    # 3b. Merge CS 1.6 p_ak47.mdl (AKS-74U) using GoldSrc StudioMergeBones onto Bip01 R Hand!
    flare_rel_pos = (0.0, 0.2, 4.2)
    if weapon_mdl_path and os.path.exists(weapon_mdl_path):
        with open(weapon_mdl_path, "rb") as wf:
            wbuf = wf.read()
        wints = struct.unpack_from("<19i", wbuf, 136)
        w_nbones, w_bidx = wints[1], wints[2]
        w_seqidx = wints[8]
        w_ntex, w_texidx = wints[11], wints[12]
        w_skinidx = wints[16]
        w_bpidx = wints[18]

        w_tex_dims = []
        for i in range(w_ntex):
            w_tex_dims.append(paste_goldsrc_tex(wbuf, w_texidx + i * 80, numtex + i, apply_tint=False))

        w_animindex = struct.unpack_from("<i", wbuf, w_seqidx + 124)[0]
        w_wm_gold = [None] * w_nbones
        w_wm_rec = [None] * w_nbones
        flash_bone_idx = None

        for b in range(w_nbones):
            wb_off = w_bidx + b * 112
            wb_name_raw, wb_parent, _ = struct.unpack_from("<32sii", wbuf, wb_off)
            wb_name = wb_name_raw.split(b"\x00")[0].decode("latin1")
            if wb_name == "flash":
                flash_bone_idx = b
            if wb_name in bone_names:
                p_bidx = bone_names.index(wb_name)
                w_wm_gold[b] = idle_wm_gold[p_bidx]
            else:
                bvals = struct.unpack_from("<12f", wbuf, wb_off + 64)
                a_off = w_animindex + b * 12
                r_offs = struct.unpack_from("<6H", wbuf, a_off)
                p = [goldsrc_read_anim_val(wbuf, a_off, r_offs[j], 0, bvals[j], bvals[6 + j]) for j in range(3)]
                r = [goldsrc_read_anim_val(wbuf, a_off, r_offs[3 + j], 0, bvals[3 + j], bvals[9 + j]) for j in range(3)]
                loc = goldsrc_angle_mat4(p, r)
                w_wm_gold[b] = (w_wm_gold[wb_parent] @ loc) if wb_parent >= 0 else loc

            m_r = np.eye(4, dtype=np.float32)
            m_r[:3, :3] = C_perm @ w_wm_gold[b][:3, :3] @ C_perm.T
            m_r[:3, 3] = C_perm @ w_wm_gold[b][:3, 3]
            w_wm_rec[b] = m_r

        _, _, w_modidx = struct.unpack_from("<iii", wbuf, w_bpidx + 64)
        _, _, w_nmesh, w_meshidx, w_nverts, w_vinfoidx, w_vidx, w_nnorms, w_ninfoidx, w_nidx = struct.unpack_from(
            "<if8i", wbuf, w_modidx + 64
        )
        wv_bones = np.frombuffer(wbuf, dtype=np.uint8, count=w_nverts, offset=w_vinfoidx)
        wv_local_g = np.frombuffer(wbuf, dtype=np.float32, count=w_nverts * 3, offset=w_vidx).reshape((w_nverts, 3))
        wn_bones = np.frombuffer(wbuf, dtype=np.uint8, count=w_nnorms, offset=w_ninfoidx)
        wn_local_g = np.frombuffer(wbuf, dtype=np.float32, count=w_nnorms * 3, offset=w_nidx).reshape((w_nnorms, 3))

        wv_world = np.zeros_like(wv_local_g)
        for i in range(w_nverts):
            M = w_wm_rec[wv_bones[i]]
            wv_world[i] = (M[:3, :3] @ (C_perm @ wv_local_g[i]) + M[:3, 3]) * scale
        wv_world[:, 1] -= min_y

        # Precision AKS-74U (p_ak47.mdl) two-handed grip alignment for guer_arno:
        # Shifts the shortened AKS-74U receiver back -0.36 elmos in Z, -0.18 in Y, +0.07 in X so:
        # 1) Right Hand (Z=2.50..3.10) wraps dead-center around the pistol grip (handle.bmp -> Z=2.66)
        # 2) Left Hand (Z=5.22..6.10) wraps dead-center under the wooden handguard (forearm.bmp -> Z=5.81)
        # 3) Curved 30-rd magazine (magazine.bmp -> Z=3.94..5.07) sits cleanly between both hands with zero clipping
        # 4) Buttstock (buttstock.bmp -> Z=0.38..2.62) tucks snugly into the right shoulder pocket!
        aks_grip_offset = np.array([0.07, -0.18, -0.36], dtype=np.float32)
        wv_world += aks_grip_offset[None, :]

        wn_world = np.zeros_like(wn_local_g)
        for i in range(w_nnorms):
            M = w_wm_rec[wn_bones[i]]
            wn_world[i] = M[:3, :3] @ (C_perm @ wn_local_g[i])

        larm_r_pidx = PIECE_ORDER.index("larm_r")
        decode_mdl_tristrips(
            wbuf,
            w_nmesh,
            w_meshidx,
            w_skinidx,
            wv_world,
            wn_world,
            [larm_r_pidx] * w_nverts,
            w_tex_dims,
            numtex,
        )

        if flash_bone_idx is not None:
            flash_w = w_wm_rec[flash_bone_idx][:3, 3].copy() * scale
            flash_w[1] -= min_y
            flash_w += aks_grip_offset
            larm_piv = idle_wm[piece_to_bidx["larm_r"]][:3, 3].copy() * scale
            larm_piv[1] -= min_y
            flare_rel_pos = tuple(flash_w - larm_piv)

    pos_arr = np.array(out_pos, dtype=np.float32)
    norm_arr = np.array(out_norm, dtype=np.float32)
    uv_arr = np.array(out_uv, dtype=np.float32)
    pid_arr = np.array(out_pid, dtype=np.int32)
    faces_arr = np.array(out_faces, dtype=np.uint32)

    # 4. Build articulated 11-piece hierarchy
    piece_world_pivots = {}
    for pname in PIECE_ORDER:
        b_idx = piece_to_bidx[pname]
        piv = idle_wm[b_idx][:3, 3].copy() * scale
        piv[1] -= min_y
        piece_world_pivots[pname] = piv

    tri_piece_id = pid_arr[faces_arr[:, 0]]
    piece_nodes = {}
    for p_idx, pname in enumerate(PIECE_ORDER):
        parent_name = PIECE_PARENTS[pname]
        world_piv = piece_world_pivots[pname]
        rel_off = world_piv if parent_name is None else (world_piv - piece_world_pivots[parent_name])

        mask = tri_piece_id == p_idx
        sub_faces = faces_arr[mask]
        if len(sub_faces) > 0:
            used_verts, new_sub_faces = np.unique(sub_faces, return_inverse=True)
            sub_pos = pos_arr[used_verts] - world_piv[None, :]
            sub_norm = norm_arr[used_verts]
            sub_uv = uv_arr[used_verts]
            sub_faces_reshaped = new_sub_faces.reshape(-1, 3).astype(np.uint32)
        else:
            sub_pos = np.zeros((0, 3), dtype=np.float32)
            sub_norm = np.zeros((0, 3), dtype=np.float32)
            sub_uv = np.zeros((0, 2), dtype=np.float32)
            sub_faces_reshaped = np.zeros((0, 3), dtype=np.uint32)

        piece_nodes[pname] = PieceNode(pname, tuple(rel_off), sub_pos, sub_norm, sub_uv, sub_faces_reshaped)

    for pname, parent_name in PIECE_PARENTS.items():
        if parent_name is not None:
            piece_nodes[parent_name].children.append(piece_nodes[pname])

    piece_nodes["larm_r"].children.append(PieceNode("flare", flare_rel_pos))

    base = PieceNode("base", (0.0, 0.0, 0.0))
    base.children.append(piece_nodes["hips"])

    # 5. Extract embedded GoldSrc sequences with CS 1.6 upper/lower body blending:
    # Lower body plays Idle (seq 1), Walk (seq 3), Run (seq 4); Upper body holds AKS-74U (seq 33) or fires (seq 34)!
    seq_map = {
        "Idle": (1, 61, 0, 33, 2, 4),
        "Walk": (3, 33, 0, 33, 2, 4),
        "Run": (4, 37, 0, 33, 2, 4),
        "Attack": (1, 61, 0, 34, 6, 4),
    }
    extracted_clips = {}
    for clip_name, (l_seq, l_frames, l_blend, u_seq, u_frames, u_blend) in seq_map.items():
        num_steps = 6
        frames_list = []
        for step in range(num_steps):
            fl_eval = min(l_frames - 1, int((step / float(num_steps)) * l_frames))
            fu_eval = min(u_frames - 1, int((step / float(num_steps)) * u_frames))
            wm_t, _ = eval_bones_recoil(l_seq, fl_eval, l_blend, u_seq, fu_eval, u_blend)
            world_delta_rot = {}
            for pname in PIECE_ORDER:
                b_idx = piece_to_bidx[pname]
                R_t = wm_t[b_idx][:3, :3]
                R_idle = idle_wm[b_idx][:3, :3]
                world_delta_rot[pname] = R_t @ R_idle.T

            frame_angles = {}
            for pname in PIECE_ORDER:
                if pname in ("uarm_l", "larm_l", "uarm_r", "larm_r"):
                    # Keep both arms & hands locked in their exact 2-handed AKS-74U grip (pistol grip + wooden handguard)
                    # so the left hand never separates from the foregrip while torso handles aiming and recoil!
                    frame_angles[pname] = [0.0, 0.0, 0.0]
                else:
                    parent_name = PIECE_PARENTS[pname]
                    L_rot = world_delta_rot[pname] if parent_name is None else (world_delta_rot[parent_name].T @ world_delta_rot[pname])
                    frame_angles[pname] = mat3_to_recoil_euler(L_rot)
            frames_list.append(frame_angles)
        extracted_clips[clip_name] = frames_list

    return base, extracted_clips, tex1, tex2, len(faces_arr)


def build_material_atlas(gltf, bin_data, atlas_size=1024, grid_n=5):
    """
    Packs up to grid_n*grid_n (5x5 = 25) materials into a 1024x1024 RGBA texture atlas (tex1, tex2).
    - Guarantees every material (even models with 17 materials like A-10) has its own dedicated tile with zero collision.
    - Tiles repeating textures (2x2 or 3x3) when UVs exceed [0..1] and bakes embedded normalTexture micro-relief
      detail directly into the albedo tile so tracks, tyres, armor steel, and concrete look crisp in Recoil's S3O shader.
    - Bakes each primitive's vertex COLOR_0 (blood wounds, stains, boils, shading) AND tiled detail texture
      into Front/Back hemisphere body-space projection when COLOR_0 is present (as in all zombie GLB models),
      while also tiling non-COLOR_0 materials (Belt, Denim, Camo, Boots).
    """
    tile_sz = atlas_size // grid_n
    tex1 = Image.new("RGBA", (atlas_size, atlas_size), (128, 128, 128, 0))
    tex2 = Image.new("RGBA", (atlas_size, atlas_size), (0, 28, 0, 255))

    materials = gltf.get("materials", [])
    textures = gltf.get("textures", [])
    images = gltf.get("images", [])
    buffer_views = gltf.get("bufferViews", [])

    decoded_imgs = {}
    for idx, img_def in enumerate(images):
        if "bufferView" in img_def:
            bv = buffer_views[img_def["bufferView"]]
            off = bv.get("byteOffset", 0)
            ln = bv["byteLength"]
            raw = bin_data[off : off + ln]
            try:
                decoded_imgs[idx] = np.asarray(Image.open(io.BytesIO(raw)).convert("RGB"), dtype=np.float32)
            except Exception:
                pass

    # Pre-check if any mesh primitive uses COLOR_0 or multi-tiled UVs outside [0, 1]
    prim_color_bakes = {}
    mat_uv_spans = {}
    for mesh in gltf.get("meshes", []):
        for prim in mesh.get("primitives", []):
            attrs = prim.get("attributes", {})
            m_idx = prim.get("material", 0)
            if "TEXCOORD_0" in attrs:
                uv_check = get_accessor_data(gltf, bin_data, attrs["TEXCOORD_0"]).astype(np.float32)
                if len(uv_check) > 0:
                    span = float(max(uv_check[:, 0].max() - uv_check[:, 0].min(), uv_check[:, 1].max() - uv_check[:, 1].min()))
                    mat_uv_spans[m_idx] = max(mat_uv_spans.get(m_idx, 1.0), span)
            if "COLOR_0" in attrs and "POSITION" in attrs and m_idx not in prim_color_bakes:
                pos = get_accessor_data(gltf, bin_data, attrs["POSITION"]).astype(np.float32)
                norm = get_accessor_data(gltf, bin_data, attrs["NORMAL"]).astype(np.float32) if "NORMAL" in attrs else np.zeros_like(pos)
                uv_raw = get_accessor_data(gltf, bin_data, attrs["TEXCOORD_0"]).astype(np.float32) if "TEXCOORD_0" in attrs else None
                c0 = get_accessor_data(gltf, bin_data, attrs["COLOR_0"]).astype(np.float32)
                if c0.max() > 1.5:
                    c0 = c0 / 255.0
                prim_color_bakes[m_idx] = (pos, norm, uv_raw, c0[:, :3])

    for m_idx in range(min(len(materials), grid_n * grid_n)):
        mat = materials[m_idx]
        pbr = mat.get("pbrMetallicRoughness", {})
        factor = pbr.get("baseColorFactor", [1.0, 1.0, 1.0, 1.0])
        srgb_factor = np.array([min(255.0, max(0.0, (max(0.0, c) ** (1.0 / 2.2)) * 255.0)) for c in factor[:3]], dtype=np.float32)

        gx = m_idx % grid_n
        gy = m_idx // grid_n
        x0, y0 = gx * tile_sz, gy * tile_sz

        base_tex_info = pbr.get("baseColorTexture")
        src_arr = None
        if base_tex_info is not None:
            tex_idx = base_tex_info.get("index", 0)
            if tex_idx < len(textures):
                src_idx = textures[tex_idx].get("source", tex_idx)
                if src_idx in decoded_imgs:
                    src_arr = decoded_imgs[src_idx]

        norm_tex_info = mat.get("normalTexture")
        norm_arr = None
        if norm_tex_info is not None:
            ntex_idx = norm_tex_info.get("index", 0)
            if ntex_idx < len(textures):
                nsrc_idx = textures[ntex_idx].get("source", ntex_idx)
                if nsrc_idx in decoded_imgs:
                    norm_arr = decoded_imgs[nsrc_idx]

        # Build base tile array (tile_sz x tile_sz x 3)
        if src_arr is not None:
            # If the primitive uses multi-tiled UVs (e.g. Tank track, MRAP tyre, HQ concrete, Zombie belt),
            # repeat the embedded texture 2x2 inside the tile so surface detail is crisp and dense!
            uv_span = mat_uv_spans.get(m_idx, 1.0)
            if uv_span > 2.2 and m_idx not in prim_color_bakes:
                rep = 3 if uv_span > 8.0 else 2
                tiled_src = np.tile(src_arr, (rep, rep, 1))
                base_pil = Image.fromarray(tiled_src.astype(np.uint8), mode="RGB").resize((tile_sz, tile_sz), Image.Resampling.BILINEAR)
            else:
                base_pil = Image.fromarray(src_arr.astype(np.uint8), mode="RGB").resize((tile_sz, tile_sz), Image.Resampling.BILINEAR)
            tile_rgb = np.asarray(base_pil, dtype=np.float32).copy()
            if "baseColorFactor" in pbr:
                tile_rgb *= srgb_factor[None, None, :] / 255.0

            # Bake embedded normalTexture micro-relief lighting into the tile (since S3O has no tangent-space normal map slot)
            if norm_arr is not None:
                uv_span = mat_uv_spans.get(m_idx, 1.0)
                if uv_span > 2.2 and m_idx not in prim_color_bakes:
                    rep = 3 if uv_span > 8.0 else 2
                    tiled_n = np.tile(norm_arr, (rep, rep, 1))
                    n_pil = Image.fromarray(tiled_n.astype(np.uint8), mode="RGB").resize((tile_sz, tile_sz), Image.Resampling.BILINEAR)
                else:
                    n_pil = Image.fromarray(norm_arr.astype(np.uint8), mode="RGB").resize((tile_sz, tile_sz), Image.Resampling.BILINEAR)
                n_rgb = (np.asarray(n_pil, dtype=np.float32) / 127.5) - 1.0
                # Directional micro-relief from normal map (light from top-left-front)
                relief = np.clip(0.88 + 0.22 * n_rgb[:, :, 0] + 0.25 * n_rgb[:, :, 1] + 0.15 * n_rgb[:, :, 2], 0.68, 1.25)
                tile_rgb = np.clip(tile_rgb * relief[:, :, None], 0.0, 255.0)
        else:
            # High-detail procedural military aviation / armor skin texture for solid PBR materials (C-130, A-10, F-16, Tank, MRAP, HQ)
            yy_px, xx_px = np.mgrid[0:tile_sz, 0:tile_sz].astype(np.float32)
            yy = yy_px / float(max(1, tile_sz - 1))
            xx = xx_px / float(max(1, tile_sz - 1))

            # 1) Staggered aircraft/armor panel grid (panel seams + highlight bevel + per-panel tonal variation)
            panel_h = 34.0
            panel_w = 51.0
            row_id = np.floor(yy_px / panel_h)
            stagger_x = xx_px + (row_id % 2.0) * (panel_w * 0.5)
            col_id = np.floor(stagger_x / panel_w)

            local_y = yy_px % panel_h
            local_x = stagger_x % panel_w

            # Crisp dark seam line (1.5px) + bright adjacent bevel edge (1.5px)
            is_seam = (local_y < 1.6) | (local_x < 1.6)
            is_bevel = ((local_y >= 1.6) & (local_y < 3.2)) | ((local_x >= 1.6) & (local_x < 3.2))

            # Deterministic per-panel paint tone variation (+/- 7%)
            panel_hash = np.sin(row_id * 12.9898 + col_id * 78.233 + m_idx * 3.17) * 43758.5453
            panel_var = (panel_hash - np.floor(panel_hash)) * 0.13 - 0.065

            # Rivet dots along panel borders every 8px
            rivet_y = (np.abs(local_y - 4.5) < 1.1) & ((np.floor(stagger_x) % 8.0) < 1.6)
            rivet_x = (np.abs(local_x - 4.5) < 1.1) & ((np.floor(yy_px) % 8.0) < 1.6)
            is_rivet = rivet_y | rivet_x

            # Subtle weathered airframe streaking & micro-grain along airflow (Y/X)
            streak = 0.035 * np.sin(xx * math.pi * 6.0 + yy * 2.5) + 0.025 * np.cos(yy * math.pi * 10.0)
            grain_hash = np.sin(xx_px * 19.13 + yy_px * 47.71 + m_idx) * 15731.7
            grain = ((grain_hash - np.floor(grain_hash)) - 0.5) * 0.045

            shade = 0.96 + 0.10 * (1.0 - yy) + panel_var + streak + grain
            shade = np.where(is_bevel, shade * 1.09, shade)
            shade = np.where(is_rivet, shade * 0.84, shade)
            shade = np.where(is_seam, shade * 0.72, shade)

            # Boost overly dark paint materials slightly so panel details & contours remain clearly visible in-game
            base_c = srgb_factor.copy()
            mat_name = mat.get("name", "")
            if "Paint" in mat_name and base_c.max() < 65.0:
                base_c = np.clip(base_c * 1.45 + 22.0, 0.0, 255.0)
            elif "Canopy" in mat_name or "Glass" in mat_name:
                # Give aircraft cockpit canopy a crisp armoured-glass teal/blue gradient with frame reflection
                base_c = np.array([72.0, 118.0, 152.0], dtype=np.float32)
                shade = 0.85 + 0.35 * np.sin(xx * math.pi) * (1.0 - yy * 0.5)

            tile_rgb = np.clip(base_c[None, None, :] * shade[:, :, None], 0.0, 255.0)

        # If this material has hand-painted vertex COLOR_0 (blood wounds, stains, boils, shading),
        # bake the combined (baseColorFactor * TiledDetailTex * NormalRelief * COLOR_0) into front/back body-space UV map!
        if m_idx in prim_color_bakes:
            pos, norm, uv_raw, c0_rgb = prim_color_bakes[m_idx]
            if src_arr is not None and uv_raw is not None:
                th, tw, _ = src_arr.shape
                u_wrapped = np.mod(uv_raw[:, 0], 1.0)
                v_wrapped = np.mod(uv_raw[:, 1], 1.0)
                px = np.clip((u_wrapped * (tw - 1)).astype(np.int32), 0, tw - 1)
                py = np.clip((v_wrapped * (th - 1)).astype(np.int32), 0, th - 1)
                v_tex_rgb = src_arr[py, px] * (srgb_factor[None, :] / 255.0)
                if norm_arr is not None and norm_arr.shape[:2] == (th, tw):
                    vn = (norm_arr[py, px] / 127.5) - 1.0
                    v_rel = np.clip(0.88 + 0.22 * vn[:, 0] + 0.25 * vn[:, 1] + 0.15 * vn[:, 2], 0.70, 1.22)
                    v_tex_rgb *= v_rel[:, None]
            else:
                v_tex_rgb = np.broadcast_to(srgb_factor[None, :], (len(pos), 3)).copy()

            # Multiply by vertex COLOR_0 (sRGB blood/wound/shading)
            v_final_rgb = np.clip(v_tex_rgb * c0_rgb, 0.0, 255.0)

            # Project vertices onto Front (left half of tile) and Back (right half of tile) in (X, Y) body space
            pmin = pos.min(axis=0)
            pmax = pos.max(axis=0)
            span_x = max(1e-4, float(pmax[0] - pmin[0]))
            span_y = max(1e-4, float(pmax[1] - pmin[1]))
            nx_norm = np.clip((pos[:, 0] - pmin[0]) / span_x, 0.0, 1.0)
            ny_norm = np.clip((pos[:, 1] - pmin[1]) / span_y, 0.0, 1.0)
            is_front = norm[:, 2] >= -0.05
            u_local = np.where(is_front, 0.04 + nx_norm * 0.43, 0.53 + nx_norm * 0.43)
            v_local = 0.04 + (1.0 - ny_norm) * 0.92

            # Splat vertex colors with a 5x5 Gaussian kernel onto tile_rgb for smooth coverage across 204x204 tile
            acc_rgb = tile_rgb * 0.25
            acc_w = np.full((tile_sz, tile_sz, 1), 0.25, dtype=np.float32)
            tx_i = np.clip((u_local * (tile_sz - 1)).astype(np.int32), 2, tile_sz - 3)
            ty_i = np.clip((v_local * (tile_sz - 1)).astype(np.int32), 2, tile_sz - 3)
            for dy in (-2, -1, 0, 1, 2):
                for dx in (-2, -1, 0, 1, 2):
                    dist2 = dx * dx + dy * dy
                    w_k = 1.0 if dist2 == 0 else (0.65 if dist2 == 1 else (0.40 if dist2 == 2 else 0.20))
                    np.add.at(acc_rgb, (ty_i + dy, tx_i + dx), v_final_rgb * w_k)
                    np.add.at(acc_w, (ty_i + dy, tx_i + dx), w_k)
            tile_rgb = acc_rgb / np.maximum(acc_w, 1e-4)

        rgba = np.zeros((tile_sz, tile_sz, 4), dtype=np.uint8)
        rgba[:, :, :3] = np.clip(tile_rgb, 0, 255).astype(np.uint8)
        rgba[:, :, 3] = 0
        tex1.paste(Image.fromarray(rgba, mode="RGBA"), (x0, y0))

        metallic = float(pbr.get("metallicFactor", 0.05))
        roughness = float(pbr.get("roughnessFactor", 0.75))
        mat_name = mat.get("name", "")
        if "Paint" in mat_name or "Camo" in mat_name or "Olive" in mat_name:
            # Military tactical paint should be matte/satin (high roughness, low metalness) so it shows texture panels clearly!
            metallic = min(metallic, 0.12)
            roughness = max(roughness, 0.74)
        # In BAR CUS GL4 (cus_gl4.frag.glsl):
        # texColor2.r = emissiveness, texColor2.g = metalness, texColor2.b = roughness, texColor2.a = alpha (1.0 = opaque)
        metal_byte = int(min(235, max(5, metallic * 255.0)))
        rough_byte = int(min(245, max(135, roughness * 255.0)))
        emiss_byte = 180 if ("Lamp" in mat.get("name", "") or "Screen" in mat.get("name", "")) else 0
        t2_tile = Image.new("RGBA", (tile_sz, tile_sz), (emiss_byte, metal_byte, rough_byte, 255))
        tex2.paste(t2_tile, (x0, y0))

    return tex1, tex2, grid_n


def extract_mesh_geometry(gltf, bin_data, mesh_idx, grid_n=5, scale=1.0, return_skin=False):
    mesh = gltf["meshes"][mesh_idx]
    all_pos, all_norm, all_uv, all_idx = [], [], [], []
    all_joints, all_weights = [], []
    v_offset = 0

    for prim in mesh.get("primitives", []):
        if prim.get("mode", 4) != 4:
            continue
        attrs = prim["attributes"]
        if "POSITION" not in attrs:
            continue
        pos_raw = get_accessor_data(gltf, bin_data, attrs["POSITION"]).astype(np.float32)
        pos = pos_raw * scale
        n_verts = len(pos)

        if "NORMAL" in attrs:
            norm = get_accessor_data(gltf, bin_data, attrs["NORMAL"]).astype(np.float32)
        else:
            norm = np.zeros_like(pos)
            norm[:, 1] = 1.0

        mat_idx = min(prim.get("material", 0), grid_n * grid_n - 1)
        gx = mat_idx % grid_n
        gy = mat_idx // grid_n

        if "COLOR_0" in attrs:
            # Match continuous Front/Back body-space UV projection baked in build_material_atlas!
            pmin = pos_raw.min(axis=0)
            pmax = pos_raw.max(axis=0)
            span_x = max(1e-4, float(pmax[0] - pmin[0]))
            span_y = max(1e-4, float(pmax[1] - pmin[1]))
            nx_norm = np.clip((pos_raw[:, 0] - pmin[0]) / span_x, 0.0, 1.0)
            ny_norm = np.clip((pos_raw[:, 1] - pmin[1]) / span_y, 0.0, 1.0)
            is_front = norm[:, 2] >= -0.05
            u_local = np.where(is_front, 0.04 + nx_norm * 0.43, 0.53 + nx_norm * 0.43)
            v_local = 0.04 + (1.0 - ny_norm) * 0.92
            u_mapped = (gx + u_local) / float(grid_n)
            v_mapped = (gy + v_local) / float(grid_n)
        else:
            if "TEXCOORD_0" in attrs:
                uv = np.mod(get_accessor_data(gltf, bin_data, attrs["TEXCOORD_0"]).astype(np.float32), 1.0)
            else:
                # Generate 3D tri-planar / box-projected UV coordinates from vertex positions & normals
                # so untextured GLB meshes (C-130, A-10, F-16, Tank, MRAP, HQ) map across the entire 204x204 riveted panel tile!
                pmin = pos_raw.min(axis=0)
                pmax = pos_raw.max(axis=0)
                span = np.maximum(1e-4, pmax - pmin)
                n_pos = (pos_raw - pmin[None, :]) / span[None, :]
                abs_n = np.abs(norm)
                # Blend top-down (X, Z) and side (Z, Y) projections based on surface normal
                top_mask = (abs_n[:, 1] >= abs_n[:, 0]) & (abs_n[:, 1] >= abs_n[:, 2])
                side_mask = (abs_n[:, 0] > abs_n[:, 1]) & (abs_n[:, 0] >= abs_n[:, 2])
                u_box = np.where(top_mask, n_pos[:, 0], np.where(side_mask, n_pos[:, 2], n_pos[:, 0]))
                v_box = np.where(top_mask, n_pos[:, 2], np.where(side_mask, 1.0 - n_pos[:, 1], 1.0 - n_pos[:, 1]))
                uv = np.stack([np.clip(u_box, 0.0, 1.0), np.clip(v_box, 0.0, 1.0)], axis=1).astype(np.float32)
            u_mapped = (gx + 0.04 + uv[:, 0] * 0.92) / float(grid_n)
            v_mapped = (gy + 0.04 + uv[:, 1] * 0.92) / float(grid_n)

        uv_atlas = np.stack([u_mapped, v_mapped], axis=1).astype(np.float32)

        if return_skin and "JOINTS_0" in attrs and "WEIGHTS_0" in attrs:
            j0 = get_accessor_data(gltf, bin_data, attrs["JOINTS_0"]).astype(np.int32)
            w0 = get_accessor_data(gltf, bin_data, attrs["WEIGHTS_0"]).astype(np.float32)
        else:
            j0 = np.zeros((n_verts, 4), dtype=np.int32)
            w0 = np.zeros((n_verts, 4), dtype=np.float32)
            w0[:, 0] = 1.0

        if "indices" in prim:
            idx = get_accessor_data(gltf, bin_data, prim["indices"]).astype(np.uint32).reshape(-1, 3)
        else:
            idx = np.arange(n_verts, dtype=np.uint32).reshape(-1, 3)

        all_pos.append(pos)
        all_norm.append(norm)
        all_uv.append(uv_atlas)
        all_idx.append(idx + v_offset)
        all_joints.append(j0)
        all_weights.append(w0)
        v_offset += n_verts

    if not all_pos:
        empty_p = np.zeros((0, 3), dtype=np.float32)
        empty_uv = np.zeros((0, 2), dtype=np.float32)
        empty_f = np.zeros((0, 3), dtype=np.uint32)
        if return_skin:
            return empty_p, empty_p, empty_uv, empty_f, np.zeros((0, 4), dtype=np.int32), np.zeros((0, 4), dtype=np.float32)
        return empty_p, empty_p, empty_uv, empty_f

    if return_skin:
        return (
            np.vstack(all_pos),
            np.vstack(all_norm),
            np.vstack(all_uv),
            np.vstack(all_idx),
            np.vstack(all_joints),
            np.vstack(all_weights),
        )
    return np.vstack(all_pos), np.vstack(all_norm), np.vstack(all_uv), np.vstack(all_idx)


def decimate_mesh_grid(pos, norm, uv, faces, target_tris, vert_piece_id=None, grid_n=5):
    orig_tris = len(faces)
    if orig_tris <= target_tris or orig_tris == 0:
        if orig_tris > 0 and len(pos) > 0:
            e1 = pos[faces[:, 1]] - pos[faces[:, 0]]
            e2 = pos[faces[:, 2]] - pos[faces[:, 0]]
            fn = np.cross(e1, e2)
            vn = (norm[faces[:, 0]] + norm[faces[:, 1]] + norm[faces[:, 2]]) / 3.0
            flip_mask = (fn * vn).sum(axis=1) < 0
            if np.any(flip_mask):
                faces = faces.copy()
                faces[flip_mask] = faces[flip_mask][:, [0, 2, 1]]
        return pos, norm, uv, faces, vert_piece_id

    bbox_min = pos.min(axis=0)
    bbox_max = pos.max(axis=0)
    extent = float(np.max(bbox_max - bbox_min))
    if extent < 1e-6:
        return pos, norm, uv, faces, vert_piece_id

    g_flt = float(grid_n)
    tile_id = np.floor(uv[:, 0] * g_flt).astype(np.int64) * int(grid_n) + np.floor(uv[:, 1] * g_flt).astype(np.int64)
    p_id = vert_piece_id.astype(np.int64) if vert_piece_id is not None else np.zeros(len(pos), dtype=np.int64)
    # Classify vertex normals into 6 primary axis directions (+X, -X, +Y, -Y, +Z, -Z) so top/bottom wing surfaces
    # and opposite hull walls never collapse into each other while still allowing clean decimation on organic meshes!
    abs_n = np.abs(norm)
    dom_axis = np.argmax(abs_n, axis=1).astype(np.int64)
    dom_sign = (np.take_along_axis(norm, dom_axis[:, None], axis=1)[:, 0] >= 0).astype(np.int64)
    n_oct = dom_axis * 2 + dom_sign

    low_res = 2.0
    high_res = 320.0
    best_result = (pos, norm, uv, faces, vert_piece_id)
    best_diff = abs(orig_tris - target_tris)

    for _ in range(13):
        mid_res = 0.5 * (low_res + high_res)
        cell_size = extent / mid_res
        q = np.floor((pos - bbox_min) / cell_size).astype(np.int64)
        keys = (q[:, 0] << 48) ^ (q[:, 1] << 32) ^ (q[:, 2] << 16) ^ (n_oct << 10) ^ (p_id << 5) ^ tile_id
        unique_keys, first_idx, inv = np.unique(keys, return_index=True, return_inverse=True)

        f_new = inv[faces]
        valid = (f_new[:, 0] != f_new[:, 1]) & (f_new[:, 1] != f_new[:, 2]) & (f_new[:, 0] != f_new[:, 2])
        f_valid = f_new[valid]
        n_tris = len(f_valid)

        diff = abs(n_tris - target_tris)
        if n_tris > 0 and diff < best_diff:
            best_diff = diff
            n_clusters = len(unique_keys)
            new_pos = np.zeros((n_clusters, 3), dtype=np.float32)
            new_norm = np.zeros((n_clusters, 3), dtype=np.float32)
            counts = np.bincount(inv, minlength=n_clusters).astype(np.float32)[:, None]
            for d in range(3):
                new_pos[:, d] = np.bincount(inv, weights=pos[:, d], minlength=n_clusters)
                new_norm[:, d] = np.bincount(inv, weights=norm[:, d], minlength=n_clusters)
            new_pos /= np.maximum(counts, 1.0)
            norm_len = np.linalg.norm(new_norm, axis=1, keepdims=True)
            new_norm = np.where(norm_len > 1e-6, new_norm / np.maximum(norm_len, 1e-6), np.array([0.0, 1.0, 0.0], dtype=np.float32))
            new_uv = uv[first_idx]
            new_pid = vert_piece_id[first_idx] if vert_piece_id is not None else None

            # Enforce 100% consistent triangle winding with vertex normals so gl.Culling(GL.BACK) never creates holes!
            e1 = new_pos[f_valid[:, 1]] - new_pos[f_valid[:, 0]]
            e2 = new_pos[f_valid[:, 2]] - new_pos[f_valid[:, 0]]
            fn = np.cross(e1, e2)
            vn = (new_norm[f_valid[:, 0]] + new_norm[f_valid[:, 1]] + new_norm[f_valid[:, 2]]) / 3.0
            flip_mask = (fn * vn).sum(axis=1) < 0
            if np.any(flip_mask):
                f_valid = f_valid.copy()
                f_valid[flip_mask] = f_valid[flip_mask][:, [0, 2, 1]]

            best_result = (new_pos, new_norm.astype(np.float32), new_uv.astype(np.float32), f_valid.astype(np.uint32), new_pid)

        if n_tris < target_tris:
            low_res = mid_res
        else:
            high_res = mid_res

    return best_result


def build_articulated_character(gltf, bin_data, scale, target_tris, grid_n=4):
    skin = gltf["skins"][0]
    joints = skin["joints"]
    n_joints = len(joints)
    ibm_raw = get_accessor_data(gltf, bin_data, skin["inverseBindMatrices"]).reshape(-1, 4, 4)
    ibm = np.transpose(ibm_raw, (0, 2, 1)).astype(np.float32)

    anims_by_name = {a.get("name", f"anim_{i}"): a for i, a in enumerate(gltf.get("animations", []))}
    idle_clip = anims_by_name.get("Idle")

    idle_world_nodes = sample_animation_clip_transforms(gltf, bin_data, idle_clip, 0.0)
    skin_mats = np.zeros((n_joints, 4, 4), dtype=np.float32)
    idle_joint_world = np.zeros((n_joints, 4, 4), dtype=np.float32)
    for j_idx, node_idx in enumerate(joints):
        w_mat = idle_world_nodes[node_idx]
        idle_joint_world[j_idx] = w_mat
        skin_mats[j_idx] = w_mat @ ibm[j_idx]

    pos_raw, norm_raw, uv, faces, j0, w0 = extract_mesh_geometry(gltf, bin_data, 0, grid_n, 1.0, return_skin=True)
    w_sum = np.maximum(w0.sum(axis=1, keepdims=True), 1e-6)
    w_norm = w0 / w_sum

    M_vert = (
        w_norm[:, 0, None, None] * skin_mats[j0[:, 0]]
        + w_norm[:, 1, None, None] * skin_mats[j0[:, 1]]
        + w_norm[:, 2, None, None] * skin_mats[j0[:, 2]]
        + w_norm[:, 3, None, None] * skin_mats[j0[:, 3]]
    )
    ones = np.ones((len(pos_raw), 1), dtype=np.float32)
    pos_h = np.hstack([pos_raw, ones])[:, :, None]
    pos_idle = (M_vert @ pos_h)[:, :3, 0] * scale

    norm_idle = (M_vert[:, :3, :3] @ norm_raw[:, :, None])[:, :, 0]
    n_len = np.linalg.norm(norm_idle, axis=1, keepdims=True)
    norm_idle = np.where(n_len > 1e-6, norm_idle / np.maximum(n_len, 1e-6), norm_raw)

    min_y = float(pos_idle[:, 1].min())
    pos_idle[:, 1] -= min_y

    joint_to_pidx = np.zeros(n_joints, dtype=np.int32)
    for j_idx, node_idx in enumerate(joints):
        jname = gltf["nodes"][node_idx].get("name", "")
        pname = classify_joint_to_piece(jname)
        joint_to_pidx[j_idx] = PIECE_ORDER.index(pname)

    vert_piece_scores = np.zeros((len(pos_idle), len(PIECE_ORDER)), dtype=np.float32)
    for k in range(4):
        p_indices = joint_to_pidx[j0[:, k]]
        np.add.at(vert_piece_scores, (np.arange(len(pos_idle)), p_indices), w_norm[:, k])
    vert_piece_id = np.argmax(vert_piece_scores, axis=1).astype(np.int32)

    pos_dec, norm_dec, uv_dec, faces_dec, pid_dec = decimate_mesh_grid(
        pos_idle, norm_idle, uv, faces, target_tris, vert_piece_id
    )

    piece_to_jidx = primary_joint_for_piece(gltf, skin)
    piece_world_pivots = {}
    for pname in PIECE_ORDER:
        j_idx = piece_to_jidx[pname]
        pivot = idle_joint_world[j_idx][:3, 3].copy() * scale
        pivot[1] -= min_y
        piece_world_pivots[pname] = pivot

    tri_piece_id = pid_dec[faces_dec[:, 0]]
    piece_nodes = {}
    for p_idx, pname in enumerate(PIECE_ORDER):
        parent_name = PIECE_PARENTS[pname]
        world_piv = piece_world_pivots[pname]
        rel_off = world_piv if parent_name is None else (world_piv - piece_world_pivots[parent_name])

        mask = tri_piece_id == p_idx
        sub_faces = faces_dec[mask]
        if len(sub_faces) > 0:
            used_verts, new_sub_faces = np.unique(sub_faces, return_inverse=True)
            sub_pos = pos_dec[used_verts] - world_piv[None, :]
            sub_norm = norm_dec[used_verts]
            sub_uv = uv_dec[used_verts]
            sub_faces_reshaped = new_sub_faces.reshape(-1, 3).astype(np.uint32)
        else:
            sub_pos = np.zeros((0, 3), dtype=np.float32)
            sub_norm = np.zeros((0, 3), dtype=np.float32)
            sub_uv = np.zeros((0, 2), dtype=np.float32)
            sub_faces_reshaped = np.zeros((0, 3), dtype=np.uint32)

        piece_nodes[pname] = PieceNode(pname, tuple(rel_off), sub_pos, sub_norm, sub_uv, sub_faces_reshaped)

    for pname, parent_name in PIECE_PARENTS.items():
        if parent_name is not None:
            piece_nodes[parent_name].children.append(piece_nodes[pname])

    piece_nodes["torso"].children.append(PieceNode("flare", (0.0, 2.0, 5.0)))

    base = PieceNode("base", (0.0, 0.0, 0.0))
    base.children.append(piece_nodes["hips"])

    extracted_clips = {}
    for clip_name in ("Idle", "Walk", "Run", "Attack", "Bite", "Hit", "Death", "Scream"):
        clip = anims_by_name.get(clip_name)
        if clip is None and clip_name == "Attack":
            clip = anims_by_name.get("Bite") or anims_by_name.get("Run")
        if clip is None:
            continue

        num_steps = 6
        frames_list = []
        for step in range(num_steps):
            # For Death clip, include the final lying-down pose at t_norm = 0.98 on step 5!
            t_norm = (step / float(num_steps - 1)) * 0.98 if clip_name == "Death" else (step / float(num_steps))
            w_nodes = sample_animation_clip_transforms(gltf, bin_data, clip, t_norm)
            world_delta_rot = {}
            for pname in PIECE_ORDER:
                j_idx = piece_to_jidx[pname]
                node_idx = joints[j_idx]
                R_t = w_nodes[node_idx][:3, :3]
                R_t = R_t / np.maximum(np.linalg.norm(R_t, axis=0, keepdims=True), 1e-6)
                R_idle = idle_joint_world[j_idx][:3, :3]
                R_idle = R_idle / np.maximum(np.linalg.norm(R_idle, axis=0, keepdims=True), 1e-6)
                world_delta_rot[pname] = R_t @ R_idle.T

            frame_angles = {}
            for pname in PIECE_ORDER:
                if pname in ("uarm_l", "larm_l", "uarm_r", "larm_r"):
                    # Keep both arms & hands locked in their exact 2-handed AKS-74U grip (pistol grip + wooden handguard)
                    # so the left hand never separates from the foregrip while torso handles aiming and recoil!
                    frame_angles[pname] = [0.0, 0.0, 0.0]
                else:
                    parent_name = PIECE_PARENTS[pname]
                    L_rot = world_delta_rot[pname] if parent_name is None else (world_delta_rot[parent_name].T @ world_delta_rot[pname])
                    frame_angles[pname] = mat3_to_recoil_euler(L_rot)
            frames_list.append(frame_angles)

        extracted_clips[clip_name] = frames_list

    return base, extracted_clips


def build_death_corpse_piece(gltf, bin_data, scale, target_tris=850, grid_n=4):
    """
    Deforms the character mesh into the final lying-down frame (t=0.98) of its embedded 'Death'
    animation clip via 4-bone Linear Blend Skinning (LBS), returning a static corpse PieceNode
    for use as the unit's dead feature (zdef_zombie_*_dead.s3o).
    """
    skin = gltf["skins"][0]
    joints = skin["joints"]
    n_joints = len(joints)
    ibm_raw = get_accessor_data(gltf, bin_data, skin["inverseBindMatrices"]).reshape(-1, 4, 4)
    ibm = np.transpose(ibm_raw, (0, 2, 1)).astype(np.float32)

    anims_by_name = {a.get("name", f"anim_{i}"): a for i, a in enumerate(gltf.get("animations", []))}
    death_clip = anims_by_name.get("Death") or anims_by_name.get("Idle")

    death_world_nodes = sample_animation_clip_transforms(gltf, bin_data, death_clip, 0.98)
    skin_mats = np.zeros((n_joints, 4, 4), dtype=np.float32)
    for j_idx, node_idx in enumerate(joints):
        skin_mats[j_idx] = death_world_nodes[node_idx] @ ibm[j_idx]

    pos_raw, norm_raw, uv, faces, j0, w0 = extract_mesh_geometry(gltf, bin_data, 0, grid_n, 1.0, return_skin=True)
    w_sum = np.maximum(w0.sum(axis=1, keepdims=True), 1e-6)
    w_norm = w0 / w_sum

    M_vert = (
        w_norm[:, 0, None, None] * skin_mats[j0[:, 0]]
        + w_norm[:, 1, None, None] * skin_mats[j0[:, 1]]
        + w_norm[:, 2, None, None] * skin_mats[j0[:, 2]]
        + w_norm[:, 3, None, None] * skin_mats[j0[:, 3]]
    )
    ones = np.ones((len(pos_raw), 1), dtype=np.float32)
    pos_h = np.hstack([pos_raw, ones])[:, :, None]
    pos_dead = (M_vert @ pos_h)[:, :3, 0] * scale

    norm_dead = (M_vert[:, :3, :3] @ norm_raw[:, :, None])[:, :, 0]
    n_len = np.linalg.norm(norm_dead, axis=1, keepdims=True)
    norm_dead = np.where(n_len > 1e-6, norm_dead / np.maximum(n_len, 1e-6), norm_raw)

    # Rest lying corpse flat on ground y=0
    min_y = float(pos_dead[:, 1].min())
    pos_dead[:, 1] -= min_y

    pos_dec, norm_dec, uv_dec, faces_dec, _ = decimate_mesh_grid(pos_dead, norm_dead, uv, faces, target_tris)
    base = PieceNode("base", (0.0, 0.0, 0.0))
    base.children.append(PieceNode("corpse", (0.0, 0.0, 0.0), pos_dec, norm_dec, uv_dec, faces_dec))
    return base


def compute_hierarchy_bounds(piece, parent_world=(0.0, 0.0, 0.0)):
    wx = parent_world[0] + piece.offset[0]
    wy = parent_world[1] + piece.offset[1]
    wz = parent_world[2] + piece.offset[2]
    mins, maxs = [], []
    if len(piece.pos) > 0:
        wpos = piece.pos + np.array([wx, wy, wz], dtype=np.float32)
        mins.append(wpos.min(axis=0))
        maxs.append(wpos.max(axis=0))
    for ch in piece.children:
        cmin, cmax = compute_hierarchy_bounds(ch, (wx, wy, wz))
        if cmin is not None:
            mins.append(cmin)
            maxs.append(cmax)
    if not mins:
        return None, None
    return np.min(mins, axis=0), np.max(maxs, axis=0)


def write_s3o(path, root_piece, tex1_name, tex2_name):
    bmin, bmax = compute_hierarchy_bounds(root_piece)
    if bmin is None:
        bmin = np.array([-10.0, 0.0, -10.0], dtype=np.float32)
        bmax = np.array([10.0, 20.0, 10.0], dtype=np.float32)

    mid = 0.5 * (bmin + bmax)
    height = float(max(8.0, bmax[1] - min(0.0, bmin[1])))
    radius = float(max(8.0, 0.5 * np.linalg.norm(bmax - bmin)))

    buf = bytearray(52)

    def alloc_string(s):
        off = len(buf)
        buf.extend(s.encode("ascii", errors="replace") + b"\x00")
        return off

    tex1_off = alloc_string(tex1_name)
    tex2_off = alloc_string(tex2_name)

    def serialize_piece(p):
        name_off = alloc_string(p.name)
        child_offsets = [serialize_piece(ch) for ch in p.children]

        if child_offsets:
            children_table_off = len(buf)
            for co in child_offsets:
                buf.extend(struct.pack("<I", co))
        else:
            children_table_off = 0

        n_verts = len(p.pos)
        if n_verts > 0:
            verts_off = len(buf)
            v_data = np.empty((n_verts, 8), dtype=np.float32)
            v_data[:, 0:3] = p.pos
            v_data[:, 3:6] = p.norm
            v_data[:, 6:8] = p.uv
            buf.extend(v_data.tobytes())
        else:
            verts_off = 0

        flat_indices = p.faces.reshape(-1).astype(np.uint32)
        n_indices = len(flat_indices)
        if n_indices > 0:
            vtable_off = len(buf)
            buf.extend(flat_indices.tobytes())
        else:
            vtable_off = 0

        piece_off = len(buf)
        buf.extend(
            struct.pack(
                "<IIIIIIIIIIfff",
                name_off,
                len(child_offsets),
                children_table_off,
                n_verts,
                verts_off,
                0,
                0,
                n_indices,
                vtable_off,
                0,
                p.offset[0],
                p.offset[1],
                p.offset[2],
            )
        )
        return piece_off

    root_off = serialize_piece(root_piece)

    header = struct.pack(
        "<12sIfffffIIII",
        b"Spring unit\x00",
        0,
        radius,
        height,
        float(mid[0]),
        float(mid[1]),
        float(mid[2]),
        root_off,
        0,
        tex1_off,
        tex2_off,
    )
    buf[0:52] = header

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(buf)
    return radius, height, bmax - bmin


def write_dae(path, root_piece, tex1_name):
    geoms_xml = []

    def emit_geom(p):
        if len(p.pos) > 0 and len(p.faces) > 0:
            gid = f"{p.name}-mesh"
            n_v = len(p.pos)
            pos_str = " ".join(f"{x:.4f}" for x in p.pos.reshape(-1))
            norm_str = " ".join(f"{x:.4f}" for x in p.norm.reshape(-1))
            uv_flipped = p.uv.copy()
            uv_flipped[:, 1] = 1.0 - uv_flipped[:, 1]
            uv_str = " ".join(f"{x:.4f}" for x in uv_flipped.reshape(-1))
            idx_str = " ".join(str(int(x)) for x in p.faces.reshape(-1))
            n_tris = len(p.faces)
            geoms_xml.append(f"""    <geometry id="{gid}" name="{p.name}">
      <mesh>
        <source id="{gid}-pos">
          <float_array id="{gid}-pos-arr" count="{n_v * 3}">{pos_str}</float_array>
          <technique_common><accessor source="#{gid}-pos-arr" count="{n_v}" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common>
        </source>
        <source id="{gid}-norm">
          <float_array id="{gid}-norm-arr" count="{n_v * 3}">{norm_str}</float_array>
          <technique_common><accessor source="#{gid}-norm-arr" count="{n_v}" stride="3"><param name="X" type="float"/><param name="Y" type="float"/><param name="Z" type="float"/></accessor></technique_common>
        </source>
        <source id="{gid}-uv">
          <float_array id="{gid}-uv-arr" count="{n_v * 2}">{uv_str}</float_array>
          <technique_common><accessor source="#{gid}-uv-arr" count="{n_v}" stride="2"><param name="S" type="float"/><param name="T" type="float"/></accessor></technique_common>
        </source>
        <vertices id="{gid}-verts">
          <input semantic="POSITION" source="#{gid}-pos"/>
          <input semantic="NORMAL" source="#{gid}-norm"/>
          <input semantic="TEXCOORD" source="#{gid}-uv"/>
        </vertices>
        <triangles count="{n_tris}">
          <input semantic="VERTEX" source="#{gid}-verts" offset="0"/>
          <p>{idx_str}</p>
        </triangles>
      </mesh>
    </geometry>""")
        for ch in p.children:
            emit_geom(ch)

    def emit_node(p, indent="      "):
        ox, oy, oz = p.offset
        geom_tag = f'\n{indent}  <instance_geometry url="#{p.name}-mesh"/>' if (len(p.pos) > 0 and len(p.faces) > 0) else ""
        children_xml = "".join("\n" + emit_node(ch, indent + "  ") for ch in p.children)
        return f"""{indent}<node id="{p.name}" name="{p.name}" type="NODE">
{indent}  <translate>{ox:.4f} {oy:.4f} {oz:.4f}</translate>{geom_tag}{children_xml}
{indent}</node>"""

    emit_geom(root_piece)
    scene_nodes = emit_node(root_piece)
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<COLLADA xmlns="http://www.collada.org/2005/11/COLLADASchema" version="1.4.1">
  <asset><up_axis>Y_UP</up_axis></asset>
  <library_images>
    <image id="tex1_img" name="tex1_img"><init_from>{tex1_name}</init_from></image>
  </library_images>
  <library_geometries>
{chr(10).join(geoms_xml)}
  </library_geometries>
  <library_visual_scenes>
    <visual_scene id="Scene" name="Scene">
{scene_nodes}
    </visual_scene>
  </library_visual_scenes>
  <scene><instance_visual_scene url="#Scene"/></scene>
</COLLADA>
"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(xml)


def build_unit_hierarchy(gltf, bin_data, kind, scale, target_tris, grid_n=4):
    if kind == "character":
        return build_articulated_character(gltf, bin_data, scale, target_tris, grid_n)

    base = PieceNode("base", (0.0, 0.0, 0.0))

    if kind == "vehicle":
        nodes = gltf.get("nodes", [])
        hull_p, hull_n, hull_uv, hull_f = extract_mesh_geometry(gltf, bin_data, 0, grid_n, scale)
        for n in nodes[3:]:
            if "mesh" in n:
                wp, wn, wuv, wf = extract_mesh_geometry(gltf, bin_data, n["mesh"], grid_n, scale)
                if "rotation" in n:
                    R_node = quat_to_mat3(n["rotation"])
                    wp = (R_node @ wp.T).T
                    wn = (R_node @ wn.T).T
                t = np.array(n.get("translation", [0.0, 0.0, 0.0]), dtype=np.float32) * scale
                wp = wp + t
                wf = wf + len(hull_p)
                hull_p = np.vstack([hull_p, wp])
                hull_n = np.vstack([hull_n, wn])
                hull_uv = np.vstack([hull_uv, wuv])
                hull_f = np.vstack([hull_f, wf])

        hull_p, hull_n, hull_uv, hull_f, _ = decimate_mesh_grid(hull_p, hull_n, hull_uv, hull_f, int(target_tris * 0.55))
        t_hull = np.array(nodes[0].get("translation", [0.0, 0.0, 0.0]), dtype=np.float32) * scale
        hull_node = PieceNode("hull", tuple(t_hull), hull_p, hull_n, hull_uv, hull_f)

        tur_p, tur_n, tur_uv, tur_f = extract_mesh_geometry(gltf, bin_data, 1, grid_n, scale)
        tur_p, tur_n, tur_uv, tur_f, _ = decimate_mesh_grid(tur_p, tur_n, tur_uv, tur_f, int(target_tris * 0.30))
        t_tur = np.array(nodes[1].get("translation", [0.0, 1.5, 0.0]), dtype=np.float32) * scale
        turret_node = PieceNode("turret", tuple(t_tur), tur_p, tur_n, tur_uv, tur_f)

        gun_p, gun_n, gun_uv, gun_f = extract_mesh_geometry(gltf, bin_data, 2, grid_n, scale)
        gun_p, gun_n, gun_uv, gun_f, _ = decimate_mesh_grid(gun_p, gun_n, gun_uv, gun_f, int(target_tris * 0.15))
        t_gun = np.array(nodes[2].get("translation", [0.0, 0.4, 2.0]), dtype=np.float32) * scale
        barrel_node = PieceNode("barrel", tuple(t_gun), gun_p, gun_n, gun_uv, gun_f)

        flare_z = float(gun_p[:, 2].max()) if len(gun_p) > 0 else 12.0
        flare_node = PieceNode("flare", (0.0, 0.0, flare_z))

        barrel_node.children.append(flare_node)
        turret_node.children.append(barrel_node)
        hull_node.children.append(turret_node)
        base.children.append(hull_node)

    elif kind == "c130":
        nodes = gltf.get("nodes", [])
        fus_p, fus_n, fus_uv, fus_f = extract_mesh_geometry(gltf, bin_data, 0, grid_n, scale)
        # Also include landing gear / wheel sub-nodes (nodes[5:]) on the fuselage with their proper rotation & translation!
        for n in nodes[5:]:
            if "mesh" in n:
                wp, wn, wuv, wf = extract_mesh_geometry(gltf, bin_data, n["mesh"], grid_n, scale)
                if len(wp) > 0:
                    if "rotation" in n:
                        R_node = quat_to_mat3(n["rotation"])
                        wp = (R_node @ wp.T).T
                        wn = (R_node @ wn.T).T
                    t = np.array(n.get("translation", [0.0, 0.0, 0.0]), dtype=np.float32) * scale
                    wp = wp + t
                    wf = wf + len(fus_p)
                    fus_p = np.vstack([fus_p, wp])
                    fus_n = np.vstack([fus_n, wn])
                    fus_uv = np.vstack([fus_uv, wuv])
                    fus_f = np.vstack([fus_f, wf])
        fus_p, fus_n, fus_uv, fus_f, _ = decimate_mesh_grid(fus_p, fus_n, fus_uv, fus_f, int(target_tris * 0.75))
        fus_node = PieceNode("fuselage", (0.0, 0.0, 0.0), fus_p, fus_n, fus_uv, fus_f)

        for i in range(1, 5):
            if i < len(nodes) and "mesh" in nodes[i]:
                pp, pn, puv, pf = extract_mesh_geometry(gltf, bin_data, nodes[i]["mesh"], grid_n, scale)
                pp, pn, puv, pf, _ = decimate_mesh_grid(pp, pn, puv, pf, 180)
                t_prop = np.array(nodes[i].get("translation", [0.0, 0.0, 0.0]), dtype=np.float32) * scale
                fus_node.children.append(PieceNode(f"prop{i}", tuple(t_prop), pp, pn, puv, pf))

        fus_node.children.append(PieceNode("flare", (0.0, -3.0, 0.0)))
        base.children.append(fus_node)

    else:
        all_p, all_n, all_uv, all_f = [], [], [], []
        v_off = 0
        for n in gltf.get("nodes", []):
            if "mesh" in n:
                mp, mn, muv, mf = extract_mesh_geometry(gltf, bin_data, n["mesh"], grid_n, scale)
                if len(mp) == 0:
                    continue
                if "rotation" in n:
                    R_node = quat_to_mat3(n["rotation"])
                    mp = (R_node @ mp.T).T
                    mn = (R_node @ mn.T).T
                t = np.array(n.get("translation", [0.0, 0.0, 0.0]), dtype=np.float32) * scale
                mp = mp + t
                all_p.append(mp)
                all_n.append(mn)
                all_uv.append(muv)
                all_f.append(mf + v_off)
                v_off += len(mp)
        if not all_p and len(gltf.get("meshes", [])) > 0:
            mp, mn, muv, mf = extract_mesh_geometry(gltf, bin_data, 0, grid_n, scale)
            all_p, all_n, all_uv, all_f = [mp], [mn], [muv], [mf]

        body_p = np.vstack(all_p)
        body_n = np.vstack(all_n)
        body_uv = np.vstack(all_uv)
        body_f = np.vstack(all_f)
        body_p, body_n, body_uv, body_f, _ = decimate_mesh_grid(body_p, body_n, body_uv, body_f, target_tris)

        body_node = PieceNode("body", (0.0, 0.0, 0.0), body_p, body_n, body_uv, body_f)
        max_y = float(body_p[:, 1].max()) if len(body_p) > 0 else 15.0
        max_z = float(body_p[:, 2].max()) if len(body_p) > 0 else 8.0
        body_node.children.append(PieceNode("flare", (0.0, max_y * 0.65, max_z * 0.8)))
        base.children.append(body_node)

    return base, None


def count_hierarchy_tris(piece):
    total = len(piece.faces)
    for ch in piece.children:
        total += count_hierarchy_tris(ch)
    return total


def write_lua_anim_data(path, all_extracted_anims):
    lines = [
        "-- Auto-generated from embedded GoldSrc MDL (guer_arno.mdl) and GLB skeletal animation tracks",
        "-- Angles are (rx, ry, rz) in radians relative to the Idle rest pose for each articulated piece.",
        "return {",
    ]
    for unit_name, clips in all_extracted_anims.items():
        lines.append(f"\t{unit_name} = {{")
        for clip_name, frames in clips.items():
            lines.append(f"\t\t{clip_name} = {{")
            for f_idx, frame_dict in enumerate(frames):
                parts = []
                for pname in PIECE_ORDER:
                    rx, ry, rz = frame_dict[pname]
                    if abs(rx) > 0.002 or abs(ry) > 0.002 or abs(rz) > 0.002:
                        parts.append(f"{pname}={{{rx:.3f},{ry:.3f},{rz:.3f}}}")
                lines.append(f"\t\t\t[{f_idx + 1}] = {{ " + ", ".join(parts) + " },")
            lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def write_lua_preview_meshes(path, all_preview_roots, max_preview_tris=1400):
    """
    Exports a self-contained Lua 3D triangle mesh table for each unit (flattened from its rest-pose PieceNode hierarchy
    and decimated to ~1400 triangles) so the bottom-left 3D Tactical Unit Inspector can render any unit in 3D with its
    exact 1024x1024 unittextures/<name>_tex1.png texture in Recoil GL4 without relying on deprecated gl.UnitShape!
    """
    lines = [
        "-- Auto-generated 3D preview meshes (pos, norm, uv, tris) for the Bottom-Left 3D Tactical Unit Inspector",
        "return {",
    ]
    for unit_name, root_piece in all_preview_roots.items():
        all_p, all_n, all_uv, all_f = [], [], [], []
        v_off = [0]

        def collect_piece(p, parent_world=(0.0, 0.0, 0.0)):
            wx = parent_world[0] + p.offset[0]
            wy = parent_world[1] + p.offset[1]
            wz = parent_world[2] + p.offset[2]
            if len(p.pos) > 0 and len(p.faces) > 0:
                wpos = p.pos + np.array([wx, wy, wz], dtype=np.float32)
                all_p.append(wpos)
                all_n.append(p.norm)
                all_uv.append(p.uv)
                all_f.append(p.faces + v_off[0])
                v_off[0] += len(wpos)
            for ch in p.children:
                collect_piece(ch, (wx, wy, wz))

        collect_piece(root_piece)
        if not all_p:
            continue

        pos = np.vstack(all_p)
        norm = np.vstack(all_n)
        uv = np.vstack(all_uv)
        faces = np.vstack(all_f)
        pos, norm, uv, faces, _ = decimate_mesh_grid(pos, norm, uv, faces, max_preview_tris)

        bmin = pos.min(axis=0)
        bmax = pos.max(axis=0)
        mid = 0.5 * (bmin + bmax)
        span = bmax - bmin
        # Use bounding-box max dimension * 0.52 so characters, tanks, and wide-wingspan aircraft all fill the 3D scanner box!
        rad = float(max(4.0, 0.52 * max(float(span[0]), float(span[1]), float(span[2]))))
        tex_file = f"unittextures/{unit_name}_tex1.png"

        lines.append(f"\t{unit_name} = {{")
        lines.append(f"\t\ttex = {json.dumps(tex_file)},")
        lines.append(f"\t\tmid = {{ {mid[0]:.2f}, {mid[1]:.2f}, {mid[2]:.2f} }},")
        lines.append(f"\t\tradius = {rad:.2f},")
        lines.append("\t\ttris = {")
        for f in faces:
            i0, i1, i2 = int(f[0]), int(f[1]), int(f[2])
            p0, p1, p2 = pos[i0], pos[i1], pos[i2]
            u0, u1, u2 = uv[i0], uv[i1], uv[i2]
            # Average smoothed vertex normals for natural curved shading, oriented to face normal
            vn = norm[i0] + norm[i1] + norm[i2]
            vn_len = float(np.linalg.norm(vn))
            if vn_len > 1e-6:
                fn = vn / vn_len
            else:
                fn = np.cross(p1 - p0, p2 - p0)
                fn_len = float(np.linalg.norm(fn))
                fn = (fn / fn_len) if fn_len > 1e-6 else np.array([0.0, 1.0, 0.0], dtype=np.float32)
            lines.append(
                f"\t\t\t{{{p0[0]:.2f},{p0[1]:.2f},{p0[2]:.2f},{u0[0]:.3f},{u0[1]:.3f},"
                f"{p1[0]:.2f},{p1[1]:.2f},{p1[2]:.2f},{u1[0]:.3f},{u1[1]:.3f},"
                f"{p2[0]:.2f},{p2[1]:.2f},{p2[2]:.2f},{u2[0]:.3f},{u2[1]:.3f},"
                f"{fn[0]:.2f},{fn[1]:.2f},{fn[2]:.2f}}},"
            )
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def read_s3o_piece(buf, off):
    name_off, n_ch, ch_off, n_v, v_off, _, _, n_idx, idx_off, _, ox, oy, oz = struct.unpack_from("<10I3f", buf, off)
    end = buf.find(b"\x00", name_off)
    name = buf[name_off:end].decode("ascii", errors="replace")
    if n_v > 0:
        v_data = np.frombuffer(buf, dtype=np.float32, count=n_v * 8, offset=v_off).reshape((n_v, 8)).copy()
        pos, norm, uv = v_data[:, 0:3], v_data[:, 3:6], v_data[:, 6:8]
    else:
        pos = np.zeros((0, 3), dtype=np.float32)
        norm = np.zeros((0, 3), dtype=np.float32)
        uv = np.zeros((0, 2), dtype=np.float32)
    if n_idx > 0:
        faces = np.frombuffer(buf, dtype=np.uint32, count=n_idx, offset=idx_off).reshape((-1, 3)).copy()
    else:
        faces = np.zeros((0, 3), dtype=np.uint32)
    node = PieceNode(name, (ox, oy, oz), pos, norm, uv, faces)
    if n_ch > 0:
        ch_offs = struct.unpack_from(f"<{n_ch}I", buf, ch_off)
        for co in ch_offs:
            node.children.append(read_s3o_piece(buf, co))
    return node


def load_s3o_hierarchy(path):
    with open(path, "rb") as f:
        buf = f.read()
    root_off = struct.unpack_from("<I", buf, 36)[0]
    return read_s3o_piece(buf, root_off)


def convert_all_assets(mod_root):
    assets_root = r"C:\Users\akihungac\.gemini\antigravity\scratch\game-assets-3d"
    guer_mdl_path = r"C:\Users\akihungac\.gemini\antigravity\scratch\extracted_units\guer_arno\guer_arno.mdl"
    aks74u_mdl_path = r"C:\Users\akihungac\.gemini\antigravity\scratch\extracted_units\aks74u\cstrike\models\p_ak47.mdl"

    obj_dir = os.path.join(mod_root, "objects3d", "Units")
    tex_dir = os.path.join(mod_root, "unittextures")
    os.makedirs(obj_dir, exist_ok=True)
    os.makedirs(tex_dir, exist_ok=True)

    all_extracted_anims = {}
    all_preview_roots = {}

    print(f"{'Model Name':<20} | {'Orig Tris':>9} -> {'Decimated':>9} | {'Size (W x H x L) elmos':<24} | Source & Animations")
    print("-" * 105)

    # 1. Convert guer_arno.mdl + CS 1.6 p_ak47.mdl (AKS-74U) for zdef_infantry & zdef_paratrooper
    for name, height_elmos, tint in [
        ("zdef_infantry", 14.5, (1.0, 1.0, 1.0)),
        ("zdef_paratrooper", 14.8, (0.88, 0.96, 1.05)),
    ]:
        s3o_path = os.path.join(obj_dir, f"{name}.s3o")
        if os.path.exists(guer_mdl_path):
            root_piece, extracted_clips, tex1_img, tex2_img, orig_tris = convert_goldsrc_mdl(
                guer_mdl_path, aks74u_mdl_path, target_height_elmos=height_elmos, tint_rgb=tint
            )
            all_extracted_anims[name] = extracted_clips
            all_preview_roots[name] = root_piece
            tex1_file = f"{name}_tex1.png"
            tex2_file = f"{name}_tex2.png"
            tex1_img.save(os.path.join(tex_dir, tex1_file), "PNG")
            tex2_img.save(os.path.join(tex_dir, tex2_file), "PNG")

            dec_tris = count_hierarchy_tris(root_piece)
            dae_path = os.path.join(obj_dir, f"{name}.dae")
            radius, height, sz = write_s3o(s3o_path, root_piece, tex1_file, tex2_file)
            write_dae(dae_path, root_piece, tex1_file)
            sz_str = f"{sz[0]:5.1f} x {sz[1]:5.1f} x {sz[2]:5.1f}"
            print(f"{name:<20} | {orig_tris:>9,d} -> {dec_tris:>9,d} | {sz_str:<24} | guer_arno.mdl + p_ak47.mdl (Idle,Walk,Run,Attack)")
        elif os.path.exists(s3o_path):
            root_piece = load_s3o_hierarchy(s3o_path)
            all_preview_roots[name] = root_piece
            dec_tris = count_hierarchy_tris(root_piece)
            print(f"{name:<20} | {dec_tris:>9,d} -> {dec_tris:>9,d} | {'(loaded from S3O)':<24} | Existing S3O hierarchy")

    # 2. Convert GLB Zombies, Vehicles, Aircraft, and HQ with harmonized realistic scales
    glb_targets = [
        ("zdef_zombie_walker", r"characters\zombies\models\zombie-walker.glb", "character", 8.0, 1650),
        ("zdef_zombie_brute", r"characters\zombies\models\zombie-brute.glb", "character", 10.5, 2100),
        ("zdef_zombie_soldier", r"characters\zombies\models\zombie-soldier.glb", "character", 8.2, 1750),
        ("zdef_zombie_bloater", r"characters\zombies\models\zombie-bloated.glb", "character", 8.5, 1700),
        ("zdef_mrap", r"vehicles\military\models\mrap-4x4.glb", "vehicle", 5.5, 4200),
        ("zdef_tank", r"vehicles\military\models\battle-tank.glb", "vehicle", 6.0, 5600),
        ("zdef_a10", r"vehicles\fighter-jets\models\straight-wing-attack-jet.glb", "a10", 6.0, 9500),
        ("zdef_fighter", r"vehicles\fighter-jets\models\multirole-fighter.glb", "a10", 5.8, 8500),
        ("zdef_c130", r"vehicles\bombers-and-transport-planes\models\four-turboprop-airlifter.glb", "c130", 5.4, 11500),
        ("zdef_hq", r"vehicles\fighter-jets\models\hardened-aircraft-shelter.glb", "building", 4.2, 1600),
    ]

    for name, rel_path, kind, scale, target_tris in glb_targets:
        glb_path = os.path.join(assets_root, rel_path)
        gltf, bin_data = load_glb(glb_path)

        orig_tris = 0
        for m in range(len(gltf.get("meshes", []))):
            _, _, _, f = extract_mesh_geometry(gltf, bin_data, m, 5, 1.0)
            orig_tris += len(f)

        tex1_img, tex2_img, grid_n = build_material_atlas(gltf, bin_data, atlas_size=1024, grid_n=5)
        root_piece, extracted_clips = build_unit_hierarchy(gltf, bin_data, kind, scale, target_tris, grid_n)

        tex1_file = f"{name}_tex1.png"
        tex2_file = f"{name}_tex2.png"
        tex1_img.save(os.path.join(tex_dir, tex1_file), "PNG")
        tex2_img.save(os.path.join(tex_dir, tex2_file), "PNG")

        all_preview_roots[name] = root_piece
        if extracted_clips:
            all_extracted_anims[name] = extracted_clips

        dec_tris = count_hierarchy_tris(root_piece)
        s3o_path = os.path.join(obj_dir, f"{name}.s3o")
        dae_path = os.path.join(obj_dir, f"{name}.dae")
        radius, height, sz = write_s3o(s3o_path, root_piece, tex1_file, tex2_file)
        write_dae(dae_path, root_piece, tex1_file)

        # If this is a zombie character, also bake its Death-pose lying corpse model (zdef_zombie_*_dead.s3o)!
        if kind == "character" and "zombie" in name:
            corpse_root = build_death_corpse_piece(gltf, bin_data, scale, target_tris=850, grid_n=grid_n)
            dead_s3o_path = os.path.join(obj_dir, f"{name}_dead.s3o")
            write_s3o(dead_s3o_path, corpse_root, tex1_file, tex2_file)

        sz_str = f"{sz[0]:5.1f} x {sz[1]:5.1f} x {sz[2]:5.1f}"
        info_str = f"11 bones ({','.join(extracted_clips.keys())})" if extracted_clips else "Rigid hierarchy"
        print(f"{name:<20} | {orig_tris:>9,d} -> {dec_tris:>9,d} | {sz_str:<24} | {info_str}")

    anim_lua_path = os.path.join(mod_root, "scripts", "Units", "zdef_anim_data.lua")
    write_lua_anim_data(anim_lua_path, all_extracted_anims)
    preview_lua_path = os.path.join(mod_root, "luaui", "Include", "zdef_preview_meshes.lua")
    write_lua_preview_meshes(preview_lua_path, all_preview_roots, max_preview_tris=1400)
    print(f"\nSaved extracted MDL + GLB animation keyframe data to: {anim_lua_path}")
    print(f"Saved 3D HUD preview mesh data to: {preview_lua_path}")


if __name__ == "__main__":
    mod_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    convert_all_assets(mod_dir)
