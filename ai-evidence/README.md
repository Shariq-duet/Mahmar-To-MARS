# NASA Space Apps Challenge 2026 — AI Evidence & Transparency Disclosure

[![NASA Space Apps AI Policy](https://img.shields.io/badge/NASA%20Space%20Apps-AI%20Transparency%20Compliant-0B3D91?style=for-the-badge&logo=nasa)](https://www.spaceappschallenge.org/)
[![Documentation](https://img.shields.io/badge/Documentation-Verified-success?style=for-the-badge)](.)

This directory contains complete, unedited conversation records and evidence of Artificial Intelligence (AI) tool utilization during the development of **Mahmar To MARS: Procedural Mars Survival & Ascent Simulation** for the **NASA Space Apps Challenge 2026 (Challenge #03)**.

---

## 📋 Statement of AI Usage & Human Authorship

In full accordance with the NASA Space Apps Challenge Global Rules regarding AI and automated tools:

1. **Human Direction & Systems Architecture**:
   - The conceptual vision, gameplay design, educational learning objectives, NASA data selection, physical level layout, and creative direction were authored and driven by the human developer (**Syed Muhammad Shariq**).
   - Every mechanic, algorithm, and asset placement was requested, reviewed, tested, and validated through human iteration.

2. **Role of AI Tools**:
   - Generative AI coding assistants (Anthropic Claude Sonnet & Google Gemini) were utilized as intelligent pair programmers and engineering accelerators:
     - Formulating vector math for spherical planetary surface gravity, cube-sphere quadtree projections, and crater displacements.
     - Authoring custom Godot 4 shaders for Mars atmospheric sky, procedural terrain blending, and water ice deposits.
     - Structuring GDScript state machines, survival economies, and automated physics test scripts.
     - Generating unit verification suites (e.g. 30/30 automated unit tests ensuring 60 FPS performance and zero clipping).

---

## 📂 Evidence Archive Contents

| Document | Format | Description |
|---|---|---|
| [**Chat 01: Architecture, Movement & Terrain**](Chat_01_Architecture_Movement_and_Terrain.md) | Markdown (`.md`) | **Phase 1 Transcript** (111 turns): Architectural planning, Outer Wilds-style spherical gravity & movement, procedural cube-sphere planet, terrain shader, and astronaut animation rigging. |
| [**Chat 02: Survival, Cutscenes & Polishing**](Chat_02_Survival_Cutscenes_and_Polishing.md) | Markdown (`.md`) | **Phase 2 Transcript** (49 turns): Procedural Martian landmarks (caves, crevasse, mountain water deposit), day/night solar cycle, survival mechanics (O2, power, water), opening & ending cutscenes, bug fixes, and pitch deck preparation. |
| [**Raw Session 1 Transcript**](raw/chat_01_transcript.jsonl) | JSONL (`.jsonl`) | Raw cryptographic/verifiable event log of Session 1 from the Antigravity developer environment. |
| [**Raw Session 2 Transcript**](raw/chat_02_transcript.jsonl) | JSONL (`.jsonl`) | Raw cryptographic/verifiable event log of Session 2 from the Antigravity developer environment. |

---

## 🔍 Key Highlights of AI-Assisted Iteration

* **Spherical Planetary Mathematics**: Deriving smooth surface projection vectors and tangent bases to ensure seamless walking across all 6 faces of the normalized cube-sphere planet.
* **Physics & Shader Optimization**: Writing high-performance HLSL/GLSL-compatible Godot shaders that compute distance-based triplanar blending without stalling the main thread.
* **Closed-Loop Survival Balances**: Tuning mathematical drain rates across multiple player states (indoor shelter, EVA traversal, jetpacking) tied to real-time solar zenith angles.
* **Automated Unit Testing**: Developing comprehensive headless test scripts (`tests/`) to verify landing coordinates, hatch headroom clearance ($>2.5\text{m}$), and sub-millisecond frametimes ($<2.0\text{ms}$).
