import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def create_deck():
    prs = Presentation()
    # 16:9 widescreen dimensions
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6] # blank layout

    # Color palette
    BG_DARK = RGBColor(11, 14, 20)        # #0B0E14
    CARD_BG = RGBColor(19, 25, 36)        # #131924
    CARD_BORDER = RGBColor(38, 50, 72)    # #263248
    CYAN_ACCENT = RGBColor(63, 208, 240)  # #3FD0F0 (HUD Cyan)
    ORANGE_ACCENT = RGBColor(224, 70, 60) # #E0463C (Mars Rust)
    GOLD_ACCENT = RGBColor(240, 168, 48)  # #F0A830 (Amber Alert)
    TEXT_LIGHT = RGBColor(245, 248, 255)  # White/Off-white
    TEXT_MUTED = RGBColor(150, 168, 195)  # Soft slate
    TEXT_DIM = RGBColor(100, 118, 145)    # Dim slate

    def set_slide_background(slide):
        bg = slide.shapes.add_shape(
            MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(7.5)
        )
        bg.fill.solid()
        bg.fill.fore_color.rgb = BG_DARK
        bg.line.fill.background()
        return bg

    def add_header(slide, tag_text, title_text, slide_num):
        # Header text box
        tb = slide.shapes.add_textbox(Inches(0.8), Inches(0.45), Inches(11.733), Inches(1.1))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        
        # Tag
        p_tag = tf.paragraphs[0]
        p_tag.text = tag_text.upper()
        p_tag.font.name = "Segoe UI"
        p_tag.font.size = Pt(10)
        p_tag.font.bold = True
        p_tag.font.color.rgb = CYAN_ACCENT
        p_tag.space_after = Pt(2)

        # Title
        p_title = tf.add_paragraph()
        p_title.text = title_text
        p_title.font.name = "Segoe UI"
        p_title.font.size = Pt(22)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_LIGHT

        # Slide number badge on right
        nb = slide.shapes.add_textbox(Inches(11.2), Inches(0.45), Inches(1.333), Inches(0.4))
        ntf = nb.text_frame
        ntf.margin_left = ntf.margin_top = ntf.margin_right = ntf.margin_bottom = 0
        np = ntf.paragraphs[0]
        np.text = f"SLIDE {slide_num} OF 7"
        np.alignment = PP_ALIGN.RIGHT
        np.font.name = "Segoe UI"
        np.font.size = Pt(10)
        np.font.bold = True
        np.font.color.rgb = TEXT_DIM

    def add_card(slide, left, top, width, height, bg_color=CARD_BG, border_color=CARD_BORDER):
        card = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        card.fill.solid()
        card.fill.fore_color.rgb = bg_color
        card.line.color.rgb = border_color
        card.line.width = Pt(1.2)
        return card

    # =========================================================================
    # SLIDE 1: TITLE SLIDE
    # =========================================================================
    s1 = prs.slides.add_slide(blank_layout)
    set_slide_background(s1)

    # Hero image on right side
    img1_path = "tests/cutscene_03s_entry_heatplume.png"
    if os.path.exists(img1_path):
        img_left = Inches(6.8)
        img_top = Inches(0.8)
        img_w = Inches(5.8)
        img_h = Inches(5.9)
        # Background card behind image
        add_card(s1, img_left - Inches(0.08), img_top - Inches(0.08), img_w + Inches(0.16), img_h + Inches(0.16), CARD_BG, CYAN_ACCENT)
        s1.shapes.add_picture(img1_path, img_left, img_top, img_w, img_h)

        # Image caption
        cap_box = s1.shapes.add_textbox(img_left, img_top + img_h - Inches(0.5), img_w, Inches(0.4))
        ctf = cap_box.text_frame
        ctf.margin_left = Inches(0.2)
        cp = ctf.paragraphs[0]
        cp.text = "IN-GAME CUTSCENE: Atmospheric Entry & Sol 1 Descent"
        cp.font.name = "Segoe UI"
        cp.font.size = Pt(9)
        cp.font.bold = True
        cp.font.color.rgb = CYAN_ACCENT

    # Left content box
    left_tb = s1.shapes.add_textbox(Inches(0.8), Inches(1.0), Inches(5.6), Inches(5.6))
    ltf = left_tb.text_frame
    ltf.word_wrap = True
    ltf.margin_left = ltf.margin_top = ltf.margin_right = ltf.margin_bottom = 0

    # Competition Badge
    p0 = ltf.paragraphs[0]
    p0.text = "NASA SPACE APPS CHALLENGE 2026 | KARACHI LOCAL EVENT"
    p0.font.name = "Segoe UI"
    p0.font.size = Pt(10)
    p0.font.bold = True
    p0.font.color.rgb = GOLD_ACCENT
    p0.space_after = Pt(12)

    # Main Title
    p1 = ltf.add_paragraph()
    p1.text = "ARES SOL"
    p1.font.name = "Segoe UI"
    p1.font.size = Pt(44)
    p1.font.bold = True
    p1.font.color.rgb = TEXT_LIGHT

    # Subtitle
    p2 = ltf.add_paragraph()
    p2.text = "Procedural Mars Survival & Ascent Simulation"
    p2.font.name = "Segoe UI"
    p2.font.size = Pt(16)
    p2.font.bold = True
    p2.font.color.rgb = CYAN_ACCENT
    p2.space_after = Pt(20)

    # Description
    p3 = ltf.add_paragraph()
    p3.text = "A high-fidelity 3D Mars survival experience built in Godot 4. Powered by real NASA planetary data, dynamic space weather, authentic cube-sphere orbital physics, and engineering-driven habitat restoration."
    p3.font.name = "Segoe UI"
    p3.font.size = Pt(11)
    p3.font.color.rgb = TEXT_MUTED
    p3.space_after = Pt(24)

    # Team & Challenge Details Card
    t_box = s1.shapes.add_textbox(Inches(0.8), Inches(4.7), Inches(5.6), Inches(1.8))
    ttf = t_box.text_frame
    ttf.word_wrap = True
    ttf.margin_left = ttf.margin_top = ttf.margin_right = ttf.margin_bottom = 0

    tp1 = ttf.paragraphs[0]
    tp1.text = "CHALLENGE:"
    tp1.font.name = "Segoe UI"
    tp1.font.size = Pt(9)
    tp1.font.bold = True
    tp1.font.color.rgb = CYAN_ACCENT

    tp2 = ttf.add_paragraph()
    tp2.text = "NASA Space Apps Challenge #03"
    tp2.font.name = "Segoe UI"
    tp2.font.size = Pt(11)
    tp2.font.color.rgb = TEXT_LIGHT
    tp2.space_after = Pt(8)

    tp3 = ttf.add_paragraph()
    tp3.text = "TEAM NAME & MEMBERS:"
    tp3.font.name = "Segoe UI"
    tp3.font.size = Pt(9)
    tp3.font.bold = True
    tp3.font.color.rgb = CYAN_ACCENT

    tp4 = ttf.add_paragraph()
    tp4.text = "[Your Team Name]  |  [Member 1, Member 2, Member 3, Member 4]"
    tp4.font.name = "Segoe UI"
    tp4.font.size = Pt(11)
    tp4.font.color.rgb = TEXT_LIGHT

    # =========================================================================
    # SLIDE 2: THE CHALLENGE & MISSION NARRATIVE
    # =========================================================================
    s2 = prs.slides.add_slide(blank_layout)
    set_slide_background(s2)
    add_header(s2, "Challenge & Mission Narrative", "Sol 1: Stranded on the Martian Frontier", 2)

    # Left text column (Cards)
    add_card(s2, Inches(0.8), Inches(1.8), Inches(5.7), Inches(1.5))
    c1 = s2.shapes.add_textbox(Inches(1.0), Inches(1.95), Inches(5.3), Inches(1.2))
    ctf1 = c1.text_frame
    ctf1.word_wrap = True
    ctf1.margin_left = ctf1.margin_top = ctf1.margin_right = ctf1.margin_bottom = 0
    p = ctf1.paragraphs[0]
    p.text = "THE PROBLEM: SURVIVING EXTREME ISOLATION"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = ORANGE_ACCENT
    p = ctf1.add_paragraph()
    p.text = "Human exploration of Mars involves unforgiving environmental hazards: an unbreathable atmosphere, lethal solar radiation, catastrophic dust storms, and extreme resource scarcity."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    add_card(s2, Inches(0.8), Inches(3.5), Inches(5.7), Inches(1.5))
    c2 = s2.shapes.add_textbox(Inches(1.0), Inches(3.65), Inches(5.3), Inches(1.2))
    ctf2 = c2.text_frame
    ctf2.word_wrap = True
    ctf2.margin_left = ctf2.margin_top = ctf2.margin_right = ctf2.margin_bottom = 0
    p = ctf2.paragraphs[0]
    p.text = "THE MISSION: SOL 1 CRASH-LANDING"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
    p = ctf2.add_paragraph()
    p.text = "After a catastrophic descent, the player awakens wounded next to their crash site. Survival demands reaching the emergency Life Pod, securing life support, and engineering an ascent back to orbit."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    add_card(s2, Inches(0.8), Inches(5.2), Inches(5.7), Inches(1.5))
    c3 = s2.shapes.add_textbox(Inches(1.0), Inches(5.35), Inches(5.3), Inches(1.2))
    ctf3 = c3.text_frame
    ctf3.word_wrap = True
    ctf3.margin_left = ctf3.margin_top = ctf3.margin_right = ctf3.margin_bottom = 0
    p = ctf3.paragraphs[0]
    p.text = "THE SOLUTION: SCIENCE-DRIVEN SURVIVAL"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = GOLD_ACCENT
    p = ctf3.add_paragraph()
    p.text = "Instead of artificial game tropes, every mechanic models genuine aerospace engineering: solar zenith power curves, cryogenic water ice melting, and real NASA solar flare alerts."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    # Right Image
    img2_path = "tests/cutscene_30s_cinematic_wreck.png"
    if os.path.exists(img2_path):
        add_card(s2, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s2.shapes.add_picture(img2_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        # Image description card below
        ic = s2.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ictf = ic.text_frame
        ictf.word_wrap = True
        ictf.margin_left = ictf.margin_top = ictf.margin_right = ictf.margin_bottom = 0
        p = ictf.paragraphs[0]
        p.text = "CINEMATIC CUTSCENE: MAV CRASH SITE & LANDING WRECK"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ictf.add_paragraph()
        p.text = "Rendered in real-time in Godot 4 using procedural regolith displacement shaders, volumetric smoke venting, and letterboxed cinematic camera framing."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 3: USER EXPERIENCE & CINEMATIC IMMERSION
    # =========================================================================
    s3 = prs.slides.add_slide(blank_layout)
    set_slide_background(s3)
    add_header(s3, "User Experience & Immersion", "Seamless Cinematic Transitions & Atmospheric Gameplay", 3)

    # Left Column: Image 1 (Lying astronaut in letterbox)
    img3a_path = "tests/screenshots/cinematic_start_lying_letterbox.png"
    if os.path.exists(img3a_path):
        add_card(s3, Inches(0.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s3.shapes.add_picture(img3a_path, Inches(0.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s3.shapes.add_textbox(Inches(1.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "LETTERBOXED PRONE INTRO & HAGGARD GAIT"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "The astronaut awakens face down on the regolith. Sol 1 features a unique haggard locomotion system (forward lean, limp, and dragged leg) reflecting wounded physical trauma."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # Right Column: Image 2 (Walkable Pod & HUD)
    img3b_path = "tests/screenshots/pod_hud_active.png"
    if os.path.exists(img3b_path):
        add_card(s3, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s3.shapes.add_picture(img3b_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s3.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "WALKABLE LIFE POD & DYNAMIC SURVIVAL HUD"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "Minimalist cyan telemetry inspired by Outer Wilds. Meters automatically hide during nominal state and smoothly fade in when resources drain or physiological danger occurs."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 4: REALISTIC SURVIVAL ECONOMY
    # =========================================================================
    s4 = prs.slides.add_slide(blank_layout)
    set_slide_background(s4)
    add_header(s4, "Core Game Systems", "Interconnected Physics & Resource Economies", 4)

    # 4 Feature Cards on Left
    card_w = Inches(5.7)
    card_h = Inches(1.15)
    
    systems = [
        ("OXYGEN SYSTEM (O2)", "0.05/s inside pod shelter, 1.5x outside on EVA, 3.0x while jetpacking. Scrubber repair permanently halves drain rate. Zero power doubles drain penalty.", CYAN_ACCENT),
        ("POWER GENERATION & DUST STORMS", "Follows the sun's zenith: 2.0/s peak at solar noon, 0/s at night. Repaired solar unit boosts gen by +50%. Sol 2 dust storms cut generation in half.", GOLD_ACCENT),
        ("WATER ICE HARVESTING & METABOLISM", "Constant 0.03/s hydration baseline. Players harvest raw cryogenic water ice from mountain basins to replenish habitat reserves (+10% per sample).", CYAN_ACCENT),
        ("SUIT INTEGRITY & PHYSIOLOGICAL HEALTH", "Regenerates inside pod when vitals > 20%. Harsh exterior conditions degrade suit; total depletion causes hypothermia and rapid health failure.", ORANGE_ACCENT)
    ]

    for idx, (title, desc, color) in enumerate(systems):
        top_y = Inches(1.8) + idx * Inches(1.25)
        add_card(s4, Inches(0.8), top_y, card_w, card_h)
        tb = s4.shapes.add_textbox(Inches(1.0), top_y + Inches(0.12), Inches(5.3), Inches(0.95))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(10.5); p.font.bold = True; p.font.color.rgb = color
        p = tf.add_paragraph()
        p.text = desc
        p.font.size = Pt(9.5); p.font.color.rgb = TEXT_MUTED

    # Right Image: Water Deposit & Mountain
    img4_path = "tests/screenshots/water_deposit_from_new_pod.png"
    if os.path.exists(img4_path):
        add_card(s4, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s4.shapes.add_picture(img4_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s4.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "WATER ICE DEPOSIT & RIDGED MOUNTAIN BASIN"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "Procedurally generated ridged mountain peak (>110m above radius) with a shallow pale-blue ice basin. Translucent ice shader with custom specular roughness."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 5: NASA DATA & PLANETARY SCIENCE
    # =========================================================================
    s5 = prs.slides.add_slide(blank_layout)
    set_slide_background(s5)
    add_header(s5, "Scientific Validity", "How NASA Data & Planetary Telemetry Powers the Game", 5)

    # 3 NASA Data Cards on Left
    nasa_data = [
        ("NASA DONKI API: REAL-TIME SPACE WEATHER", "Space Weather Database of Notifications, Knowledge, and Information. Directly drives the in-game Coronal Mass Ejection (CME) solar storm event on Sol 3: a 30s emergency warning banner, followed by 90s of lethal radiation (-3/s health outside), requiring immediate shelter in the life pod.", GOLD_ACCENT),
        ("NASA MOLA TOPOGRAPHY & CRATER PHYSICS", "Mars Orbiter Laser Altimeter laser altimetry telemetry used to formulate accurate crater depth-to-radius ratios, ejecta blanket lips, and vast geological features: the steep rock fissure of Noctis Labyrinthus and the volcanic caverns of Elysium Planitia.", CYAN_ACCENT),
        ("NASA HISTORICAL MARS MISSIONS CATALOG", "Historical telemetry and locations of six historic NASA exploration probes (Mariner 4, Viking 1, Sojourner, Opportunity, Curiosity, InSight) are embedded across crater rims as discoverable historical relics with scientific archival records.", ORANGE_ACCENT)
    ]

    for idx, (title, desc, color) in enumerate(nasa_data):
        top_y = Inches(1.8) + idx * Inches(1.68)
        add_card(s5, Inches(0.8), top_y, Inches(5.7), Inches(1.55))
        tb = s5.shapes.add_textbox(Inches(1.0), top_y + Inches(0.15), Inches(5.3), Inches(1.25))
        tf = tb.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = title
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = color
        p = tf.add_paragraph()
        p.text = desc
        p.font.size = Pt(9.5); p.font.color.rgb = TEXT_MUTED

    # Right Image: Noctis Chasm
    img5_path = "tests/screenshots/cave_entrance_noctis_closeup.png"
    if os.path.exists(img5_path):
        add_card(s5, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s5.shapes.add_picture(img5_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s5.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "GEOLOGICAL FORMATION: NOCTIS LABYRINTHUS CHASM"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "Subterranean pit crater entrance carved into the cube-sphere geometry with analytical lip displacement, physics-verified ray-check openings, and basaltic vertex shading."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 6: PLANETARY EXPLORATION & HABITAT RESTORATION
    # =========================================================================
    s6 = prs.slides.add_slide(blank_layout)
    set_slide_background(s6)
    add_header(s6, "Exploration & Habitat Engineering", "Salvaging Critical Life-Support Across Dangerous Terrain", 6)

    # Image 1: Space Cargo on Crevasse
    img6a_path = "tests/screenshots/space_cargo_crevasse_rim.png"
    if os.path.exists(img6a_path):
        add_card(s6, Inches(0.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s6.shapes.add_picture(img6a_path, Inches(0.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s6.shapes.add_textbox(Inches(1.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "SPACE CARGO: FILTER CORE SALVAGE"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "Perched on the perilous edge of a 30m rock crevasse. Players navigate extreme terrain to recover the Oxygen Filter Core and permanently restore life pod atmospheric scrubbing."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # Image 2: Rover Site Power Core
    img6b_path = "tests/screenshots/rover_site_power_core.png"
    if os.path.exists(img6b_path):
        add_card(s6, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s6.shapes.add_picture(img6b_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s6.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "ROVER SITE: POWER UNIT CORE SALVAGE"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = GOLD_ACCENT
        p = ctf.add_paragraph()
        p.text = "A derelict exploration rover tilted into the regolith surrounded by debris obstacles. Recovering its nuclear/solar power core boosts habitat solar generation efficiency by +50%."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 7: MAV ROCKET LIFTOFF & IMPACT
    # =========================================================================
    s7 = prs.slides.add_slide(blank_layout)
    set_slide_background(s7)
    add_header(s7, "Mission Climax & Global Impact", "Orbital Ascent, Educational Reach & Future Horizons", 7)

    # Left Column: Key Takeaways Cards
    add_card(s7, Inches(0.8), Inches(1.8), Inches(5.7), Inches(1.5))
    c1 = s7.shapes.add_textbox(Inches(1.0), Inches(1.95), Inches(5.3), Inches(1.2))
    ctf1 = c1.text_frame; ctf1.word_wrap = True; ctf1.margin_left = ctf1.margin_top = ctf1.margin_right = ctf1.margin_bottom = 0
    p = ctf1.paragraphs[0]
    p.text = "THE CLIMAX: MAV PRE-FLIGHT & ASCENT"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = GOLD_ACCENT
    p = ctf1.add_paragraph()
    p.text = "Launch is strictly gated behind repairing all 3 life systems. Players hold [E] for 3s to prime ignition, triggering exhaust plumes, engine rumble, and a 10s ascent into orbit."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    add_card(s7, Inches(0.8), Inches(3.5), Inches(5.7), Inches(1.5))
    c2 = s7.shapes.add_textbox(Inches(1.0), Inches(3.65), Inches(5.3), Inches(1.2))
    ctf2 = c2.text_frame; ctf2.word_wrap = True; ctf2.margin_left = ctf2.margin_top = ctf2.margin_right = ctf2.margin_bottom = 0
    p = ctf2.paragraphs[0]
    p.text = "EDUCATIONAL IMPACT & SCIENTIFIC LITERACY"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
    p = ctf2.add_paragraph()
    p.text = "Translates complex aerospace engineering and NASA open data into an engaging simulation, teaching players the delicate balance of planetary exploration and survival."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    add_card(s7, Inches(0.8), Inches(5.2), Inches(5.7), Inches(1.5))
    c3 = s7.shapes.add_textbox(Inches(1.0), Inches(5.35), Inches(5.3), Inches(1.2))
    ctf3 = c3.text_frame; ctf3.word_wrap = True; ctf3.margin_left = ctf3.margin_top = ctf3.margin_right = ctf3.margin_bottom = 0
    p = ctf3.paragraphs[0]
    p.text = "TECHNICAL EXCELLENCE: 100% VERIFIED"
    p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = ORANGE_ACCENT
    p = ctf3.add_paragraph()
    p.text = "30/30 automated unit tests passing. Solid 60 FPS performance (<0.5ms physics budget), fully non-destructive terrain integration, and modular GDScript architecture."
    p.font.size = Pt(10.5); p.font.color.rgb = TEXT_MUTED

    # Right Image: Rocket Chase Burn Ascent
    img7_path = "tests/cutscene_09s_chase_burn.png"
    if os.path.exists(img7_path):
        add_card(s7, Inches(6.8), Inches(1.8), Inches(5.7), Inches(4.9), CARD_BG, CARD_BORDER)
        s7.shapes.add_picture(img7_path, Inches(6.88), Inches(1.88), Inches(5.54), Inches(3.11))
        
        c = s7.shapes.add_textbox(Inches(7.0), Inches(5.15), Inches(5.3), Inches(1.4))
        ctf = c.text_frame
        ctf.word_wrap = True
        ctf.margin_left = ctf.margin_top = ctf.margin_right = ctf.margin_bottom = 0
        p = ctf.paragraphs[0]
        p.text = "THE ASCENT: RETURNING TO ORBIT"
        p.font.size = Pt(11); p.font.bold = True; p.font.color.rgb = CYAN_ACCENT
        p = ctf.add_paragraph()
        p.text = "The camera follows the MAV climbing above the red regolith before pulling back to frame the entire planet against the starry sky, culminating in 'Mission complete'."
        p.font.size = Pt(10); p.font.color.rgb = TEXT_MUTED

    out_path = "Ares_Sol_NASA_Space_Apps_Presentation.pptx"
    prs.save(out_path)
    print(f"Presentation saved successfully to {os.path.abspath(out_path)}")

if __name__ == "__main__":
    create_deck()
