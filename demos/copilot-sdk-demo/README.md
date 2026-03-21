# 🏟️ AI Code Review Arena

> **Two AI judges. One code snippet. A live terminal battle you can't look away from.**

Built with [GitHub Copilot SDK](https://github.com/microsoft/models) (Microsoft.Extensions.AI + Azure.AI.Inference) in C# .NET 8.

---

## What It Does

Paste any C# code and watch two AI judges with **opposite personalities** review it simultaneously:

| Judge | Personality | Focus |
|-------|-------------|-------|
| 🛡️ **CodeGuard** | The Strict Architect | Correctness, security, SOLID principles |
| 🚀 **DevAdvocate** | The Pragmatic Advocate | Shipping velocity, developer happiness, real-world tradeoffs |

Then they **debate each other's findings** in real-time.  
Then they **converge on top 3 fixes** the author must make.  
Finally a **live scoreboard** with per-dimension scores and a verdict banner.

All live-streamed token by token in a split-screen Spectre.Console TUI.

### 🔧 Tool/Function Calling Demo (`--tools`)

Add `--tools` to see **AI tool/function calling** live before the arena:

1. The AI autonomously calls `analyze_code()` — a C# static analyser registered as an `AIFunction`
2. The terminal shows the tool being invoked and its structured return value (metrics panel)
3. The AI uses objective data (cyclomatic complexity, security hotspots, code smells) in its grounded review

This is a textbook demo of `AIFunctionFactory.Create()` + `UseFunctionInvocation()` middleware in Microsoft.Extensions.AI.

---

## Demo Script (under 3 minutes)

```
=== Without --tools (2 minutes) ===
1. Start the app — the banner renders instantly, setting the stage
2. The built-in sample (a buggy UserService with SQLi, hardcoded secrets) loads
3. Both judges stream simultaneously — audience watches two AIs "think" in parallel
4. Debate round: CodeGuard calls out SQL injection, DevAdvocate says "at least it works"
5. Consensus fixes appear as a numbered list — audience can follow along
6. Scoreboard drops — Security: 2/10 ░░░░ gets a gasp every time
7. "Now let me paste YOUR code" — hand it to an audience member

=== With --tools (adds ~30 seconds before the arena) ===
1. Spin up the status spinner: "AI is reasoning… watching for tool call…"
2. "⚡ Tool call detected: analyze_code() invoked by AI!" — audience sees function calling live
3. "✅ Tool result received" — structured metrics panel renders: complexity, smells, security hotspots
4. AI writes a data-grounded analysis: "Cyclomatic complexity of 14 indicates…"
5. Then the full arena runs as above
```

**Total runtime:** ~90s without `--tools`, ~2:30 with `--tools`

---

## Quick Start

### Prerequisites
- .NET 8 SDK
- A [GitHub Personal Access Token](https://github.com/settings/tokens) (no scopes required for GitHub Models)

### Run with built-in demo
```bash
export GITHUB_TOKEN="github_pat_..."   # Windows: $env:GITHUB_TOKEN="..."
cd src/CodeReviewArena
dotnet run
```

### Review your own file
```bash
dotnet run -- --file ../../MyService.cs
```

### Full demo: tool calling + arena
```bash
dotnet run -- --tools                        # tool calling demo, then arena (built-in sample)
dotnet run -- --tools --file MyCode.cs       # tool calling, then arena (your code)
```

### Pipe from stdin
```bash
cat MyController.cs | dotnet run
```

### Security mode (CodeGuard vs CipherHawk)
```bash
dotnet run -- --mode security --file FileController.cs
```

### Use a different model
```bash
$env:COPILOT_MODEL = "gpt-4o"   # default is gpt-4o-mini
dotnet run
```

---

## Architecture

```
CodeReviewArena/
├── Program.cs                  ← Entry point, IChatClient wiring, flag parsing
├── Judges/
│   ├── JudgePersonality.cs     ← Personality definitions & system prompts
│   └── Judge.cs                ← IChatClient wrapper, streaming, conversation history
├── Arena/
│   ├── ArenaOrchestrator.cs    ← 3-round orchestration (review → debate → consensus)
│   └── RoundResult.cs          ← Score records and verdict logic
├── Tools/
│   ├── CodeMetricsTool.cs      ← AI-callable function: static C# analyser (cyclomatic complexity, smells, CVEs)
│   └── ToolCallDemo.cs         ← Tool calling demo: AIFunctionFactory + UseFunctionInvocation()
├── UI/
│   └── ArenaDisplay.cs         ← Spectre.Console live dual-panel renderer
└── Samples/
    └── DemoSamples.cs          ← Built-in demo code with intentional bugs
```

---

## How It Uses the GitHub Copilot SDK

| Concept | Location |
|---------|----------|
| `IChatClient` abstraction (Microsoft.Extensions.AI) | `Judge.cs` — one per judge |
| `GetStreamingResponseAsync` live streaming | `Judge.StreamAndRecordAsync` |
| `AsChatClient()` bridge extension | `Program.cs` — `ChatCompletionsClient.AsChatClient()` |
| Per-agent conversation history (`List<ChatMessage>`) | `Judge._history` |
| Parallel multi-agent execution | `ArenaOrchestrator.RunAsync` — `Task.WhenAll` |
| System prompt persona injection | `JudgePersonality.SystemPrompt` via `ChatRole.System` |
| Token streaming into live TUI | `ArenaDisplay.RunLiveDualPanelAsync` |
| **Tool/function calling** | `Tools/CodeMetricsTool.cs` + `AIFunctionFactory.Create()` |
| **Auto tool invocation middleware** | `Tools/ToolCallDemo.cs` + `.UseFunctionInvocation()` |
| **`ChatOptions.Tools` registration** | `ToolCallDemo.RunAsync` — `FunctionCallContent` / `FunctionResultContent` |

---

## Extending the Arena

### Add a new judge
```csharp
// In JudgePersonality.cs
public static readonly JudgePersonality PerformanceGuru = new(
    Name: "PerfGuru",
    Emoji: "⚡",
    Title: "The Performance Guru",
    PanelColor: Color.Green,
    SystemPrompt: "You are obsessed with performance. Every allocation is a crime..."
);
```

### Add it to a mode
```csharp
// In Program.cs
"perf" => new[] { Personalities.StrictArchitect, Personalities.PerformanceGuru },
```

### Use Azure OpenAI instead of GitHub Models
```csharp
IChatClient CreateChatClient() =>
    new AzureOpenAIClient(new Uri(azureEndpoint), new AzureKeyCredential(azureKey))
        .AsChatClient(deploymentName);
```
The rest of the code is unchanged — that's the power of the `IChatClient` abstraction.

---

## Why This Demo Is a WOW Moment

1. **Real AI conflict** — two models with opposite personalities genuinely disagree (especially about the SQL injection sample)
2. **Live streaming** — watching tokens appear in two panels simultaneously is viscerally impressive
3. **3-minute arc** — it has a beginning (setup), middle (debate), and end (verdict) like a story
4. **Audience participation** — "anyone want to submit their code?" closes every demo
5. **Extensible live** — add a third judge mid-demo to show `IChatClient` abstraction in action

---

*Built for the GitHub Copilot SDK Demo Showcase · Issue #980*
