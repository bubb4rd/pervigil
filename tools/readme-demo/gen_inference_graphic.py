#!/usr/bin/env python3
"""Generate the Pervigil Inference Host graphic (docs/assets/inference_host.svg).

Moody dark-glass node and telemetry visual inspired by luminous flow-node UIs,
styled in Pervigil's sapphire blue palette for local Apple Silicon inference
hosting (Ollama, LM Studio, llama-server, GPU/wired-memory telemetry).

Pure self-contained vector SVG (no external fonts, no scripts, no bitmaps).

    python3 tools/readme-demo/gen_inference_graphic.py
"""

from pathlib import Path
import math

OUT = Path(__file__).resolve().parents[2] / "docs" / "assets"
FONT = "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Helvetica Neue', Arial, sans-serif"

# Exact Pervigil mark geometry (viewBox 0 0 562 650)
MARK_FULL = "M0 0H562V650H0V231H190L0 124ZM190 231 557 438 190 645Z"
MARK_INNER = "251 334 435 438 251 542"


def star_dots() -> str:
    """Deterministic micro-sparkle dots inside the dark telemetry meter well."""
    # (dx, dy, r, opacity) relative to well origin (x=222, y=482), width 316, height 58
    pts = [
        (16, 12, 0.85, 0.55), (34, 19, 0.65, 0.35), (52, 9, 1.0, 0.70),
        (68, 22, 0.7, 0.40), (88, 13, 0.9, 0.60), (104, 8, 0.65, 0.38),
        (122, 18, 1.05, 0.72), (140, 11, 0.75, 0.45), (156, 21, 0.85, 0.50),
        (174, 9, 0.95, 0.65), (192, 17, 0.7, 0.42), (210, 12, 1.1, 0.78),
        (228, 20, 0.8, 0.52), (244, 10, 0.9, 0.60), (262, 16, 0.65, 0.36),
        (278, 11, 0.85, 0.48), (294, 21, 0.75, 0.40), (304, 13, 0.6, 0.32),
        (44, 26, 0.6, 0.30), (132, 27, 0.65, 0.35), (218, 26, 0.75, 0.48),
        (270, 27, 0.6, 0.30), (186, 25, 0.65, 0.36),
    ]
    lines = []
    for dx, dy, r, op in pts:
        lines.append(
            f'<circle cx="{222 + dx}" cy="{482 + dy}" r="{r}" fill="#DCEEFF" opacity="{op}"/>'
        )
    return "\n    ".join(lines)


def ambient_dust() -> str:
    """Subtle floating atmospheric dust motes around the central halo."""
    pts = [
        (140, 120, 1.0, 0.22), (192, 92, 0.8, 0.18), (584, 110, 1.1, 0.24),
        (638, 152, 0.8, 0.18), (110, 340, 0.9, 0.16), (664, 336, 1.0, 0.20),
        (272, 392, 0.85, 0.26), (488, 394, 0.85, 0.28), (380, 112, 1.0, 0.24),
    ]
    return "\n  ".join(
        f'<circle cx="{x}" cy="{y}" r="{r}" fill="#A8D4FF" opacity="{op}"/>'
        for x, y, r, op in pts
    )


def build_inference_graphic() -> str:
    w, h = 760, 620
    # Centerpiece card geometry
    cx, cy, cw, ch = 228, 164, 304, 156
    # Outer glass halo frame
    hx, hy, hw, hh = 214, 150, 332, 184
    mid_y = cy + ch / 2  # 242

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="Pervigil Inference Host architecture graphic showing local Ollama, LM Studio, and llama-server node with live GPU and wired memory telemetry">
<style>
  text {{ font-family: {FONT}; }}
  .num {{ font-variant-numeric: tabular-nums; }}
  .pulse {{ animation: softPulse 3.6s ease-in-out infinite; }}
  .breathe {{ animation: softPulse 3.2s ease-in-out 0.8s infinite; }}
  .flow {{ stroke-dasharray: 38 220; animation: flowDash 3.6s linear infinite; }}
  @keyframes softPulse {{ 0%, 100% {{ opacity: 1; }} 50% {{ opacity: 0.62; }} }}
  @keyframes flowDash {{ from {{ stroke-dashoffset: 258; }} to {{ stroke-dashoffset: 0; }} }}
  @media (prefers-reduced-motion: reduce) {{
    .pulse, .breathe, .flow {{ animation: none !important; }}
  }}
