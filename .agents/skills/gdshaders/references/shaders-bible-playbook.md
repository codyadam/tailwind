# The Godot Shaders Bible Playbook

Primary source:
- `/home/mewhhaha/Downloads/ENG_The_Godot_Shaders_Bible_v011_DIGITAL.pdf`
- Paid product page:
  `https://jettelly.com/store/the-godot-shaders-bible`

Use this file for practical effect design and implementation sequencing. Use the official
language reference for syntax authority.

## Source Availability Rules

- Prefer the local PDF when present.
- If the local PDF is missing, continue using:
  - `references/godot-shading-language.md` for syntax correctness.
  - This playbook for implementation heuristics already extracted from the book.
  - User-provided excerpts if available.
- If deeper chapter detail is required and the local PDF is missing, explicitly state that
  the book is paid and direct acquisition to:
  `https://jettelly.com/store/the-godot-shaders-bible`

## Chapter Map To User Intents

- Chapter 1 (Mesh composition, spaces, matrices, tangent space):
  Use for coordinate-space bugs, UV-driven effects, billboard math, custom vertex transforms.
- Chapter 2 (Lighting and rendering):
  Use for custom diffuse/specular pipelines, Fresnel/rim, anisotropic highlights, normal mapping.
- Chapter 3 (Procedural shapes and vertex animation):
  Use for math-driven masks, function/inequality drawing, animated deformation, 2D shader motion.
- Chapter 4 (Advanced VFX/post):
  Use for screen-space filters, Shadertoy ports, transparency-distance blending, ray marching, stencil.

## Reusable Effect Recipes

### 1) Space-First Shader Construction

- Decide one working space per computation (object, world, view, tangent).
- Transform vectors once, then keep all dot/cross products in that same space.
- For camera-dependent UV distortions, build a tangent basis and project view direction into it.

### 2) Diffuse And Specular Lighting Stack

- Lambert diffuse baseline:
  `max(dot(NORMAL, LIGHT), 0.0)` with attenuation and light color terms.
- Add specular as a separate term so intensity and exponent are independently tunable.
- Blinn-Phong variant:
  use `normalize(LIGHT + VIEW)` half-vector for more stable highlights.
- Rim/Fresnel accent:
  drive rim intensity from view-vs-normal angle and blend with albedo/specular outputs.

### 3) Anisotropic Highlighting

- Carry tangent-space orientation data when specular shape must stretch directionally.
- Use tangent/binormal-aware exponents to shape the highlight along material flow.
- Keep anisotropic terms modular so they can be switched or blended with simpler specular models.

### 4) Normal Mapping Integration

- Sample normal textures in tangent space.
- Remap sampled values from texture range to signed vector range before use.
- Build or reuse a TBN basis when moving from tangent-space normals to working space.
- Keep normal-map intensity as a separate scalar uniform for art tuning.

### 5) Procedural And Animated Forms

- Build masks from simple inequalities and smooth transitions (`step`, `smoothstep` patterns).
- Layer small functions to compose complex silhouettes instead of writing one monolithic expression.
- Animate with time and low-cost trig for stable motion.
- Keep deformation amounts in uniforms so artists can tune without code edits.

### 6) Post-Processing And Screen Effects

- Use `canvas_item` shaders plus screen texture sampling for full-screen filters.
- For Shadertoy ports, map source UV/time/resolution assumptions to Godot conventions first.
- Introduce effects in slices: grayscale/quantization first, then edge/noise/stylization.

### 7) Ray-Marching Workflow

- Start with a minimal signed-distance function and bounded march loop.
- Add normal estimation and simple lighting only after hit logic is stable.
- Expose step count, epsilon, and max distance as uniforms for quality/performance tuning.

## Debug Heuristics

- Black or flat output:
  verify stage built-ins and ensure ALBEDO/lighting outputs are written in the right stage.
- Sparkly or unstable highlights:
  normalize vectors and verify all lighting math uses one consistent space.
- Normal map looks inverted or wrong:
  verify tangent basis orientation and channel remap/sign conventions.
- UV distortion swims unexpectedly:
  verify whether distortion is intended in object/world/view/tangent coordinates.
- Shader works in one material but not another instance:
  check per-instance uniform index collisions and limits.

## Practical Parameter Seeds

Use as starting points, then tune in editor:

- UV displacement offsets: small ranges (for example `0.0` to `0.3`) for stable parallax-like motion.
- Anisotropy exponents: wide ranges (for example `0` to high hundreds) for directional control.
- Normal map strength: allow negative-to-positive range when stylized inversion is useful.

## Optional Source Mining Commands

When you need extra detail from the local PDF:

```bash
PDF="/home/mewhhaha/Downloads/ENG_The_Godot_Shaders_Bible_v011_DIGITAL.pdf"
if [ -f "$PDF" ]; then
  pdftotext -layout "$PDF" /tmp/gdshaders-bible.txt
  rg -n "Lambert|Blinn|Rim|Anisotropic|Normal Map|Ray Marching|Shadertoy|Stencil|tangent|matrix" /tmp/gdshaders-bible.txt
else
  echo "Local PDF not found. Acquire from: https://jettelly.com/store/the-godot-shaders-bible" >&2
fi
```

Use these commands to pull chapter-specific snippets without loading the entire PDF at once.
