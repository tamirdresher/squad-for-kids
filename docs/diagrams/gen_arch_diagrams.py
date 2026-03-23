"""
Generate professional architecture diagrams for Squad on AKS.
Creates SVG files that look like Azure documentation diagrams.
"""
import os

OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# Color palette (Azure-inspired)
# ============================================================
C = {
    "bg": "#FFFFFF",
    "azure_blue": "#0078D4",
    "azure_dark": "#002050",
    "azure_light": "#E8F4FD",
    "k8s_blue": "#326CE5",
    "k8s_light": "#E8EEFB",
    "github_dark": "#24292F",
    "github_gray": "#F6F8FA",
    "green": "#107C10",
    "green_light": "#E6F5E6",
    "purple": "#8B5CF6",
    "purple_light": "#F3EEFF",
    "orange": "#D83B01",
    "orange_light": "#FFF4EC",
    "red": "#D13438",
    "gray": "#605E5C",
    "gray_light": "#F3F2F1",
    "text": "#1B1A19",
    "text_light": "#605E5C",
    "line": "#B3B0AD",
    "arrow": "#605E5C",
}

def svg_header(w, h, title):
    safe_title = title.replace("&", "&amp;")
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
<title>{safe_title}</title>
<defs>
  <marker id="arrowhead" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="{C['arrow']}"/>
  </marker>
  <marker id="arrowblue" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="{C['azure_blue']}"/>
  </marker>
  <marker id="arrowgreen" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="{C['green']}"/>
  </marker>
  <marker id="arrowpurple" markerWidth="10" markerHeight="7" refX="10" refY="3.5" orient="auto">
    <polygon points="0 0, 10 3.5, 0 7" fill="{C['purple']}"/>
  </marker>
  <filter id="shadow" x="-4%" y="-4%" width="108%" height="108%">
    <feDropShadow dx="1" dy="2" stdDeviation="3" flood-opacity="0.1"/>
  </filter>
  <style>
    text {{ font-family: 'Segoe UI', -apple-system, sans-serif; }}
  </style>
