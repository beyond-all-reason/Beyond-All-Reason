import os
import numpy as np
from PIL import Image

ICONS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "icons"))
os.makedirs(ICONS_DIR, exist_ok=True)


def make_radial_grid(size=128):
    # Normalized radius r in [0, 1] at edge of inscribed circle (with 4px padding)
    c = (size - 1) * 0.5
    max_r = c - 4.0
    y, x = np.ogrid[:size, :size]
    dist = np.sqrt((x - c) ** 2 + (y - c) ** 2)
    return dist / max_r


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / max(1e-6, (edge1 - edge0)), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def save_icon(filename, rgba):
    path = os.path.join(ICONS_DIR, filename)
    arr = np.clip(rgba, 0, 255).astype(np.uint8)
    Image.fromarray(arr, mode="RGBA").save(path)
    print(f"Generated {filename} ({arr.shape[1]}x{arr.shape[0]})")


def generate_small_dot(filename, core_alpha=235, rim_darkness=24):
    """Compact crisp dot for small units (infantry / walkers) with anti-aliased dark contrast rim."""
    r = make_radial_grid(128)
    rgba = np.zeros((128, 128, 4), dtype=np.float32)

    # Outer edge AA falloff at r = 1.0
    outer_mask = 1.0 - smoothstep(0.92, 1.02, r)
    # Transition from white team-colored core (r < 0.74) to dark contrast rim (0.74..0.98)
    core_mask = 1.0 - smoothstep(0.70, 0.80, r)

    rgb_val = core_mask * 255.0 + (1.0 - core_mask) * rim_darkness
    alpha_val = outer_mask * (core_mask * core_alpha + (1.0 - core_mask) * 210.0)

    rgba[:, :, 0] = rgb_val
    rgba[:, :, 1] = rgb_val
    rgba[:, :, 2] = rgb_val
    rgba[:, :, 3] = alpha_val
    save_icon(filename, rgba)


def generate_semitransparent_bordered_circle(
    filename,
    fill_alpha=82.0,
    border_inner=0.73,
    border_outer=0.90,
    border_alpha=248.0,
    center_pip_r=0.17,
    center_pip_alpha=175.0,
    inner_ring=False,
):
    """
    Semi-transparent team-colored circle with a crisp bright border ring and thin dark outer halo.
    Used for large units (MRAP, M1 Tank, Zombie Brute, A-10, C-130, HQ Bunker) on the minimap.
    """
    r = make_radial_grid(128)
    rgba = np.zeros((128, 128, 4), dtype=np.float32)

    # 1. Semi-transparent interior fill (r < border_inner)
    inside_disk = 1.0 - smoothstep(border_inner - 0.03, border_inner + 0.02, r)

    # 2. Bright team-colored border ring (border_inner <= r <= border_outer)
    ring_in = smoothstep(border_inner - 0.03, border_inner + 0.02, r)
    ring_out = 1.0 - smoothstep(border_outer - 0.02, border_outer + 0.03, r)
    border_mask = ring_in * ring_out

    # 3. Thin dark outer contrast halo (border_outer < r <= 0.99) so the border pops on any terrain
    halo_in = smoothstep(border_outer - 0.01, border_outer + 0.03, r)
    halo_out = 1.0 - smoothstep(0.95, 1.02, r)
    halo_mask = halo_in * halo_out

    # 4. Optional subtle inner ring (for HQ / Aircraft)
    inner_ring_mask = np.zeros_like(r)
    if inner_ring:
        ir_in = smoothstep(0.42, 0.46, r)
        ir_out = 1.0 - smoothstep(0.51, 0.55, r)
        inner_ring_mask = ir_in * ir_out

    # 5. Subtle center pip marking exact unit position
    pip_mask = np.zeros_like(r)
    if center_pip_r > 0:
        pip_mask = 1.0 - smoothstep(center_pip_r - 0.03, center_pip_r + 0.03, r)

    # Combine RGB (255 = pure team color, 22 = dark contrast border halo)
    bright_weight = np.clip(inside_disk + border_mask + inner_ring_mask + pip_mask, 0.0, 1.0)
    rgb = bright_weight * 255.0 + (1.0 - bright_weight) * 20.0

    # Combine Alpha:
    # - Interior is semi-transparent (fill_alpha ~ 78..92 / 255, ~32% opacity)
    # - Border is crisp high-opacity (border_alpha ~ 248 / 255, ~97% opacity)
    # - Outer dark halo is medium opacity (170 / 255)
    alpha = (
        inside_disk * fill_alpha
        + border_mask * border_alpha
        + halo_mask * 170.0
    )
    if inner_ring:
        alpha = np.maximum(alpha, inner_ring_mask * 165.0)
    if center_pip_r > 0:
        alpha = np.maximum(alpha, pip_mask * center_pip_alpha)

    rgba[:, :, 0] = rgb
    rgba[:, :, 1] = rgb
    rgba[:, :, 2] = rgb
    rgba[:, :, 3] = np.clip(alpha, 0.0, 255.0)
    save_icon(filename, rgba)


if __name__ == "__main__":
    # Small units: compact, crisp dots
    generate_small_dot("zdef_dot_walker.png", core_alpha=220, rim_darkness=20)
    generate_small_dot("zdef_dot_zombie_med.png", core_alpha=232, rim_darkness=22)
    generate_small_dot("zdef_dot_infantry.png", core_alpha=245, rim_darkness=25)

    # Large units: semi-transparent circles with crisp border rings
    generate_semitransparent_bordered_circle(
        "zdef_circle_brute.png",
        fill_alpha=78.0,
        border_inner=0.72,
        border_outer=0.90,
        border_alpha=245.0,
        center_pip_r=0.16,
        center_pip_alpha=165.0,
        inner_ring=False,
    )
    generate_semitransparent_bordered_circle(
        "zdef_circle_mrap.png",
        fill_alpha=80.0,
        border_inner=0.73,
        border_outer=0.90,
        border_alpha=248.0,
        center_pip_r=0.16,
        center_pip_alpha=170.0,
        inner_ring=False,
    )
    generate_semitransparent_bordered_circle(
        "zdef_circle_tank.png",
        fill_alpha=86.0,
        border_inner=0.70,
        border_outer=0.90,
        border_alpha=252.0,
        center_pip_r=0.20,
        center_pip_alpha=190.0,
        inner_ring=False,
    )
    generate_semitransparent_bordered_circle(
        "zdef_circle_air.png",
        fill_alpha=72.0,
        border_inner=0.75,
        border_outer=0.90,
        border_alpha=245.0,
        center_pip_r=0.15,
        center_pip_alpha=175.0,
        inner_ring=True,
    )
    generate_semitransparent_bordered_circle(
        "zdef_circle_hq.png",
        fill_alpha=88.0,
        border_inner=0.72,
        border_outer=0.90,
        border_alpha=255.0,
        center_pip_r=0.22,
        center_pip_alpha=210.0,
        inner_ring=True,
    )
