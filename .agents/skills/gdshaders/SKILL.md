---
name: gdshaders
description: Author, port, and debug Godot `.gdshader` code for `spatial`, `canvas_item`, `particle`, and `fog` pipelines. Use when requests require shader source changes, shader-language/compiler fixes, built-in or stage selection, uniform/varying wiring, or GLSL/Shadertoy-to-Godot shader translation. Do not use for non-shader rendering setup (materials, scene nodes, project lighting config) unless `.gdshader` authoring is explicitly requested.
---

# GDShaders

Use this skill to produce reliable Godot shader answers that stay syntax-correct and practical.

## License Notice

- This skill is for private/internal use only.
- Do not redistribute or publish this skill or its reference material.
- `The Godot Shaders Bible` is a paid product:
  `https://jettelly.com/store/the-godot-shaders-bible`
- See `LICENSE.txt` for full terms.

## Follow This Workflow

1. Classify the request by pipeline and stage.
- Identify shader type first: `spatial`, `canvas_item`, `particle`, or `fog`.
- Identify stage next: `vertex`, `fragment`, `light`, `start`, `process`, or `fog`.

2. Pull the right references before coding.
- Read `references/godot-shading-language.md` for syntax, built-ins, stage restrictions, and uniform/varying limits.
- Read `references/shaders-bible-playbook.md` for implementation recipes and task-to-technique mapping.

3. Build a compile-safe skeleton first.
- Emit a minimal shader that compiles in the selected pipeline.
- Add one feature at a time and keep space transforms explicit (`object`, `world`, `view`, `tangent`).

4. Implement the requested effect using reusable patterns.
- Use helper functions for repeatable lighting logic.
- Expose tunable parameters as inspector-facing `uniform` values with hints/ranges.
- Keep syntax and built-ins aligned with the official docs even when adapting Bible recipes.

5. Run a failure-oriented review pass.
- Check stage contract violations (for example, illegal varying assignments).
- Check array safety and index bounds.
- Check per-instance/global uniform constraints.
- Check that each built-in is valid for the shader type/stage.

## Route By Task Type

- Shader parser/compiler errors:
  Read `references/godot-shading-language.md` first.
- New effect authoring (lighting, stylized materials, procedural motion, post):
  Read both references, then implement from playbook patterns.
- GLSL/Shadertoy porting:
  Start with syntax reference, then adapt effect structure from playbook.
- Performance or artifact debugging:
  Use playbook debug heuristics, then verify against official language constraints.

## Do Not Route Here

- Pure editor/node setup questions with no shader code requested.
- General art-direction requests that do not need `.gdshader` changes.
- Rendering pipeline tuning unrelated to shader source (project settings, import settings, scene-only setup).
- Requests that are purely about buying/licensing the book or store support.

## Output Contract

Default response contract:

- If the user requests implementation/fix work, provide complete `.gdshader` code unless the user asks for patch-only edits.
- If the user requests conceptual explanation only, provide concise reasoning and include code only when it clarifies the answer.
- List exposed uniforms with short purpose notes when code is provided.
- Call out pipeline/stage assumptions explicitly.
- Add a quick verification checklist the user can run in Godot when behavior is expected to change.

## Canonical Sources

- Official syntax authority:
  `https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html`
- Practical recipe source:
  `/home/mewhhaha/Downloads/ENG_The_Godot_Shaders_Bible_v011_DIGITAL.pdf`