</defs>
<rect width="{w}" height="{h}" fill="{C['bg']}"/>
'''

def svg_footer():
    return '</svg>\n'

def esc(text):
    """Escape XML entities in text."""
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("'", "&apos;")

def box(x, y, w, h, fill, stroke, label, sublabel="", icon="", rx=8, font_size=13, stroke_width=1.5):
    """Rounded rectangle with label."""
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{stroke_width}" filter="url(#shadow)"/>\n'
    ty = y + h/2 + 5 if not sublabel else y + h/2 - 2
    if icon:
        s += f'<text x="{x + 12}" y="{ty}" font-size="16" fill="{stroke}">{icon}</text>\n'
        s += f'<text x="{x + 32}" y="{ty}" font-size="{font_size}" font-weight="600" fill="{C["text"]}">{esc(label)}</text>\n'
    else:
        s += f'<text x="{x + w/2}" y="{ty}" font-size="{font_size}" font-weight="600" fill="{C["text"]}" text-anchor="middle">{esc(label)}</text>\n'
    if sublabel:
        s += f'<text x="{x + w/2}" y="{ty + 18}" font-size="11" fill="{C["text_light"]}" text-anchor="middle">{esc(sublabel)}</text>\n'
    return s

def section_box(x, y, w, h, fill, stroke, label, stroke_dash=""):
    """Section container with label at top."""
    dash = f' stroke-dasharray="{stroke_dash}"' if stroke_dash else ''
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{stroke}" stroke-width="2"{dash}/>\n'
    s += f'<text x="{x + 16}" y="{y + 22}" font-size="12" font-weight="700" fill="{stroke}" letter-spacing="0.5">{esc(label)}</text>\n'
    return s

def arrow(x1, y1, x2, y2, label="", color=None, dash=False):
    """Arrow with optional label."""
    c = color or C['arrow']
    marker = "arrowhead"
    if c == C['azure_blue']: marker = "arrowblue"
    elif c == C['green']: marker = "arrowgreen"
    elif c == C['purple']: marker = "arrowpurple"
    d = ' stroke-dasharray="6,4"' if dash else ''
    s = f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="1.5"{d} marker-end="url(#{marker})"/>\n'
    if label:
        mx, my = (x1+x2)/2, (y1+y2)/2
        s += f'<rect x="{mx - len(label)*3.5 - 4}" y="{my - 9}" width="{len(label)*7 + 8}" height="16" rx="3" fill="{C["bg"]}" opacity="0.9"/>\n'
        s += f'<text x="{mx}" y="{my + 3}" font-size="10" fill="{c}" text-anchor="middle" font-style="italic">{esc(label)}</text>\n'
    return s

def arrow_path(path_d, label="", color=None, dash=False, lx=0, ly=0):
    """Arrow along SVG path."""
    c = color or C['arrow']
    marker = "arrowhead"
    if c == C['azure_blue']: marker = "arrowblue"
    elif c == C['green']: marker = "arrowgreen"
    elif c == C['purple']: marker = "arrowpurple"
    d = ' stroke-dasharray="6,4"' if dash else ''
    s = f'<path d="{path_d}" fill="none" stroke="{c}" stroke-width="1.5"{d} marker-end="url(#{marker})"/>\n'
    if label and lx and ly:
        s += f'<rect x="{lx - len(label)*3.3 - 4}" y="{ly - 8}" width="{len(label)*6.6 + 8}" height="15" rx="3" fill="{C["bg"]}" opacity="0.92"/>\n'
        s += f'<text x="{lx}" y="{ly + 4}" font-size="9.5" fill="{c}" text-anchor="middle" font-style="italic">{esc(label)}</text>\n'
    return s

def badge(x, y, text, bg, fg):
    w = len(text) * 7 + 16
    s = f'<rect x="{x}" y="{y}" width="{w}" height="20" rx="10" fill="{bg}"/>\n'
    s += f'<text x="{x + w/2}" y="{y + 14}" font-size="10" font-weight="600" fill="{fg}" text-anchor="middle">{esc(text)}</text>\n'
    return s

# ============================================================
# DIAGRAM 1A: High-Level Architecture Overview (clean 3-layer)
# ============================================================
def diagram_overview():
    """Clean high-level view — 3 layers, minimal arrows, no clutter."""
    W, H = 1100, 620
    svg = svg_header(W, H, "Squad AI Framework — Architecture Overview")

    # Title
    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">Squad AI Agent Framework on AKS</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">Architecture Overview</text>\n'

    # ── Layer 1: External Systems ──
    svg += section_box(40, 80, W-80, 100, C["github_gray"], C["github_dark"], "EXTERNAL SYSTEMS")
    ext = [
        ("GitHub", "Issues · PRs · Webhooks", "📋", C["github_dark"], 70),
        ("Copilot API", "Coding agent requests", "🤖", C["orange"], 320),
        ("Microsoft Teams", "Notifications · Updates", "💬", C["azure_blue"], 570),
        ("Azure DevOps", "Pipelines · Boards", "🔧", C["azure_blue"], 820),
    ]
    for name, sub, icon, color, x in ext:
        svg += box(x, 108, 210, 55, "#FFF", color, name, sub, icon)

    # ── Layer 2: AKS Cluster ──
    svg += section_box(40, 210, W-80, 220, C["k8s_light"], C["k8s_blue"], "AKS CLUSTER  ⎈  Kubernetes 1.33")

    # Left side: scheduling
    svg += f'<rect x="70" y="245" width="300" height="170" rx="8" fill="#FFF" stroke="{C["k8s_blue"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<text x="220" y="268" font-size="12" font-weight="700" fill="{C["k8s_blue"]}" text-anchor="middle">Scheduling &amp; Scaling</text>\n'
    svg += box(85, 280, 130, 45, C["k8s_light"], C["k8s_blue"], "KEDA", "Custom scaler")
    svg += box(225, 280, 130, 45, C["k8s_light"], C["k8s_blue"], "CronJobs", "*/15 min cycles")
    svg += box(85, 340, 270, 40, C["green_light"], C["green"], "Rate Governor", "Traffic light · Token pool · Circuit breaker")

    # Right side: agent pods
    svg += f'<rect x="400" y="245" width="620" height="170" rx="8" fill="#FFF" stroke="{C["purple"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<text x="710" y="268" font-size="12" font-weight="700" fill="{C["purple"]}" text-anchor="middle">Agent Pods (squad namespace)</text>\n'

    pods = [
        ("Ralph", "Work Monitor", "🔄", C["orange"], 420),
        ("Picard", "Lead / Orchestrator", "🎖️", C["azure_blue"], 560),
        ("Specialists", "Data · Seven · Worf", "💻", C["green"], 700),
        ("B&apos;Elanna", "Infrastructure", "🔧", "#B8860B", 840),
    ]
    for name, sub, icon, color, x in pods:
        svg += f'<rect x="{x}" y="280" width="125" height="60" rx="6" fill="#FFF" stroke="{color}" stroke-width="1.5" filter="url(#shadow)"/>\n'
        svg += f'<text x="{x+62}" y="300" font-size="12" font-weight="600" fill="{C["text"]}" text-anchor="middle">{icon} {name}</text>\n'
        svg += f'<text x="{x+62}" y="316" font-size="10" fill="{C["text_light"]}" text-anchor="middle">{sub}</text>\n'

    # Workload Identity bar
    svg += f'<rect x="420" y="355" width="580" height="28" rx="5" fill="{C["azure_light"]}" stroke="{C["azure_blue"]}" stroke-width="1" stroke-dasharray="4,3"/>\n'
    svg += f'<text x="710" y="374" font-size="10" font-weight="600" fill="{C["azure_blue"]}" text-anchor="middle">🔐 Workload Identity — Zero credentials in pods</text>\n'

    # Arrows: scheduling → pods
    svg += arrow(370, 300, 400, 300, "", C["k8s_blue"])

    # ── Layer 3: Azure Infrastructure ──
    svg += section_box(40, 460, W-80, 95, C["azure_light"], C["azure_blue"], "AZURE INFRASTRUCTURE")
    infra = [
        ("Managed Identity", "🪪", 70),
        ("Key Vault", "🔑", 255),
        ("Container Registry", "📦", 440),
        ("Persistent Volume", "💾", 625),
        ("Log Analytics", "📈", 810),
    ]
    for name, icon, x in infra:
        svg += box(x, 488, 165, 48, "#FFF", C["azure_blue"], f"{icon} {name}", "")

    # Clean vertical arrows between layers (no labels, no crossing)
    svg += arrow(175, 163, 175, 210, "", C["github_dark"])
    svg += arrow(425, 163, 500, 245, "", C["github_dark"])
    svg += arrow(675, 163, 710, 245, "", C["azure_blue"])
    svg += arrow(300, 415, 300, 460, "", C["azure_blue"], dash=True)
    svg += arrow(710, 415, 710, 460, "", C["azure_blue"], dash=True)

    # Legend
    svg += f'<rect x="40" y="{H-50}" width="{W-80}" height="38" rx="6" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="0.5"/>\n'
    items = [("Solid line", "Data / control flow"), ("Dashed line", "Auth / secrets"),
             ("🟠", "Scheduled (CronJob)"), ("🔵", "Scaled (KEDA)"), ("🟣", "On-demand agents")]
    for i, (k, v) in enumerate(items):
        svg += f'<text x="{70 + i*200}" y="{H-27}" font-size="10" fill="{C["text"]}"><tspan font-weight="600">{k}:</tspan> {v}</text>\n'

    svg += svg_footer()
    return svg


# ============================================================
# DIAGRAM 1B: Agent Pods — Detailed View
# ============================================================
def diagram_agent_pods():
    """Detailed view of what runs inside the AKS cluster."""
    W, H = 1100, 560
    svg = svg_header(W, H, "Squad Agent Pods — Detailed View")

    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">Agent Pods — Inside the AKS Cluster</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">squad namespace · Kubernetes 1.33 · Workload Identity</text>\n'

    # ── Ralph (left, large) ──
    rx, ry, rw, rh = 40, 80, 240, 220
    svg += f'<rect x="{rx}" y="{ry}" width="{rw}" height="{rh}" rx="10" fill="#FFF" stroke="{C["orange"]}" stroke-width="2.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="{rx}" y="{ry}" width="{rw}" height="32" rx="10" fill="{C["orange"]}"/>\n'
    svg += f'<rect x="{rx}" y="{ry+20}" width="{rw}" height="12" fill="{C["orange"]}"/>\n'
    svg += f'<text x="{rx+rw/2}" y="{ry+22}" font-size="14" font-weight="700" fill="#FFF" text-anchor="middle">🔄 Ralph · CronJob</text>\n'
    details = [
        "Schedule: */15 * * * *",
        "Duration: ~4 min per cycle",
        "concurrencyPolicy: Forbid",
        "Image: squad-ralph:v10",
        "Polls issues → triages → spawns",
    ]
    for i, d in enumerate(details):
        svg += f'<text x="{rx+18}" y="{ry+55+i*20}" font-size="11" fill="{C["text"]}">{esc(d)}</text>\n'
    svg += badge(rx+18, ry+rh-35, "Work Monitor", C["orange_light"], C["orange"])
    svg += badge(rx+135, ry+rh-35, "24/7", C["green_light"], C["green"])

    # ── Picard (center, large) ──
    px, py, pw, ph = 310, 80, 240, 220
    svg += f'<rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="10" fill="#FFF" stroke="{C["azure_blue"]}" stroke-width="2.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="{px}" y="{py}" width="{pw}" height="32" rx="10" fill="{C["azure_blue"]}"/>\n'
    svg += f'<rect x="{px}" y="{py+20}" width="{pw}" height="12" fill="{C["azure_blue"]}"/>\n'
    svg += f'<text x="{px+pw/2}" y="{py+22}" font-size="14" font-weight="700" fill="#FFF" text-anchor="middle">🎖️ Picard · Deployment</text>\n'
    details = [
        "Replicas: 0–5 (KEDA scaled)",
        "Role: Lead / Orchestrator",
        "Decomposes complex tasks",
        "Delegates to specialists",
        "Reviews agent output",
    ]
    for i, d in enumerate(details):
        svg += f'<text x="{px+18}" y="{py+55+i*20}" font-size="11" fill="{C["text"]}">{esc(d)}</text>\n'
    svg += badge(px+18, py+ph-35, "Orchestrator", C["azure_light"], C["azure_blue"])
    svg += badge(px+130, py+ph-35, "KEDA", C["k8s_light"], C["k8s_blue"])

    # ── Specialist Agents (right side, stacked) ──
    svg += f'<rect x="580" y="80" width="480" height="220" rx="10" fill="{C["purple_light"]}" stroke="{C["purple"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="820" y="103" font-size="13" font-weight="700" fill="{C["purple"]}" text-anchor="middle">Specialist Agents · ScaledJob / On-demand</text>\n'

    agents = [
        ("Data", "Code · C# · Go · .NET · Clean code", "💻", C["green"]),
        ("Seven", "Research · Docs · Analysis · Presentations", "🔬", C["purple"]),
        ("B&apos;Elanna", "Infrastructure · K8s · Helm · ArgoCD", "🔧", "#B8860B"),
        ("Worf", "Security · Azure · Networking · Compliance", "🛡️", C["red"]),
        ("Troi", "Blog writing · Voice matching · Storytelling", "✍️", "#E91E63"),
    ]
    for i, (name, desc, icon, color) in enumerate(agents):
        ay = 115 + i * 35
        svg += f'<rect x="600" y="{ay}" width="440" height="30" rx="6" fill="#FFF" stroke="{color}" stroke-width="1.2"/>\n'
        svg += f'<text x="620" y="{ay+20}" font-size="12" font-weight="600" fill="{color}">{icon} {name}</text>\n'
        svg += f'<text x="720" y="{ay+20}" font-size="11" fill="{C["text_light"]}">{desc}</text>\n'

    # ── Flow arrows ──
    # Ralph → Picard (triggers)
    svg += arrow(280, 190, 310, 190, "triggers", C["orange"])
    # Picard → Specialists
    svg += arrow(550, 190, 580, 190, "delegates", C["purple"])

    # ── Second Squad namespace ──
    svg += section_box(40, 330, W-80, 100, C["orange_light"], C["orange"], "SECOND SQUAD  ⎈  squad-bot namespace · EMU Bot Account")
    svg += box(70, 360, 220, 52, "#FFF", C["orange"], "Heartbeat CronJob", "*/30 · Auth health check", "💓")
    svg += box(320, 360, 220, 52, "#FFF", C["orange"], "Vuln Sync CronJob", "*/6h · Security mirrors", "🔍")
    svg += box(570, 360, 220, 52, "#FFF", C["orange"], "Bot Workload Identity", "Separate managed identity", "🪪")
    svg += badge(820, 365, "Awaiting Copilot Seat", C["orange_light"], C["orange"])

    # ── Scribe + Ralph support ──
    svg += section_box(40, 455, W-80, 55, C["gray_light"], C["gray"], "SUPPORT AGENTS (run inside Squad coordinator context)")
    svg += f'<text x="60" y="490" font-size="11" fill="{C["text"]}">📋 Scribe — Session logging · Decisions · Cross-agent memory</text>\n'
    svg += f'<text x="500" y="490" font-size="11" fill="{C["text"]}">🔄 Ralph — Backlog monitor · Keep-alive · Issue triage</text>\n'

    # Legend
    svg += f'<rect x="40" y="{H-42}" width="{W-80}" height="32" rx="6" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="0.5"/>\n'
    items = [("🟠 CronJob", "Scheduled pods"), ("🔵 Deployment", "KEDA-scaled"),
             ("🟣 ScaledJob", "On-demand per issue"), ("🟤 Bot NS", "Separate identity")]
    for i, (k, v) in enumerate(items):
        svg += f'<text x="{70 + i*260}" y="{H-22}" font-size="10" fill="{C["text"]}"><tspan font-weight="600">{k}:</tspan> {v}</text>\n'

    svg += svg_footer()
    return svg


# ============================================================
# DIAGRAM 1C: Identity & Data Flow
# ============================================================
def diagram_identity_flow():
    """How authentication, secrets, and data connections work."""
    W, H = 1100, 580
    svg = svg_header(W, H, "Identity & Data Flow")

    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">Identity &amp; Data Flow</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">Workload Identity · Key Vault · Federated Credentials — Zero secrets in pods</text>\n'

    # ── Left column: Azure Identity ──
    svg += f'<rect x="40" y="80" width="320" height="380" rx="12" fill="{C["azure_light"]}" stroke="{C["azure_blue"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="200" y="108" font-size="14" font-weight="700" fill="{C["azure_blue"]}" text-anchor="middle">Azure Identity Layer</text>\n'

    svg += box(60, 125, 280, 60, "#FFF", C["azure_blue"], "Managed Identity A", "squad-identity · Personal GitHub", "🪪")
    svg += box(60, 200, 280, 60, "#FFF", C["azure_blue"], "Managed Identity B", "bot-identity · EMU GitHub org", "🪪")
    svg += box(60, 280, 280, 60, "#FFF", C["azure_blue"], "Azure Key Vault", "GH_TOKEN · TEAMS_WEBHOOK · API keys", "🔑")
    svg += box(60, 360, 280, 60, "#FFF", C["azure_blue"], "Container Registry (ACR)", "squad-ralph · squad-picard images", "📦")

    # ── Center column: AKS Pods ──
    svg += f'<rect x="400" y="80" width="300" height="380" rx="12" fill="{C["k8s_light"]}" stroke="{C["k8s_blue"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="550" y="108" font-size="14" font-weight="700" fill="{C["k8s_blue"]}" text-anchor="middle">AKS Pods</text>\n'

    svg += f'<rect x="420" y="125" width="260" height="55" rx="8" fill="#FFF" stroke="{C["orange"]}" stroke-width="2" filter="url(#shadow)"/>\n'
    svg += f'<text x="550" y="150" font-size="13" font-weight="600" fill="{C["text"]}" text-anchor="middle">🔄 Ralph</text>\n'
    svg += f'<text x="550" y="168" font-size="10" fill="{C["text_light"]}" text-anchor="middle">SA: squad-workload-identity</text>\n'

    svg += f'<rect x="420" y="195" width="260" height="55" rx="8" fill="#FFF" stroke="{C["azure_blue"]}" stroke-width="2" filter="url(#shadow)"/>\n'
    svg += f'<text x="550" y="220" font-size="13" font-weight="600" fill="{C["text"]}" text-anchor="middle">🎖️ Picard + Specialists</text>\n'
    svg += f'<text x="550" y="238" font-size="10" fill="{C["text_light"]}" text-anchor="middle">SA: squad-workload-identity</text>\n'

    svg += f'<rect x="420" y="265" width="260" height="55" rx="8" fill="#FFF" stroke="{C["orange"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<text x="550" y="290" font-size="13" font-weight="600" fill="{C["text"]}" text-anchor="middle">💓 Bot Heartbeat</text>\n'
    svg += f'<text x="550" y="308" font-size="10" fill="{C["text_light"]}" text-anchor="middle">SA: bot-workload-identity</text>\n'

    # How it works box
    svg += f'<rect x="420" y="335" width="260" height="110" rx="8" fill="#FFF" stroke="{C["green"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="550" y="358" font-size="11" font-weight="700" fill="{C["green"]}" text-anchor="middle">How Workload Identity Works</text>\n'
    steps = ["1. Pod starts with ServiceAccount", "2. K8s projects OIDC token", "3. Token exchanged for Azure AD token", "4. AD token accesses Key Vault / ACR"]
    for i, s in enumerate(steps):
        svg += f'<text x="435" y="{377+i*17}" font-size="10" fill="{C["text"]}">{esc(s)}</text>\n'

    # ── Right column: External Services ──
    svg += f'<rect x="740" y="80" width="320" height="380" rx="12" fill="{C["github_gray"]}" stroke="{C["github_dark"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="900" y="108" font-size="14" font-weight="700" fill="{C["github_dark"]}" text-anchor="middle">External Services</text>\n'

    svg += box(760, 125, 280, 55, "#FFF", C["github_dark"], "GitHub (Personal)", "tamirdresher · Issues · PRs", "📋")
    svg += box(760, 195, 280, 55, "#FFF", C["github_dark"], "GitHub (EMU Org)", "Enterprise managed · Bot repos", "📋")
    svg += box(760, 265, 280, 55, "#FFF", C["azure_blue"], "Microsoft Teams", "Channel notifications · Updates", "💬")
    svg += box(760, 340, 280, 55, "#FFF", C["purple"], "Copilot Coding Agent", "Autonomous issue resolution", "🤖")

    # ── Arrows ──
    # Identity A → Pods (Ralph, Picard)
    svg += arrow(340, 155, 420, 150, "federates", C["azure_blue"])
    # Identity B → Bot pod
    svg += arrow(340, 230, 420, 290, "federates", C["azure_blue"])
    # Key Vault → Pods
    svg += arrow(340, 310, 420, 210, "secrets", C["azure_blue"], dash=True)
    # ACR → Pods
    svg += arrow(340, 390, 420, 240, "images", C["azure_blue"], dash=True)
    # Pods → GitHub personal
    svg += arrow(680, 150, 760, 150, "API calls", C["github_dark"])
    # Pods → GitHub EMU
    svg += arrow(680, 290, 760, 220, "API calls", C["github_dark"])
    # Pods → Teams
    svg += arrow(680, 225, 760, 290, "webhooks", C["azure_blue"])
    # Pods → Copilot
    svg += arrow(680, 200, 760, 367, "requests", C["purple"], dash=True)

    # Legend
    svg += f'<rect x="40" y="{H-50}" width="{W-80}" height="38" rx="6" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="0.5"/>\n'
    items = [("Solid arrow", "API / data flow"), ("Dashed arrow", "Auth federation / secrets"),
             ("🪪 Identity A", "Personal GitHub"), ("🪪 Identity B", "EMU Bot org")]
    for i, (k, v) in enumerate(items):
        svg += f'<text x="{70 + i*260}" y="{H-27}" font-size="10" fill="{C["text"]}"><tspan font-weight="600">{k}:</tspan> {v}</text>\n'

    svg += svg_footer()
    return svg


# ============================================================
# DIAGRAM 2: Ralph Issue Processing Flow
# ============================================================
def diagram_ralph_flow():
    W, H = 1200, 650
    svg = svg_header(W, H, "Ralph — Issue Processing Flow")
    
    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">Ralph — Issue Processing Flow</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">CronJob fires every 15 minutes · concurrencyPolicy: Forbid · ~4 min per cycle</text>\n'

    # Step boxes - horizontal flow
    steps = [
        ("1", "CronJob\nTriggers", "⏰", "K8s scheduler fires\n*/15 * * * *", C["k8s_blue"], C["k8s_light"]),
        ("2", "Pod\nStarts", "🐳", "Image: squad-ralph:v10\nWorkload Identity auth", C["azure_blue"], C["azure_light"]),
        ("3", "Check\nRate Limits", "🚦", "Core: 5000/hr\nGraphQL: 5000/hr", C["orange"], C["orange_light"]),
        ("4", "Poll GitHub\nIssues", "📋", "Filter: squad:* labels\nSort by priority", C["github_dark"], C["github_gray"]),
        ("5", "Triage &\nRoute", "🔀", "Match work type\nto agent charter", C["purple"], C["purple_light"]),
        ("6", "Spawn\nAgents", "🚀", "Copilot coding agent\nper actionable issue", C["green"], C["green_light"]),
    ]
    
    sx = 40
    for i, (num, title, icon, desc, color, bg) in enumerate(steps):
        x = sx + i * 190
        y = 90
        # Main box
        svg += f'<rect x="{x}" y="{y}" width="170" height="140" rx="10" fill="{bg}" stroke="{color}" stroke-width="2" filter="url(#shadow)"/>\n'
        # Number circle
        svg += f'<circle cx="{x+25}" cy="{y+25}" r="14" fill="{color}"/>\n'
        svg += f'<text x="{x+25}" y="{y+30}" font-size="13" font-weight="700" fill="#FFF" text-anchor="middle">{num}</text>\n'
        # Icon + Title
        svg += f'<text x="{x+50}" y="{y+20}" font-size="18">{icon}</text>\n'
        lines = title.split('\n')
        for j, line in enumerate(lines):
            svg += f'<text x="{x+85}" y="{y+56+j*16}" font-size="13" font-weight="700" fill="{C["text"]}" text-anchor="middle">{line}</text>\n'
        # Description
        dlines = desc.split('\n')
        for j, line in enumerate(dlines):
            svg += f'<text x="{x+85}" y="{y+100+j*15}" font-size="10" fill="{C["text_light"]}" text-anchor="middle">{line}</text>\n'
        # Arrow to next
        if i < len(steps) - 1:
            svg += arrow(x + 170, y + 70, x + 190, y + 70, "", color)

    # Decision diamond after step 3
    dy = 280
    svg += f'<polygon points="600,{dy} 680,{dy+50} 600,{dy+100} 520,{dy+50}" fill="{C["orange_light"]}" stroke="{C["orange"]}" stroke-width="2"/>\n'
    svg += f'<text x="600" y="{dy+46}" font-size="11" font-weight="600" fill="{C["text"]}" text-anchor="middle">Rate Limit</text>\n'
    svg += f'<text x="600" y="{dy+60}" font-size="11" font-weight="600" fill="{C["text"]}" text-anchor="middle">OK?</text>\n'

    # Green path
    svg += arrow(680, dy+50, 800, dy+50, "✅ Green: proceed", C["green"])
    svg += box(800, dy+20, 180, 60, C["green_light"], C["green"], "Process Issues", "Full speed", "▶️")
    
    # Red path
    svg += arrow(600, dy+100, 600, dy+140, "🔴 Red: backoff", C["red"])
    svg += box(520, dy+140, 160, 50, C["orange_light"], C["red"], "Exponential Backoff", "Skip this cycle")

    # Amber path
    svg += arrow(520, dy+50, 350, dy+50, "🟡 Amber: throttle", C["orange"])
    svg += box(180, dy+20, 170, 60, C["orange_light"], C["orange"], "Throttled Mode", "1 req/sec, critical only")

    # Bottom: Output section
    oy = 470
    svg += f'<rect x="40" y="{oy}" width="{W-80}" height="150" rx="10" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="1"/>\n'
    svg += f'<text x="60" y="{oy+22}" font-size="12" font-weight="700" fill="{C["text"]}" letter-spacing="0.5">RALPH OUTPUTS PER CYCLE</text>\n'

    outputs = [
        ("Issues Triaged", "Labels applied\nPriority set", "🏷️", C["purple"]),
        ("Agents Spawned", "Copilot coding agent\nper actionable issue", "🤖", C["azure_blue"]),
        ("PRs Created", "By spawned agents\nLinked to issues", "📝", C["green"]),
        ("State Updated", "ralph-heartbeat.json\nPersistent Volume", "💾", C["orange"]),
        ("Metrics Emitted", "Duration, items processed\nError count, rate limit %", "📊", C["k8s_blue"]),
    ]
    for i, (title, desc, icon, color) in enumerate(outputs):
        ox = 60 + i * 220
        svg += box(ox, oy+35, 200, 95, "#FFF", color, f"{icon} {title}", desc.split('\n')[0], rx=6)
        if len(desc.split('\n')) > 1:
            svg += f'<text x="{ox+100}" y="{oy+110}" font-size="10" fill="{C["text_light"]}" text-anchor="middle">{desc.split(chr(10))[1]}</text>\n'

    svg += svg_footer()
    return svg


# ============================================================
# DIAGRAM 3: KEDA Composite Scaling
# ============================================================
def diagram_keda_scaling():
    W, H = 1200, 700
    svg = svg_header(W, H, "KEDA Composite Scaling — Rate-Limit-Aware Autoscaling")
    
    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">KEDA Composite Scaling</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">Rate-Limit-Aware Agent Autoscaling · keda-copilot-scaler v0.1.0 · Open Source</text>\n'

    # Data sources (left)
    svg += section_box(30, 80, 280, 280, C["github_gray"], C["github_dark"], "DATA SOURCES")
    svg += box(50, 115, 240, 65, "#FFF", C["github_dark"], "📋 Issue Queue API", "Open issues with squad:copilot")
    svg += box(50, 195, 240, 65, "#FFF", C["orange"], "⚡ Rate Limit API", "Remaining / 5000 per hour")
    svg += box(50, 275, 240, 65, "#FFF", C["red"], "🚫 429 Error Monitor", "Copilot API error rate")

    # Scaler (center)
    svg += section_box(360, 80, 310, 280, C["k8s_light"], C["k8s_blue"], "KEDA COPILOT SCALER  ·  gRPC")
    svg += f'<rect x="380" y="115" width="270" height="50" rx="6" fill="#FFF" stroke="{C["k8s_blue"]}" stroke-width="1.5"/>\n'
    svg += f'<text x="515" y="135" font-size="11" font-weight="600" fill="{C["text"]}" text-anchor="middle">Composite Metric Logic (Go)</text>\n'
    svg += f'<text x="515" y="150" font-size="10" fill="{C["text_light"]}" text-anchor="middle">Polls every 30 seconds</text>\n'

    # Decision logic
    svg += f'<rect x="385" y="180" width="260" height="80" rx="6" fill="{C["green_light"]}" stroke="{C["green"]}" stroke-width="1"/>\n'
    svg += f'<text x="515" y="200" font-size="11" font-weight="700" fill="{C["green"]}" text-anchor="middle">IF rate_limit &gt; threshold</text>\n'
    svg += f'<text x="515" y="216" font-size="11" font-weight="700" fill="{C["green"]}" text-anchor="middle">AND no 429 errors</text>\n'
    svg += f'<text x="515" y="240" font-size="12" font-weight="700" fill="{C["text"]}" text-anchor="middle">metric = issue_count</text>\n'

    svg += f'<rect x="385" y="270" width="260" height="55" rx="6" fill="{C["orange_light"]}" stroke="{C["red"]}" stroke-width="1"/>\n'
    svg += f'<text x="515" y="290" font-size="11" font-weight="700" fill="{C["red"]}" text-anchor="middle">ELSE (rate exhausted or 429s)</text>\n'
    svg += f'<text x="515" y="310" font-size="12" font-weight="700" fill="{C["text"]}" text-anchor="middle">metric = 0  →  scale down</text>\n'

    # KEDA Controller (right-center)
    svg += section_box(720, 80, 210, 280, C["k8s_light"], C["k8s_blue"], "KEDA CONTROLLER")
    svg += box(740, 115, 170, 60, "#FFF", C["k8s_blue"], "ScaledObject", "pollingInterval: 30s")
    svg += box(740, 190, 170, 50, "#FFF", C["k8s_blue"], "min: 0 · max: 5", "cooldown: 300s")
    svg += box(740, 255, 170, 50, "#FFF", C["k8s_blue"], "targetSize: 5", "1 replica per 5 issues")

    # Picard deployment (far right)
    svg += section_box(980, 80, 190, 280, C["purple_light"], C["purple"], "PICARD DEPLOYMENT")
    pods_y = [115, 170, 225, 280]
    labels = ["Pod 1", "Pod 2", "Pod 3", "Pod 4–5"]
    for i, (py, pl) in enumerate(zip(pods_y, labels)):
        opacity = "1" if i < 3 else "0.4"
        svg += f'<rect x="1000" y="{py}" width="150" height="42" rx="6" fill="#FFF" stroke="{C["purple"]}" stroke-width="1.5" opacity="{opacity}" filter="url(#shadow)"/>\n'
        svg += f'<text x="1075" y="{py+27}" font-size="11" font-weight="600" fill="{C["text"]}" text-anchor="middle" opacity="{opacity}">🎖️ {pl}</text>\n'

    # Arrows between sections
    svg += arrow(290, 147, 360, 147, "issue count", C["github_dark"])
    svg += arrow(290, 227, 360, 225, "remaining %", C["orange"])
    svg += arrow(290, 307, 360, 295, "error rate", C["red"])
    svg += arrow(670, 200, 720, 145, "composite metric", C["k8s_blue"])
    svg += arrow(930, 200, 980, 200, "replicas", C["purple"])

    # Timeline scenario (bottom)
    svg += f'<rect x="30" y="400" width="{W-60}" height="270" rx="12" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="1"/>\n'
    svg += f'<text x="60" y="425" font-size="14" font-weight="700" fill="{C["text"]}">Scaling Scenario Timeline</text>\n'

    # Timeline
    tl_y = 480
    svg += f'<line x1="80" y1="{tl_y}" x2="1140" y2="{tl_y}" stroke="{C["line"]}" stroke-width="2"/>\n'
    
    events = [
        (120, "T0: 8 issues arrive", "Rate limit: 85%", "Scale → 2 pods", C["green"], 2),
        (370, "T1: Rate drops to 8%", "429 errors detected", "Scale → 0 (backoff)", C["red"], 0),
        (620, "T2: Rate limit resets", "429s cleared", "Scale → 2 pods", C["green"], 2),
        (870, "T3: Issues resolved", "Queue empty", "Scale → 0 (idle)", C["k8s_blue"], 0),
    ]
    
    for ex, title, detail, action, color, pods in events:
        svg += f'<circle cx="{ex}" cy="{tl_y}" r="8" fill="{color}" stroke="#FFF" stroke-width="2"/>\n'
        svg += f'<text x="{ex}" y="{tl_y - 20}" font-size="11" font-weight="700" fill="{C["text"]}" text-anchor="middle">{title}</text>\n'
        svg += f'<text x="{ex}" y="{tl_y - 6}" font-size="9" fill="{C["text_light"]}" text-anchor="middle">{detail}</text>\n'
        
        # Action box below
        svg += f'<rect x="{ex-75}" y="{tl_y+20}" width="150" height="40" rx="6" fill="#FFF" stroke="{color}" stroke-width="1.5"/>\n'
        svg += f'<text x="{ex}" y="{tl_y+38}" font-size="10" font-weight="600" fill="{color}" text-anchor="middle">{action}</text>\n'
        # Pod indicators
        for p in range(5):
            pc = color if p < pods else C["line"]
            svg += f'<circle cx="{ex - 20 + p*10}" cy="{tl_y+55}" r="3" fill="{pc}"/>\n'

    # Pod count label
    svg += f'<text x="80" y="{tl_y+58}" font-size="9" fill="{C["text_light"]}">Pods:</text>\n'

    # Result callout
    svg += f'<rect x="80" y="590" width="1060" height="50" rx="8" fill="{C["azure_light"]}" stroke="{C["azure_blue"]}" stroke-width="1"/>\n'
    svg += f'<text x="{W/2}" y="612" font-size="12" font-weight="600" fill="{C["azure_blue"]}" text-anchor="middle">💡 Result: Agents scale with demand AND respect API limits. No wasted compute. No hammering depleted APIs. Self-defense, not just autoscaling.</text>\n'
    svg += f'<text x="{W/2}" y="630" font-size="10" fill="{C["text_light"]}" text-anchor="middle">Open source: github.com/tamirdresher/keda-copilot-scaler · MIT License · 51 tests · CI green</text>\n'

    svg += svg_footer()
    return svg


# ============================================================
# DIAGRAM 4: Multi-Squad Namespace Architecture  
# ============================================================
def diagram_multi_squad():
    W, H = 1200, 850
    svg = svg_header(W, H, "Multi-Squad AKS Architecture — Namespace Isolation")

    svg += f'<text x="{W/2}" y="36" font-size="22" font-weight="700" fill="{C["azure_dark"]}" text-anchor="middle">Multi-Squad AKS Architecture</text>\n'
    svg += f'<text x="{W/2}" y="56" font-size="13" fill="{C["text_light"]}" text-anchor="middle">Namespace Isolation · Workload Identity per Squad · Shared Infrastructure</text>\n'

    # AKS cluster boundary
    svg += f'<rect x="30" y="70" width="{W-60}" height="510" rx="16" fill="#FAFBFF" stroke="{C["azure_blue"]}" stroke-width="2.5"/>\n'
    svg += f'<text x="50" y="95" font-size="14" font-weight="700" fill="{C["azure_blue"]}">☁️ AKS Cluster · Kubernetes 1.33 · Autoscaling Node Pools</text>\n'

    # Namespace 1: squad
    svg += section_box(50, 110, 540, 220, "#FFF", C["k8s_blue"], "⎈  NAMESPACE: squad")
    svg += f'<rect x="70" y="142" width="155" height="80" rx="6" fill="#FFF" stroke="{C["orange"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="70" y="142" width="155" height="22" rx="6" fill="{C["orange"]}"/><rect x="70" y="155" width="155" height="9" fill="{C["orange"]}"/>\n'
    svg += f'<text x="147" y="159" font-size="10" font-weight="700" fill="#FFF" text-anchor="middle">🔄 Ralph CronJob</text>\n'
    svg += f'<text x="82" y="182" font-size="9" fill="{C["text"]}">Schedule: */15 * * * *</text>\n'
    svg += f'<text x="82" y="194" font-size="9" fill="{C["text"]}">Image: v10 · ~4min/run</text>\n'
    svg += f'<text x="82" y="206" font-size="9" fill="{C["text"]}">concurrencyPolicy: Forbid</text>\n'

    svg += f'<rect x="240" y="142" width="155" height="80" rx="6" fill="#FFF" stroke="{C["azure_blue"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="240" y="142" width="155" height="22" rx="6" fill="{C["azure_blue"]}"/><rect x="240" y="155" width="155" height="9" fill="{C["azure_blue"]}"/>\n'
    svg += f'<text x="317" y="159" font-size="10" font-weight="700" fill="#FFF" text-anchor="middle">🎖️ Picard Deployment</text>\n'
    svg += f'<text x="252" y="182" font-size="9" fill="{C["text"]}">Replicas: 0–5 (KEDA)</text>\n'
    svg += f'<text x="252" y="194" font-size="9" fill="{C["text"]}">Lead / Orchestrator</text>\n'
    svg += f'<text x="252" y="206" font-size="9" fill="{C["text"]}">Spawns specialist agents</text>\n'

    svg += f'<rect x="410" y="142" width="160" height="80" rx="6" fill="#FFF" stroke="{C["green"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="410" y="142" width="160" height="22" rx="6" fill="{C["green"]}"/><rect x="410" y="155" width="160" height="9" fill="{C["green"]}"/>\n'
    svg += f'<text x="490" y="159" font-size="10" font-weight="700" fill="#FFF" text-anchor="middle">🤖 Agent Pods</text>\n'
    svg += f'<text x="422" y="182" font-size="9" fill="{C["text"]}">Data · Seven · B\'Elanna</text>\n'
    svg += f'<text x="422" y="194" font-size="9" fill="{C["text"]}">Worf · Neelix · Troi</text>\n'
    svg += f'<text x="422" y="206" font-size="9" fill="{C["text"]}">ScaledJob / On-demand</text>\n'

    # SA + PVC
    svg += f'<rect x="70" y="235" width="240" height="32" rx="5" fill="{C["azure_light"]}" stroke="{C["azure_blue"]}" stroke-width="1"/>\n'
    svg += f'<text x="190" y="256" font-size="9" font-weight="600" fill="{C["azure_blue"]}" text-anchor="middle">🪪 SA: squad-workload-identity → Identity A</text>\n'
    svg += f'<rect x="330" y="235" width="240" height="32" rx="5" fill="{C["gray_light"]}" stroke="{C["gray"]}" stroke-width="1"/>\n'
    svg += f'<text x="450" y="256" font-size="9" font-weight="600" fill="{C["gray"]}" text-anchor="middle">💾 PVC: squad-state · 1Gi managed-premium</text>\n'
    svg += f'<text x="300" y="310" font-size="9" font-weight="600" fill="{C["k8s_blue"]}" text-anchor="middle">Watches: Repository A (personal GitHub)</text>\n'

    # Namespace 2: squad-scaler
    svg += section_box(610, 110, 230, 220, "#FFF", "#0E7A6E", "⎈  NAMESPACE: squad-scaler")
    svg += box(630, 145, 190, 65, "#FFF", "#0E7A6E", "KEDA Copilot Scaler", "gRPC :6000 · Go", "📊")
    svg += badge(635, 215, "v0.1.0", C["green_light"], C["green"])
    svg += badge(710, 215, "51 tests", C["green_light"], C["green"])
    svg += f'<text x="725" y="260" font-size="9" fill="{C["text_light"]}" text-anchor="middle">Polls GitHub API /30s</text>\n'
    svg += f'<text x="725" y="275" font-size="9" fill="{C["text_light"]}" text-anchor="middle">Composite: issues × rate limit</text>\n'

    # Namespace 3: keda-system
    svg += section_box(860, 110, 280, 100, "#FFF", C["gray"], "⎈  NAMESPACE: keda-system")
    svg += box(880, 145, 120, 50, "#FFF", C["gray"], "Controller", "v2.19.0")
    svg += box(1010, 145, 120, 50, "#FFF", C["gray"], "Metrics API", "Aggregator")

    # Namespace 4: squad-bot
    svg += section_box(610, 350, 530, 220, "#FFF", C["orange"], "⎈  NAMESPACE: squad-bot  ·  EMU Bot Account")

    svg += f'<rect x="630" y="385" width="150" height="75" rx="6" fill="#FFF" stroke="{C["orange"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="630" y="385" width="150" height="22" rx="6" fill="{C["orange"]}"/><rect x="630" y="398" width="150" height="9" fill="{C["orange"]}"/>\n'
    svg += f'<text x="705" y="403" font-size="10" font-weight="700" fill="#FFF" text-anchor="middle">💓 Heartbeat</text>\n'
    svg += f'<text x="642" y="425" font-size="9" fill="{C["text"]}">CronJob: */30 * * * *</text>\n'
    svg += f'<text x="642" y="437" font-size="9" fill="{C["text"]}">Auth health check</text>\n'
    svg += f'<text x="642" y="449" font-size="9" fill="{C["text"]}">gh CLI v2.88.1</text>\n'

    svg += f'<rect x="800" y="385" width="150" height="75" rx="6" fill="#FFF" stroke="{C["orange"]}" stroke-width="1.5" filter="url(#shadow)"/>\n'
    svg += f'<rect x="800" y="385" width="150" height="22" rx="6" fill="{C["orange"]}"/><rect x="800" y="398" width="150" height="9" fill="{C["orange"]}"/>\n'
    svg += f'<text x="875" y="403" font-size="10" font-weight="700" fill="#FFF" text-anchor="middle">🔍 Vuln Sync</text>\n'
    svg += f'<text x="812" y="425" font-size="9" fill="{C["text"]}">CronJob: */6h</text>\n'
    svg += f'<text x="812" y="437" font-size="9" fill="{C["text"]}">Mirrors security issues</text>\n'
    svg += f'<text x="812" y="449" font-size="9" fill="{C["text"]}">to fork for PRs</text>\n'

    svg += f'<rect x="970" y="385" width="150" height="75" rx="6" fill="{C["orange_light"]}" stroke="{C["orange"]}" stroke-width="1.5" stroke-dasharray="5,3"/>\n'
    svg += f'<text x="1045" y="415" font-size="10" font-weight="600" fill="{C["orange"]}" text-anchor="middle">⏳ Copilot Agent</text>\n'
    svg += f'<text x="1045" y="435" font-size="9" fill="{C["text_light"]}" text-anchor="middle">Awaiting seat</text>\n'
    svg += f'<text x="1045" y="448" font-size="9" fill="{C["text_light"]}" text-anchor="middle">activation</text>\n'

    svg += f'<rect x="630" y="475" width="240" height="28" rx="5" fill="{C["azure_light"]}" stroke="{C["azure_blue"]}" stroke-width="1"/>\n'
    svg += f'<text x="750" y="494" font-size="9" font-weight="600" fill="{C["azure_blue"]}" text-anchor="middle">🪪 SA: bot-workload-identity → Identity B</text>\n'
    svg += f'<text x="750" y="540" font-size="9" font-weight="600" fill="{C["orange"]}" text-anchor="middle">Watches: Repository B (org EMU account)</text>\n'

    # Arrows inside cluster
    svg += arrow(840, 177, 860, 170, "", C["gray"])  # scaler → KEDA
    svg += arrow(880, 195, 725, 285, "metrics", "#0E7A6E")  # KEDA reads scaler
    svg += arrow(395, 177, 610, 177, "", C["k8s_blue"])  # picard → scaler connection (scaled)

    # ── External services (bottom) ──
    svg += f'<rect x="30" y="600" width="{W-60}" height="220" rx="12" fill="{C["gray_light"]}" stroke="{C["line"]}" stroke-width="1"/>\n'
    svg += f'<text x="50" y="625" font-size="14" font-weight="700" fill="{C["azure_dark"]}">External Services &amp; Identity Federation</text>\n'

    # Azure services
    svg += box(50, 645, 155, 75, "#FFF", C["azure_blue"], "☁️ Managed Identity A", "Squad personal account")
    svg += box(225, 645, 155, 75, "#FFF", C["azure_blue"], "☁️ Managed Identity B", "Bot EMU account")
    svg += box(400, 645, 155, 75, "#FFF", C["azure_blue"], "🔑 Azure Key Vault", "GH_TOKEN · API keys")
    svg += box(575, 645, 155, 75, "#FFF", C["azure_blue"], "📦 Container Registry", "ACR · Squad images")
    svg += box(750, 645, 155, 75, "#FFF", C["azure_blue"], "📈 Log Analytics", "Monitoring · Alerts")

    # GitHub + Teams
    svg += box(50, 740, 155, 55, "#FFF", C["github_dark"], "📋 GitHub (Personal)", "Issues · PRs · Repos")
    svg += box(225, 740, 155, 55, "#FFF", C["github_dark"], "📋 GitHub (EMU Org)", "Enterprise repos")
    svg += box(400, 740, 155, 55, "#FFF", C["azure_blue"], "💬 Microsoft Teams", "Notifications · Webhooks")
    svg += box(575, 740, 155, 55, "#FFF", C["purple"], "🤖 Copilot API", "Coding agent requests")

    # Identity federation arrows
    svg += arrow(127, 645, 190, 310, "federates", C["azure_blue"], dash=True)
    svg += arrow(302, 645, 750, 540, "federates", C["azure_blue"], dash=True)
    svg += arrow(477, 580, 477, 645, "secrets", C["azure_blue"], dash=True)
    svg += arrow(652, 580, 652, 645, "images", C["azure_blue"], dash=True)

    svg += svg_footer()
    return svg


# ============================================================
# Write all diagrams
# ============================================================
if __name__ == "__main__":
    diagrams = {
        "arch-1a-overview.svg": diagram_overview(),
        "arch-1b-agent-pods.svg": diagram_agent_pods(),
        "arch-1c-identity-flow.svg": diagram_identity_flow(),
        "arch-2-ralph-flow.svg": diagram_ralph_flow(),
        "arch-3-keda-scaling.svg": diagram_keda_scaling(),
        "arch-4-multi-squad.svg": diagram_multi_squad(),
    }
    
    for filename, content in diagrams.items():
        path = os.path.join(OUTPUT_DIR, filename)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ {filename} ({len(content):,} bytes)")
    
    print(f"\nAll {len(diagrams)} diagrams saved to {OUTPUT_DIR}")
