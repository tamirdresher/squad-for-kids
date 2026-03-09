# Image Generation & Graphics with Copilot CLI

**Capability:** Generate images and graphics using ONLY Copilot CLI, GitHub Models, and Microsoft-approved sources

**Status:** ⚠️ LIMITED — Mostly text-based graphics (Mermaid, SVG, ASCII). AI image generation requires external Azure OpenAI.

**Confidence:** Medium (research-based; constraints are framework limitations, not gaps)

---

## Executive Summary

**Can GitHub Models generate images directly?** ❌ **No.**

GitHub Copilot's models (GPT-4, Claude, Gemini) are text/code-focused. They have multimodal *input* (can read code, analyze screenshots) but **no** native *output* image generation.

**What IS possible:**
1. ✅ **Text-based graphics** (Mermaid, PlantUML, SVG, ASCII art) — works entirely through Copilot CLI
2. ✅ **AI image generation via Azure OpenAI** — Microsoft-owned DALL-E 3 accessible through Azure SDKs
3. ✅ **MCP servers** — Extend Copilot to render diagrams (Mermaid MCP, Azure Diagram MCP)

**Best approach:** Combine text-based diagram generation (free, Copilot-native) with optional Azure OpenAI for photorealistic images.

---

## What's Possible Today vs. Not Yet Available

### ✅ What Works Today

| Capability | How | Constraints |
|-----------|-----|-------------|
| **Mermaid diagrams** (flowchart, sequence, Gantt, class, state) | Copilot CLI generates `.mmd` code → render with `@mermaid-js/mermaid-cli` to SVG/PNG | Text-based only; limited styling |
| **SVG graphics** | Copilot generates SVG code → display/save as `.svg` | Must be text-based; no photorealistic images |
| **ASCII art diagrams** | Copilot generates code → use `beautiful-mermaid` (JS/npm) or `mermaid-ascii-diagrams` (Python) | Terminal-friendly; simple visuals |
| **PlantUML diagrams** | Copilot generates PlantUML syntax → use PlantUML CLI or online renderer | Requires PlantUML Java runtime or web service |
| **D2 diagrams** | Copilot generates D2 syntax → render with `d2` CLI | Open-source; Google-created; integrates with Copilot |
| **Architecture diagrams (text)** | Copilot + MCP server (e.g., `azure-diagram-mcp`) → generates Python Diagrams DSL → outputs PNG | Requires running MCP server; limited to infrastructure |

### ❌ What's NOT Available (Yet)

| Limitation | Why | Workaround |
|-----------|-----|-----------|
| **Photorealistic image generation** (DALL-E from Copilot CLI directly) | GitHub Models don't include image generation models; OpenAI APIs aren't baked into Copilot CLI | Use Azure OpenAI DALL-E 3 (Microsoft-owned) with Python/Node.js SDKs outside Copilot |
| **Stable Diffusion** (text-to-image) | Not in GitHub Models marketplace | Use Hugging Face APIs or Replicate (third-party; not Microsoft) |
| **GPT-4 Vision → image output** | Copilot's multimodal models process images as *input*, not *output* | Use Azure OpenAI's GPT-4 Vision with explicit image generation models |
| **One-step: prompt → image** | No single Copilot CLI command generates images | Requires orchestration (generate code → invoke external API → save image) |

---

## Recommended Approaches

### 1. **Text-Based Diagrams (Native to Copilot CLI)** ⭐ Recommended for Documentation

**Best for:** Architecture diagrams, flowcharts, sequence diagrams, ERDs, state machines, Gantt charts.

**Pros:**
- Zero dependencies; Copilot CLI can generate code
- Export to SVG (vector) or PNG
- Version-controllable (`.mmd`, `.puml`, `.d2` files in Git)
- Free; no API keys or quotas

**Cons:**
- No photorealistic imagery
- Limited styling/theming
- Not suitable for artistic or brand graphics

**Step-by-step:**

```bash
# 1. Use Copilot CLI to generate Mermaid code
copilot-cli chat "Generate a Mermaid flowchart for a user login flow with OAuth"

# 2. Save the Mermaid code to a file
echo "flowchart TD
  A[Start] --> B[User clicks Login]
  B --> C{OAuth Provider?}
  C -->|Google| D[Redirect to Google]
  C -->|GitHub| E[Redirect to GitHub]" > login-flow.mmd

# 3. Render to SVG (via Mermaid CLI)
npm install -g @mermaid-js/mermaid-cli
mmdc -i login-flow.mmd -o login-flow.svg

# 4. Embed SVG in markdown or web pages
# (SVG files can be embedded directly in HTML/Markdown)
```

