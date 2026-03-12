# Nano-Banana-MCP Setup Guide

> **Issue:** [#375](https://github.com/tamresearch1/issues/375) — Research & setup of nano-banana-mcp for Microsoft Foundry Gemini integration

## Overview

[nano-banana-mcp](https://github.com/ConechoAI/Nano-Banana-MCP) is a lightweight MCP (Model Context Protocol) server that provides AI image generation and editing using Google's Gemini models. It exposes tools like `generate_image`, `edit_image`, `continue_editing`, and `describe_image` to any MCP-compatible client (Claude Code, Cursor, etc.).

- **npm package:** `nano-banana-mcp` (v1.0.3)
- **SDK:** `@google/genai` (Google's native GenAI SDK)
- **License:** MIT
- **Node.js:** ≥18.0.0

## Installation

The package is installed as a dev dependency in this repo:

```bash
npm install nano-banana-mcp --save-dev
```

To run it as an MCP server:

```bash
npx nano-banana-mcp
```

## Configuration

### Basic Setup (Google Gemini Direct)

1. **Get a Gemini API key** from [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Set the environment variable:

```bash
# Linux/macOS
export GEMINI_API_KEY="your-gemini-api-key"

# Windows PowerShell
$env:GEMINI_API_KEY = "your-gemini-api-key"
```

3. Configure your MCP client:

```json
{
  "mcpServers": {
    "nano-banana": {
      "command": "npx",
      "args": ["nano-banana-mcp"],
      "env": {
        "GEMINI_API_KEY": "your-gemini-api-key-here"
      }
    }
  }
}
```

### Available MCP Tools

| Tool | Description |
|------|-------------|
| `generate_image` | Create images from text prompts |
| `edit_image` | Modify existing images with text instructions |
| `continue_editing` | Iterate on the last generated/edited image |
| `get_last_image_info` | Get info about the last generated image |
| `configure_gemini_token` | Set API key via the MCP tool |
| `get_configuration_status` | Check if API key is configured |

### Image Output Locations

- **Windows:** `%USERPROFILE%\Documents\nano-banana-images\`
- **macOS/Linux:** `./generated_imgs/` (current directory)

## Microsoft Foundry Gemini Integration — Compatibility Assessment

### ⚠️ Key Finding: Not Directly Compatible

After analysis of the nano-banana-mcp source code (v1.0.3), **it cannot directly connect to Microsoft AI Foundry's Gemini endpoint**. Here's why:

1. **SDK Mismatch:** nano-banana-mcp uses `@google/genai` (Google's native GenAI SDK), which communicates with Google's proprietary API format (`generativelanguage.googleapis.com`).

2. **No Custom Base URL:** The package hardcodes `new GoogleGenAI({ apiKey })` without accepting a custom `httpOptions.baseUrl` parameter. There is no environment variable to override the API endpoint.

3. **API Format Difference:** Microsoft AI Foundry exposes Gemini models through an **OpenAI-compatible API** (`/chat/completions` format), not through Google's native GenAI API format. The request/response schemas are fundamentally different.

### What Microsoft AI Foundry Gemini Looks Like

Azure AI Foundry provides Gemini access via OpenAI-compatible endpoints:

```
POST https://<resource>.services.ai.azure.com/models/chat/completions
Authorization: Bearer <azure-api-key>

{
  "model": "gemini-2.5-flash-lite",
  "messages": [
    {"role": "user", "content": "Hello"}
  ]
}
```

This is a **text chat completions** endpoint — it does **not** expose Gemini's image generation capabilities the same way Google's native API does.

### Options to Bridge the Gap

#### Option A: Use nano-banana-mcp with Google API Key (Recommended for Now)
- Get a free Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
- Use nano-banana-mcp as designed — it works well for image generation
- This is the fastest path to getting image gen/edit capabilities

#### Option B: Fork & Modify nano-banana-mcp
- Fork the repo and add `httpOptions.baseUrl` support to the `GoogleGenAI` constructor
- Would require the Foundry endpoint to support Google's native API format (unlikely)
- **Effort:** Medium | **Likelihood of working:** Low

#### Option C: Build a Custom MCP Server for Azure AI Foundry
- Create a new MCP server that wraps Azure AI Foundry's OpenAI-compatible endpoint
- Use `@azure/openai` or the standard OpenAI SDK pointed at Azure
- Would give access to Gemini text capabilities but **not** image generation (Foundry doesn't expose Gemini's image gen API)
- **Effort:** Medium | **Likelihood of working:** High for text, N/A for image gen

#### Option D: Wait for Foundry Image Generation Support
- Microsoft AI Foundry may add Gemini image generation endpoints in the future
- Monitor [Azure AI Foundry docs](https://learn.microsoft.com/en-us/azure/foundry/) for updates

## Recommended Next Steps

1. **Immediate:** Use nano-banana-mcp with a Google Gemini API key for image generation needs
2. **If Azure integration is required for governance/compliance:** Build a custom MCP server targeting Azure AI Foundry's OpenAI-compatible endpoint (text only)
3. **Tamir's input needed:**
   - Do you have a Google Gemini API key we can test with?
   - Is the goal specifically image generation, or text-based Gemini capabilities?
   - If text-based: we can build an Azure AI Foundry MCP wrapper quickly
   - Is there a specific Azure AI Foundry resource/endpoint already provisioned?

## References

- [nano-banana-mcp on npm](https://www.npmjs.com/package/nano-banana-mcp)
- [GitHub: ConechoAI/Nano-Banana-MCP](https://github.com/ConechoAI/Nano-Banana-MCP)
- [Google AI Studio — Get API Key](https://aistudio.google.com/app/apikey)
- [Azure AI Foundry — Import Gemini API](https://learn.microsoft.com/en-us/azure/api-management/openai-compatible-google-gemini-api)
- [Azure AI Foundry — Model Catalog](https://ai.azure.com/catalog/models)
- [Azure AI Foundry — Endpoints](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/endpoints)