</style>
<defs>
  <!-- Moody backlit sapphire atmosphere -->
  <linearGradient id="bgBase" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#0C2D66"/>
    <stop offset="34%" stop-color="#071B3D"/>
    <stop offset="68%" stop-color="#040A16"/>
    <stop offset="100%" stop-color="#020408"/>
  </linearGradient>
  <radialGradient id="topKeyLight" cx="50%" cy="14%" r="62%">
    <stop offset="0%" stop-color="#3B97FF" stop-opacity="0.62"/>
    <stop offset="38%" stop-color="#1463D6" stop-opacity="0.34"/>
    <stop offset="72%" stop-color="#071F48" stop-opacity="0.10"/>
    <stop offset="100%" stop-color="#020408" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="sideRimL" cx="10%" cy="40%" r="48%">
    <stop offset="0%" stop-color="#2F89FF" stop-opacity="0.28"/>
    <stop offset="100%" stop-color="#020408" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="sideRimR" cx="90%" cy="40%" r="48%">
    <stop offset="0%" stop-color="#2F89FF" stop-opacity="0.26"/>
    <stop offset="100%" stop-color="#020408" stop-opacity="0"/>
  </radialGradient>
  <!-- Soft out-of-focus studio hardware monolith silhouette in backdrop -->
  <linearGradient id="monolith" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#030710" stop-opacity="0.82"/>
    <stop offset="55%" stop-color="#02050B" stop-opacity="0.92"/>
    <stop offset="100%" stop-color="#010205" stop-opacity="0.98"/>
  </linearGradient>
  <filter id="bgBlur" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="24"/>
  </filter>
  <filter id="flareGlow" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="7" result="b"/>
    <feMerge>
      <feMergeNode in="b"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>
  <filter id="softGlow" x="-40%" y="-40%" width="180%" height="180%">
    <feGaussianBlur stdDeviation="4" result="b"/>
    <feMerge>
      <feMergeNode in="b"/>
      <feMergeNode in="SourceGraphic"/>
    </feMerge>
  </filter>
  <filter id="cardDrop" x="-20%" y="-20%" width="140%" height="150%">
    <feDropShadow dx="0" dy="18" stdDeviation="18" flood-color="#000000" flood-opacity="0.72"/>
  </filter>

  <!-- Main node card glass surface -->
  <linearGradient id="nodeSurface" x1="0" y1="0" x2="0.25" y2="1">
    <stop offset="0%" stop-color="#1A2230" stop-opacity="0.90"/>
    <stop offset="55%" stop-color="#11151E" stop-opacity="0.93"/>
    <stop offset="100%" stop-color="#0B0E14" stop-opacity="0.95"/>
  </linearGradient>
  <radialGradient id="nodeEdgeL" cx="0%" cy="50%" r="36%">
    <stop offset="0%" stop-color="#4AA4FF" stop-opacity="0.34"/>
    <stop offset="100%" stop-color="#4AA4FF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="nodeEdgeR" cx="100%" cy="50%" r="36%">
    <stop offset="0%" stop-color="#4AA4FF" stop-opacity="0.34"/>
    <stop offset="100%" stop-color="#4AA4FF" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="nodeStroke" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#A8D5FF" stop-opacity="0.34"/>
    <stop offset="50%" stop-color="#FFFFFF" stop-opacity="0.10"/>
    <stop offset="100%" stop-color="#6EB5FF" stop-opacity="0.28"/>
  </linearGradient>

  <!-- Luminous liquid-flare port gradients -->
  <radialGradient id="blueFlare" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#E8F5FF"/>
    <stop offset="40%" stop-color="#5EB2FF"/>
    <stop offset="100%" stop-color="#1C7BFF" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="whiteFlare" cx="50%" cy="50%" r="50%">
    <stop offset="0%" stop-color="#FFFFFF"/>
    <stop offset="48%" stop-color="#D8EDFF"/>
    <stop offset="100%" stop-color="#6CB8FF" stop-opacity="0"/>
  </radialGradient>

  <!-- Wire gradients -->
  <linearGradient id="wireL" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0%" stop-color="#5CB0FF" stop-opacity="0.15"/>
    <stop offset="55%" stop-color="#76C2FF" stop-opacity="0.65"/>
    <stop offset="100%" stop-color="#CBE8FF" stop-opacity="0.95"/>
  </linearGradient>
  <linearGradient id="wireR" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0%" stop-color="#CBE8FF" stop-opacity="0.95"/>
    <stop offset="45%" stop-color="#76C2FF" stop-opacity="0.65"/>
    <stop offset="100%" stop-color="#5CB0FF" stop-opacity="0.15"/>
  </linearGradient>
  <linearGradient id="wireDownBlue" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#B8E0FF" stop-opacity="0.95"/>
    <stop offset="50%" stop-color="#4AA4FF" stop-opacity="0.52"/>
    <stop offset="100%" stop-color="#4AA4FF" stop-opacity="0.12"/>
  </linearGradient>
  <linearGradient id="wireDownWhite" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.98"/>
    <stop offset="55%" stop-color="#CFE7FF" stop-opacity="0.55"/>
    <stop offset="100%" stop-color="#7CC4FF" stop-opacity="0.16"/>
  </linearGradient>

  <!-- Lower telemetry card luminous blue wash -->
  <linearGradient id="telWash" x1="0" y1="0" x2="1" y2="0.85">
    <stop offset="0%" stop-color="#1C7DF7" stop-opacity="0.72"/>
    <stop offset="34%" stop-color="#0E4499" stop-opacity="0.46"/>
    <stop offset="70%" stop-color="#0D1422" stop-opacity="0.86"/>
    <stop offset="100%" stop-color="#0A0D14" stop-opacity="0.92"/>
  </linearGradient>
  <linearGradient id="telStroke" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0%" stop-color="#9BD0FF" stop-opacity="0.72"/>
    <stop offset="38%" stop-color="#5CAEFF" stop-opacity="0.30"/>
    <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0.16"/>
  </linearGradient>
  <linearGradient id="meterFill" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0%" stop-color="#4AA4FF"/>
    <stop offset="68%" stop-color="#9AD0FF"/>
    <stop offset="100%" stop-color="#FFFFFF"/>
  </linearGradient>
  <linearGradient id="markBlue" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0%" stop-color="#8BC7FF"/>
    <stop offset="100%" stop-color="#1E82FF"/>
  </linearGradient>

  <clipPath id="viewport"><rect width="{w}" height="{h}" rx="20"/></clipPath>
  <clipPath id="nodeClip"><rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" rx="18"/></clipPath>