**Tools:**
- **Mermaid CLI:** `npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg`
- **beautiful-mermaid (npm):** For SVG + ASCII output, AI-friendly theming
- **PlantUML:** `plantuml diagram.puml -Tsvg`
- **D2 CLI:** `d2 diagram.d2 diagram.svg` (modern, Google-backed)

---

### 2. **Azure OpenAI DALL-E 3 for AI Image Generation** ⭐ Recommended for Photorealism

**Best for:** Brand graphics, concept art, product mockups, marketing visuals.

**Pros:**
- Microsoft-owned; meets "MS-approved sources" requirement
- State-of-the-art image quality (DALL-E 3, soon GPT-Image-1.5)
- Integrates with Python, Node.js, .NET, Java
- Can be orchestrated in GitHub Actions

**Cons:**
- Requires Azure OpenAI subscription (~$15 per 1M tokens)
- Not directly accessible from Copilot CLI (requires external SDK)
- API key management needed

**Step-by-step:**

```python
# 1. Install Azure OpenAI SDK
# pip install openai

from openai import AzureOpenAI
import os

# 2. Configure Azure OpenAI client
client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    api_version="2023-12-01-preview"
)

# 3. Generate image from prompt
response = client.images.generate(
    model="dalle3",  # deployment name
    prompt="A futuristic smart city at sunrise with autonomous vehicles",
    n=1,
    size="1024x1024"
)

# 4. Save image
image_url = response.data[0].url
print(f"Image saved: {image_url}")

# (Optional) Download and save locally:
# import requests
# img_data = requests.get(image_url).content
# with open("generated_image.png", "wb") as f:
#     f.write(img_data)
```

**Integration with GitHub Actions:**

```yaml
name: Generate Marketing Graphics
on: [workflow_dispatch]

jobs:
  generate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v4
        with:
          python-version: "3.11"
      - run: pip install openai
      - run: python scripts/generate_dall_e_image.py
        env:
          AZURE_OPENAI_ENDPOINT: ${{ secrets.AZURE_OPENAI_ENDPOINT }}
          AZURE_OPENAI_KEY: ${{ secrets.AZURE_OPENAI_KEY }}
      - uses: actions/upload-artifact@v3
        with:
          name: generated-image
          path: generated_image.png
```

**Setup:**
1. Create Azure OpenAI resource: https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/dall-e
2. Deploy DALL-E 3 model
3. Store endpoint and key in GitHub Secrets
4. Use Python/Node.js/Java SDKs (see references below)

---

### 3. **MCP Servers for Enhanced Diagram Rendering** 🔧 Advanced Option

**Best for:** Infrastructure diagrams, real-time diagram editing, cloud architecture.

**Pros:**
- Integrates directly with Copilot (MCP protocol)
- Specialized servers for Azure, Kubernetes, cloud resources
- Automatable: Copilot → MCP server → PNG/SVG

**Cons:**
- Requires running an MCP server (separate process)
- Limited to diagram types supported by each server
- Not all MCP servers are Microsoft-vetted

**Available MCP Servers:**
1. **Azure Diagram MCP** (Microsoft-backed)
   - GitHub: https://github.com/dminkovski/azure-diagram-mcp
   - Generates Azure infrastructure diagrams using Python Diagrams library
   - Output: PNG images

2. **Mermaid MCP**
   - GitHub: https://github.com/hustcc/mcp-mermaid
   - Renders Mermaid syntax to PNG/SVG
   - Fast; widely compatible

3. **Draw.io MCP**
   - GitHub: https://github.com/lgazo/drawio-mcp-server
   - Integrates with Draw.io (diagrams.net)
   - Highly visual; supports complex diagrams

**How to Set Up:**

```bash
# 1. Install MCP server (example: azure-diagram-mcp)
git clone https://github.com/dminkovski/azure-diagram-mcp.git
cd azure-diagram-mcp
npm install

# 2. Register with Copilot CLI
# Edit ~/.copilot/config.json or use CLI command:
copilot-cli mcp add --name "azure-diagram" --command "npm run start"

# 3. Use in Copilot
# Prompt: "Generate an Azure architecture diagram with VNets, VMs, and a load balancer"
# Copilot will invoke the MCP server → outputs PNG
```

---

## Limitations & Workarounds

