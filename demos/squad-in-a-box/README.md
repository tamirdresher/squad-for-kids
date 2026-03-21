# 🤖 Squad in a Box

> **Four AI agents. One coding task. Live collaboration in your terminal.**

Built with [GitHub Copilot SDK](https://github.com/microsoft/models) (Microsoft.Extensions.AI + Azure.AI.Inference) in C# .NET 9.

---

## What It Does

Watch a full software development squad work through a coding task — live:

| Agent | Role | What they produce |
|-------|------|-------------------|
| 🏛️ **Architect** | System Architect | Architecture decisions, data model, API surface |
| 👨‍💻 **Developer** | Software Developer | Working C# implementation |
| 🧪 **Tester** | QA Engineer | Test coverage plan + xUnit test code |
| 🔍 **Reviewer** | Code Reviewer | Quality scores, findings, final verdict |

Each agent builds on the prior agent's output. Tokens stream in real-time to a Spectre.Console TUI.

---

## Quick Start

### Prerequisites
- [.NET 9 SDK](https://dotnet.microsoft.com/download)
- A [GitHub Personal Access Token](https://github.com/settings/tokens) (no scopes required for GitHub Models)

### Run with the built-in demo task

```bash
# Set your GitHub PAT
$env:GITHUB_TOKEN = "github_pat_..."       # PowerShell
# export GITHUB_TOKEN="github_pat_..."     # bash/zsh

cd src/SquadInABox
dotnet run
```

**Default task:** *"Build a minimal TODO REST API in C# .NET with full CRUD operations and in-memory storage"*

### Run with a custom task

```bash
dotnet run -- "Build a rate limiter middleware in C# .NET"
dotnet run -- "Implement an LRU cache in C#"
dotnet run -- "Design a simple pub/sub event bus"
```

### Use a different model

```bash
$env:SQUAD_MODEL = "gpt-4o"    # default is gpt-4o-mini
dotnet run
```

---

## Demo Script (~3 minutes)

```
1. Start the app — the banner shows the task and the full agent roster
2. Architect streams its output — audience sees architecture decisions forming live
3. Developer picks up the design and implements it — code appears token by token
4. Tester writes tests based on the implementation — test cases stream in
5. Reviewer scores everything — the table and final verdict is the punchline

"Now let me give them a DIFFERENT task..."  →  dotnet run -- "Build a ..."
```

**Total runtime:** ~90-120 seconds (gpt-4o-mini), ~60 seconds (gpt-4o)

---

## Architecture

```
SquadInABox/
├── Program.cs                  ← Entry point, IChatClient wiring, CLI args
├── Agents/
│   ├── AgentRole.cs            ← Role definitions, system prompts, personalities
│   └── SquadAgent.cs           ← IChatClient wrapper, prompt construction, streaming
├── Squad/
│   ├── SquadOrchestrator.cs    ← Sequential pipeline (Architect→Dev→Test→Review)
│   └── SquadArtifacts.cs       ← Result record types
└── UI/
    └── SquadDisplay.cs         ← Spectre.Console TUI: banner, live panels, summary
```

---

## How It Uses the GitHub Copilot SDK

| Concept | Location |
|---------|----------|
| `IChatClient` abstraction (Microsoft.Extensions.AI) | `SquadAgent.cs` — one per agent |
| `GetStreamingResponseAsync` live streaming | `SquadAgent.StreamAndRecordAsync` |
| `AsChatClient()` bridge extension | `Program.cs` — `ChatCompletionsClient.AsChatClient()` |
| Per-agent conversation history (`List<ChatMessage>`) | `SquadAgent._history` |
| System prompt persona injection | `AgentRole.SystemPrompt` via `ChatRole.System` |
| Sequential multi-agent orchestration | `SquadOrchestrator.RunAsync` |
| Token streaming into live Spectre.Console panel | `SquadDisplay.RunLiveAgentPanelAsync` |
| Context passing between agents | `SquadOrchestrator.BuildContext` |

---

## Extending the Squad

### Add a new agent role

```csharp
// In Agents/AgentRole.cs
public static readonly AgentRole SecurityAuditor = new(
    Name: "SecurityAuditor",
    Emoji: "🛡️",
    PanelColor: Color.Red,
    Title: "Security Auditor",
    SystemPrompt: "You review code for security vulnerabilities..."
);
```

### Insert it into the pipeline

```csharp
// In Program.cs
var roles = new[]
{
    AgentRole.Architect,
    AgentRole.Developer,
    AgentRole.Tester,
    AgentRole.SecurityAuditor,  // ← new agent
    AgentRole.Reviewer,
};
```

That's it. The orchestrator and display handle everything else automatically.

### Swap the AI backend

```csharp
// Azure OpenAI instead of GitHub Models
IChatClient CreateChatClient() =>
    new AzureOpenAIClient(new Uri(azureEndpoint), new AzureKeyCredential(azureKey))
        .AsChatClient(deploymentName);
```

Zero other changes — that's the power of the `IChatClient` abstraction.

---

## Why This Demo Is a WOW Moment

1. **The Squad pattern made tangible** — audiences instantly understand multi-agent AI when they see it working
2. **Sequential context passing** — each agent's output visibly builds on the last; this isn't just parallel calls
3. **Live streaming** — watching code and architecture decisions form token-by-token is viscerally impressive
4. **The Reviewer's verdict** — the quality scores table + final verdict is a perfect punchline
5. **Run any task** — "what should we build?" → audience suggestion → live Squad session

---

*Built for GitHub Copilot SDK Demo Showcase · Issue [#980](https://github.com/tamirdresher/tamresearch1/issues/980)*
