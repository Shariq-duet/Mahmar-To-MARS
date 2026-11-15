# Mahmar To MARS: Procedural Mars Survival & Ascent Simulation

[![NASA Space Apps Challenge 2026](https://img.shields.io/badge/NASA%20Space%20Apps-Challenge%20%2303-0B3D91?style=for-the-badge&logo=nasa)](https://www.spaceappschallenge.org/)
[![Engine](https://img.shields.io/badge/Engine-Godot%204.3%2B-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)](https://godotengine.org)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-333333?style=for-the-badge)](https://github.com/Shariq-duet/Mahmar-To-MARS)
[![Tests](https://img.shields.io/badge/Tests-30%2F30%20Passing%20(100%25)-success?style=for-the-badge)](tests/)

> **A high-fidelity 3D Mars survival and orbital ascent experience built in Godot 4, combining authentic spherical planetary physics, real-time NASA space weather telemetry, and engineering-driven life support restoration.**

---

## 🚀 Overview

**Mahmar To MARS** challenges players to survive the unforgiving environmental realities of Mars after a catastrophic atmospheric entry. Stranded on an authentic procedural cube-sphere planet, the astronaut awakens wounded at the crash site. To survive and return to orbit, players must reach the emergency Life Pod, restore damaged closed-loop life support systems, and repair the Mars Ascent Vehicle (MAV).

Instead of relying on arbitrary game tropes, every survival mechanic in Ares Sol directly models authentic aerospace engineering and real-world planetary science.

---

## 🔬 Scientific Validity & NASA Data Integration

1. **NASA DONKI Space Weather API (Real-Time Solar Storms)**:
   - Queries NASA's **Space Weather Database of Notifications, Knowledge, and Information (DONKI)** to simulate Coronal Mass Ejection (CME) solar flare events in real time.
   - When a solar storm hits Mars, a 30-second warning sounds, followed by lethal environmental radiation ($-3.0/\text{s}$ health drain) requiring players to seek shelter inside the Life Pod.

2. **NASA MOLA Laser Altimetry Topography**:
   - Terrain generation models genuine Martian geology based on Mars Orbiter Laser Altimeter data:
     - Mathematical impact crater distribution with authentic depth-to-radius ratios and raised ejecta rims.
     - Deep tectonic fissures modeling the **Noctis Labyrinthus** chasm system.
     - Subterranean volcanic lava tubes inspired by the **Elysium Planitia** cave networks.

3. **NASA Historical Mission Relics**:
   - Historical coordinates and exploration logs from NASA's landmark Mars missions are scattered across crater rims as discoverable relics:
     - **Mariner 4 (1965)**, **Viking 1 (1976)**, **Sojourner (1997)**, **Opportunity (2004)**, **Curiosity (2012)**, and **InSight (2018)**.

4. **Solar Zenith & Celestial Cycles**:
   - Sols last 10 real minutes with accurate diurnal lighting.
   - Solar panel power generation mathematically tracks the sun's elevation angle ($2.0/\text{s}$ peak at solar noon, $0/\text{s}$ at night).
   - Dynamic dust storms cut solar efficiency by $50\%$.

---

## 🛠️ Core Gameplay & Survival Systems

| System | Baseline Drain / Generation | Dynamic Gameplay Modifiers |
|---|---|---|
| **Oxygen** | $-0.05/\text{s}$ inside Pod shelter | $1.5\times$ on EVA ($-0.075/\text{s}$), $3.0\times$ while jetpacking. Scrubber repair permanently cuts drain by $50\%$. |
| **Power** | Solar Zenith generation curve | $2.0/\text{s}$ peak at solar noon; zero at night. Repaired Power Unit adds $+50\%$ efficiency. |
| **Hydration** | $-0.03/\text{s}$ hydration baseline | Harvest raw cryogenic water ice from mountain glacial basins ($+10\%$ per ice sample). |
| **Shelter & Health** | Regenerates inside pod (>20% vitals) | Severe hypothermia, starvation, or CME radiation trigger rapid suit failure and health decay. |

---

## 🎯 Mission Objectives: The Path to Orbital Ascent

1. **Awaken & Reach Habitat**: Navigate from the crash site to the emergency Life Pod using the initial wounded/haggard gait.
2. **Salvage the Oxygen Filter Core**: Recover the filter core perched on the edge of the dangerous crevasse at `cargo_site`.
3. **Salvage the Power Unit Core**: Recover the auxiliary power core from the abandoned rover at `rover_site`.
4. **Harvest Mountain Water Ice**: Climb the mountain glacier basin to collect cryogenic water ice samples.
5. **Complete Habitat Life Support Repairs**: Use hold-[E] at each station to restore the Oxygen Scrubber, Power Unit, and Water Purification system.
6. **Prep & Launch Mars Ascent Vehicle (MAV)**: Return to the rocket, complete the 3-second pre-flight diagnostic hold, and initiate the cinematic liftoff into Mars orbit.

---

## 🎮 Controls

| Action | Key / Input |
|---|---|
| **Movement** | `W`, `A`, `S`, `D` |
| **Sprint** | `Shift` (Consumes increased oxygen) |
| **Jump / Jetpack** | `Space` (Hold for 3D planetary jetpack thrusters) |
| **Interact / Repair / Salvage** | `E` (Hold for circular progress ring repair) |
| **Camera Look** | Mouse |
| **Skip Intro Cutscene** | `Esc` |

---

## 📊 Presentation Deck & Demonstrations

* **Pitch Deck**: [`Ares_Sol_NASA_Space_Apps_Presentation.pptx`](Ares_Sol_NASA_Space_Apps_Presentation.pptx) *(Full 7-slide widescreen deck for NASA Space Apps Global Judging)*
* **Interactive HTML Presentation**: [`presentation.html`](presentation.html) *(Self-contained 16:9 presentation deck with built-in 7-minute timer and speaker notes)*

---

## 🧪 Architecture & Automated Testing

The project includes an automated test suite verifying all physics, shaders, and survival economics:
* **Physics & Terrain**: Raycast cave verification, spherical gravity alignment, smooth LOD subdivision.
* **Cutscene Integrity**: Verified 4-camera cinematic opening with rocket nozzle exhaust particles, atmospheric entry plume, and aftermath smoke venting.
* **Test Verification**: 30/30 automated unit tests passing (`tests/test_verify_lighting_cargo_survival_ending.gd`).

---

## 🤖 AI Evidence & Usage Disclosure

In compliance with the NASA Space Apps Challenge AI policy, full transcripts of the human-directed AI pair programming and design sessions are archived:
* **Evidence Directory**: [`ai-evidence/`](ai-evidence/)
* **Session 1 Transcript**: [`ai-evidence/Chat_01_Architecture_Movement_and_Terrain.md`](ai-evidence/Chat_01_Architecture_Movement_and_Terrain.md)
* **Session 2 Transcript**: [`ai-evidence/Chat_02_Survival_Cutscenes_and_Polishing.md`](ai-evidence/Chat_02_Survival_Cutscenes_and_Polishing.md)
* **Raw Cryptographic Logs**: [`ai-evidence/raw/`](ai-evidence/raw/)

---

## 👥 NASA Space Apps Team

* **Challenge**: NASA Space Apps Challenge 2026 — Challenge #03
* **Local Event**: Karachi Local Event
* **Author / Developer**: Syed Muhammad Shariq (`Shariq-duet`)