| Limitation | Impact | Workaround |
|-----------|--------|-----------|
| **Copilot CLI can't call Azure OpenAI DALL-E directly** | Need external orchestration | Write Python/Node.js wrapper; call from Copilot chat context or GitHub Actions |
| **Text-based diagrams can't do photorealism** | Not suitable for marketing/art | Reserve DALL-E 3 for those use cases; use Mermaid for technical docs |
| **MCP servers require separate runtime** | Added infrastructure burden | Use only if diagram rendering frequency justifies overhead |
| **SVG export quality varies** | Rendering issues in some tools | Test SVG output in target platform (browser, Figma, etc.); use PNG fallback |
| **No GPU-accelerated generation in Copilot CLI** | Diagram rendering can be slow | Pre-render diagrams in CI/CD; cache outputs; use cloud rendering services |
| **GitHub Models != GitHub Models marketplace** | Confusion over available models | Clarify: "GitHub Models" = text/code models in Copilot. Image models come from Azure OpenAI separately. |

---

## Confidence & Open Questions

**Research Confidence:** 🟡 **MEDIUM**

- ✅ Verified: GitHub Copilot models do NOT include image generation
- ✅ Verified: Azure OpenAI DALL-E 3 is Microsoft-owned and accessible via SDKs
- ✅ Verified: Mermaid, MCP servers, and diagram-as-code tools work with Copilot
- ⚠️ Unverified: Whether GitHub Copilot CLI will support DALL-E natively in future roadmap
- ⚠️ Unverified: Performance of MCP servers at scale (e.g., 1000+ diagram renders/day)

**Open Questions:**
1. Should we build a custom MCP server to wrap Azure OpenAI DALL-E for one-step image generation?
2. Are there cost optimizations for high-volume diagram rendering (caching, batching)?
3. Will GitHub release a native image generation model in GitHub Models marketplace?
4. Can we auto-generate SVG diagrams from code comments (e.g., `@diagram flowchart`) during CI/CD?

---

## Quick Reference: Command Cheat Sheet

```bash
# Generate Mermaid diagram with Copilot CLI
copilot-cli chat "Create a Mermaid sequence diagram for a payment API call"

# Render Mermaid to SVG
npx @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg

# Render Mermaid to ASCII (beautiful-mermaid)
npx beautiful-mermaid diagram.mmd --ascii

# Render Mermaid to ASCII (Python)
pip install mermaid-ascii-diagrams
mermaid-ascii diagram.mmd -o diagram.txt

# PlantUML to SVG
plantuml diagram.puml -Tsvg

# D2 to SVG
d2 diagram.d2 diagram.svg

# Azure OpenAI DALL-E (Python)
python -m pip install openai
python scripts/dalle_generate.py

# Register MCP server with Copilot
copilot-cli mcp add --name "my-server" --command "npm run start"
```

---

## References

### GitHub/Microsoft Resources
- [GitHub Copilot CLI Documentation](https://docs.github.com/en/copilot/reference/copilot-cli)
- [Supported AI Models in GitHub Copilot](https://docs.github.com/en/copilot/reference/ai-models/supported-models)
- [Adding MCP Servers to Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [Azure OpenAI DALL-E 3](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/how-to/dall-e)

### Diagram-as-Code Tools
- [Mermaid.js](https://mermaid.js.org/) — Flowchart, sequence, Gantt, class diagrams
- [PlantUML](https://plantuml.com/) — UML, architecture, entity-relationship diagrams
- [D2 Language](https://d2lang.com/) — Google-created; modern, expressive diagram language
- [beautiful-mermaid (npm)](https://www.npmjs.com/package/beautiful-mermaid) — Render to SVG/ASCII

### MCP Servers (Image/Diagram)
- [Azure Diagram MCP](https://github.com/dminkovski/azure-diagram-mcp) — Azure infrastructure diagrams
- [Mermaid MCP](https://github.com/hustcc/mcp-mermaid) — Mermaid rendering
- [Draw.io MCP](https://github.com/lgazo/drawio-mcp-server) — Draw.io integration
- [MCP Servers Catalog](https://mcpservers.org/)

### Azure OpenAI SDKs
- [Python SDK](https://github.com/Azure/azure-sdk-for-python)
- [Node.js SDK](https://github.com/Azure/azure-sdk-for-js)
- [.NET SDK](https://github.com/Azure/azure-sdk-for-net)
- [Java SDK](https://docs.langchain4j.dev/integrations/image-models/azure-dall-e/)

---

## Skill History

**Created:** 2026-03-25  
**Issue:** #246  
**Research Conducted By:** Seven (Research & Docs)

### Key Findings
1. GitHub Copilot models are **text/code-only**; no native image generation
2. **Text-based graphics** (Mermaid, SVG, ASCII art) are the native Copilot-CLI approach
3. **Azure OpenAI DALL-E 3** is the Microsoft-approved path for AI image generation
4. **MCP servers** extend Copilot with specialized diagram renderers
5. Best approach: **Mermaid for documentation + Azure DALL-E for marketing/art**