</defs>

<g clip-path="url(#viewport)">
  <!-- ===== ATMOSPHERIC BACKLIT STUDIO BACKGROUND ===== -->
  <rect width="{w}" height="{h}" fill="url(#bgBase)"/>
  <rect width="{w}" height="{h}" fill="url(#topKeyLight)"/>
  <rect width="{w}" height="{h}" fill="url(#sideRimL)"/>
  <rect width="{w}" height="{h}" fill="url(#sideRimR)"/>

  <!-- Out-of-focus dark architectural host silhouette (echoing the reference mood) -->
  <g filter="url(#bgBlur)" opacity="0.90">
    <!-- Upper vertical tower / compute core silhouette -->
    <rect x="278" y="34" width="204" height="236" rx="92" fill="url(#monolith)"/>
    <!-- Broad lower shoulder / desk silhouette -->
    <path d="M-40 640 L-10 346 Q380 248 770 346 L800 640 Z" fill="url(#monolith)"/>
    <!-- Subtle backlit blue rim around the silhouette -->
    <ellipse cx="380" cy="242" rx="185" ry="90" fill="#2078F5" opacity="0.24"/>
  </g>

  {ambient_dust()}

  <!-- ===== GOSSAMER MULTI-STRAND FLOWING BEZIER WIRES ===== -->
  <!-- Left incoming inference requests ribbon -->
  <g fill="none" stroke-linecap="round">
    <path d="M -10 218 C 72 224, 128 248, 214 242" stroke="url(#wireL)" stroke-width="1.4" opacity="0.90"/>
    <path d="M -10 232 C 80 256, 146 244, 214 242" stroke="url(#wireL)" stroke-width="1.0" opacity="0.52"/>
    <path d="M -10 208 C 66 238, 134 232, 214 242" stroke="url(#wireL)" stroke-width="0.75" opacity="0.34"/>
    <path d="M -10 218 C 72 224, 128 248, 214 242" stroke="#DDF0FF" stroke-width="1.5" opacity="0.75" class="flow"/>
  </g>
  <!-- Left ribbon label -->
  <rect x="20" y="213" width="96" height="24" rx="12" fill="rgba(5,13,28,0.78)" stroke="rgba(140,198,255,0.20)" stroke-width="0.8"/>
  <text x="68" y="229" fill="#D8ECFF" font-size="11" font-weight="500" text-anchor="middle">127.0.0.1 · 3 req</text>

  <!-- Right outgoing power assertion ribbon -->
  <g fill="none" stroke-linecap="round">
    <path d="M 546 242 C 632 248, 688 224, 770 218" stroke="url(#wireR)" stroke-width="1.4" opacity="0.90"/>
    <path d="M 546 242 C 614 244, 680 256, 770 232" stroke="url(#wireR)" stroke-width="1.0" opacity="0.52"/>
    <path d="M 546 242 C 626 232, 694 238, 770 208" stroke="url(#wireR)" stroke-width="0.75" opacity="0.34"/>
    <path d="M 546 242 C 632 248, 688 224, 770 218" stroke="#E8F5FF" stroke-width="1.8" opacity="0.88" class="flow"/>
  </g>
  <!-- Right ribbon label -->
  <rect x="644" y="213" width="96" height="24" rx="12" fill="rgba(5,13,28,0.78)" stroke="rgba(140,198,255,0.20)" stroke-width="0.8"/>
  <text x="692" y="229" fill="#D8ECFF" font-size="11" font-weight="500" text-anchor="middle">Awake · 0 ports</text>

  <!-- Downward ports connecting top node to lower telemetry card -->
  <!-- Left port: GPU & Thermal -->
  <g fill="none" stroke-linecap="round">
    <path d="M 318 334 C 318 366, 306 396, 294 428" stroke="url(#wireDownBlue)" stroke-width="1.35" opacity="0.88"/>
    <path d="M 318 334 C 324 370, 314 398, 304 428" stroke="url(#wireDownBlue)" stroke-width="0.85" opacity="0.45"/>
  </g>
  <!-- Right port: Wired Memory -->
  <g fill="none" stroke-linecap="round">
    <path d="M 442 334 C 442 368, 444 398, 446 428" stroke="url(#wireDownWhite)" stroke-width="1.5" opacity="0.92"/>
    <path d="M 442 334 C 436 372, 438 398, 439 428" stroke="url(#wireDownWhite)" stroke-width="0.85" opacity="0.48"/>
  </g>

  <!-- ===== CENTERPIECE OUTER GLASS HALO + LIQUID FLARE PORTS ===== -->
  <g>
    <!-- Delicate outer glass halo rectangle -->
    <rect x="{hx}" y="{hy}" width="{hw}" height="{hh}" rx="22" fill="rgba(12,24,46,0.22)" stroke="rgba(155,208,255,0.22)" stroke-width="1"/>
    <!-- Subtle glowing corner bracket accents (top-left & bottom-right) -->
    <path d="M {hx} {hy + 28} L {hx} {hy + 22} A 22 22 0 0 1 {hx + 22} {hy} L {hx + 34} {hy}" fill="none" stroke="#9BD0FF" stroke-width="1.5" opacity="0.65"/>
    <path d="M {hx + hw} {hy + hh - 28} L {hx + hw} {hy + hh - 22} A 22 22 0 0 1 {hx + hw - 22} {hy + hh} L {hx + hw - 34} {hy + hh}" fill="none" stroke="#9BD0FF" stroke-width="1.5" opacity="0.50"/>

    <!-- Liquid-light connection flares welded to halo edges -->
    <g filter="url(#flareGlow)" class="pulse">
      <!-- Left flare cusp -->
      <path d="M 188 242 Q 214 242 214 218 L 214 266 Q 214 242 188 242 Z" fill="url(#blueFlare)"/>
      <circle cx="212" cy="242" r="5" fill="#DDF0FF" opacity="0.88"/>
      <!-- Right flare cusp -->
      <path d="M 572 242 Q 546 242 546 218 L 546 266 Q 546 242 572 242 Z" fill="url(#blueFlare)"/>
      <circle cx="548" cy="242" r="5" fill="#DDF0FF" opacity="0.88"/>
      <!-- Bottom-left blue flare cusp (GPU & Thermal) -->
      <path d="M 318 358 Q 318 334 298 334 L 338 334 Q 318 334 318 358 Z" fill="url(#blueFlare)"/>
      <circle cx="318" cy="336" r="4.2" fill="#BCE2FF" opacity="0.90"/>
      <!-- Bottom-right bright white flare cusp (Wired Memory) -->
      <path d="M 442 362 Q 442 334 420 334 L 464 334 Q 442 334 442 362 Z" fill="url(#whiteFlare)"/>
      <circle cx="442" cy="336" r="4.8" fill="#FFFFFF" opacity="0.96"/>
    </g>
  </g>

  <!-- ===== CENTERPIECE FLOATING DARK GLASS NODE CARD ===== -->
  <g filter="url(#cardDrop)">
    <rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" rx="18" fill="url(#nodeSurface)"/>
    <g clip-path="url(#nodeClip)">
      <rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" fill="url(#nodeEdgeL)"/>
      <rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" fill="url(#nodeEdgeR)"/>
    </g>
    <rect x="{cx}" y="{cy}" width="{cw}" height="{ch}" rx="18" fill="none" stroke="url(#nodeStroke)" stroke-width="1"/>

    <!-- Pervigil mark icon on left inside node -->
    <g transform="translate(260, 217) scale(0.076)" filter="url(#softGlow)">
      <path fill-rule="evenodd" d="{MARK_FULL}" fill="url(#markBlue)"/>
      <polygon class="breathe" points="{MARK_INNER}" fill="#FFFFFF" opacity="0.92"/>
    </g>

    <!-- Node title & subtitle -->
    <text x="320" y="237" fill="#F4F7FC" font-size="20" font-weight="500" letter-spacing="-0.3">Inference Host</text>
    <text x="320" y="259" fill="#8B98AD" font-size="12" font-weight="400">Ollama · LM Studio · llama-server</text>

    <!-- Active status check in bottom-right corner -->
    <path d="M 503 298 L 507.2 302.4 L 515.5 293.5" fill="none" stroke="#62B6FF" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" filter="url(#softGlow)"/>
  </g>

  <!-- Port labels between top node and telemetry card -->
  <text x="310" y="384" fill="#9BB8DB" font-size="11.5" font-weight="500" text-anchor="middle">GPU &amp; Thermal</text>
  <rect x="394" y="368" width="96" height="24" rx="7" fill="rgba(6,12,24,0.68)" stroke="rgba(180,220,255,0.16)" stroke-width="0.8"/>
  <text x="442" y="384" fill="#E6F2FF" font-size="11.5" font-weight="500" text-anchor="middle">Wired Memory</text>

  <!-- ===== LOWER LUMINOUS TELEMETRY & VRAM CARD ===== -->
  <g filter="url(#cardDrop)">
    <rect x="206" y="424" width="348" height="132" rx="16" fill="url(#telWash)"/>
    <rect x="206" y="424" width="348" height="132" rx="16" fill="none" stroke="url(#telStroke)" stroke-width="1.1"/>

    <!-- Top metadata row -->
    <text x="224" y="446" fill="#B8DAFF" font-size="11" font-weight="500" opacity="0.9">Apple Silicon · Wired 48 / 64 GB</text>
    <circle cx="228" cy="463" r="3" fill="#74C0FF" class="pulse"/>
    <text x="238" y="467" fill="#F6FAFF" font-size="12.5" font-weight="500">GPU Load <tspan fill="#9EC7F5" font-weight="400">·</tspan> <tspan class="num" font-weight="600">76%</tspan></text>

    <!-- Right micro signal bars + thermal/swap status -->
    <g transform="translate(438, 452)" fill="#7EC4FF">
      <rect x="0" y="7" width="2" height="5" rx="1" opacity="0.5"/>
      <rect x="4" y="5" width="2" height="7" rx="1" opacity="0.7"/>
      <rect x="8" y="2.5" width="2" height="9.5" rx="1" opacity="0.9"/>
      <rect x="12" y="0" width="2" height="12" rx="1" fill="#E6F3FF"/>
    </g>
    <text x="536" y="463" class="num" fill="#DCEBFF" font-size="12" font-weight="500" text-anchor="end">61°C · 0 swap</text>

    <!-- Inset dark glass meter well with sparkling dots & glowing progress track -->
    <rect x="222" y="482" width="316" height="58" rx="10" fill="rgba(4,9,18,0.64)" stroke="rgba(160,210,255,0.14)" stroke-width="0.9"/>
    {star_dots()}

    <!-- Progress track -->
    <rect x="236" y="510" width="288" height="3" rx="1.5" fill="rgba(255,255,255,0.14)"/>
    <!-- Active luminous fill (76% = 219px) -->
    <rect x="236" y="510" width="219" height="3" rx="1.5" fill="url(#meterFill)" filter="url(#softGlow)"/>
    <circle cx="455" cy="511.5" r="3.2" fill="#FFFFFF" filter="url(#softGlow)" class="pulse"/>

    <!-- Percentage scale ticks -->
    <text x="236" y="531" class="num" fill="#8FAAC8" font-size="10.2" text-anchor="start">0%</text>
    <text x="308" y="531" class="num" fill="#8FAAC8" font-size="10.2" text-anchor="middle">25%</text>
    <text x="380" y="531" class="num" fill="#8FAAC8" font-size="10.2" text-anchor="middle">50%</text>
    <text x="452" y="531" class="num" fill="#CFE7FF" font-size="10.2" font-weight="600" text-anchor="middle">75%</text>
    <text x="524" y="531" class="num" fill="#8FAAC8" font-size="10.2" text-anchor="end">100%</text>
  </g>
</g>
<!-- Crisp outer border -->
<rect width="{w}" height="{h}" rx="20" fill="none" stroke="rgba(155,208,255,0.16)" stroke-width="1"/>
</svg>
"""
    return svg


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    out_path = OUT / "inference_host.svg"
    out_path.write_text(build_inference_graphic(), encoding="utf-8")
    print(f"Wrote {out_path} ({out_path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
