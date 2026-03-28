# Godot Shading Language (Official Rules)

Primary source:
- `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html`

Treat this file as the syntax and semantic authority when code and examples disagree.

## Pick The Correct Shader Pipeline

- `shader_type spatial;` for 3D materials.
- `shader_type canvas_item;` for 2D/UI.
- `shader_type particle;` for GPU particles.
- `shader_type fog;` for volumetric fog shaders.

Stage entrypoints differ by pipeline:
- Spatial: `vertex`, `fragment`, optional `light`.
- Canvas item: `vertex`, `fragment`, optional `light`.
- Particle: `start`, `process`.
- Fog: `fog`.

## Core Syntax Reminders

- Use explicit types (`float`, `int`, `vec*`, `mat*`, sampler types).
- Use constructors for complex literals (`vec3(1.0)`, `mat3(...)`).
- Use integer loop counters for deterministic loops.
- Use shader constants for immutable math shared across stages.

## Arrays, Structs, And Safety

- Use typed arrays (`float[3]`, `vec2[](...)`, `int[3](...)`).
- Use struct arrays when grouped data is clearer than parallel arrays.
- Use array uniforms when author-facing lists are required.
- Do not use varying arrays (unsupported).
- Keep local arrays modest; parser limits are around 5k elements for local arrays.
- Treat out-of-bounds indexing as a bug.
- Expect undefined reads and possible GPU crashes for out-of-bounds writes.

## Varyings And Interpolation

- Declare varyings globally with explicit types.
- Assign varyings only in `vertex()` or `fragment()`.
- Do not assign varyings inside custom helper functions.
- Do not assign varyings in `light()`.
- Use `flat` to disable interpolation for discrete data.
- Use `smooth` for default perspective-correct interpolation.

Directional flow constraints:
- Send data `vertex -> fragment` through varyings.
- Send data `fragment -> light` through varyings when needed.

## Uniform Models

Local uniforms:
- Declare with `uniform`.
- Add hints and ranges for editor ergonomics.

Global uniforms:
- Declare with `global uniform`.
- Configure values in Project Settings.
- Do not rely on shader-side defaults for globals.

Grouped uniforms:
- Use `group_uniforms GroupName;` ... `group_uniforms;` to organize inspector UI.

Per-instance uniforms:
- Declare with `instance uniform`.
- Use for per-node overrides without duplicating materials.
- Avoid sampler/texture types in per-instance uniforms.
- Respect platform-dependent limits (typically 16 instance uniforms).
- Remember `MultiMesh` does not support per-instance shader uniforms.
- If multiple materials on one mesh need stable mapping, set explicit indices with
  `instance_index(n)`.

## Built-ins Are Shader-Type Specific

Always verify built-ins against shader type pages:
- Spatial built-ins:
  `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html`
- Canvas item built-ins:
  `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html`
- Particle built-ins:
  `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html`
- Fog built-ins:
  `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/fog_shader.html`

Never assume a built-in from one pipeline exists in another.

## Fast Porting Checklist (GLSL/Shadertoy -> Godot)

- Map entrypoint and semantics to Godot stages (`fragment`, `light`, `process`, etc.).
- Replace external uniforms with Godot uniform declarations and hints.
- Replace screen/buffer access with Godot texture hints and sampling conventions.
- Re-check matrix/space assumptions (`object`, `world`, `view`, `clip`, `tangent`).
- Re-validate varyings flow and interpolation qualifiers.
