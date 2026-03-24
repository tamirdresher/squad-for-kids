---
layout: post
title: "Aspire Goes Polyglot — Why This Changes Everything for AI Agent Teams"
date: 2026-03-25
tags: [aspire, ai-agents, squad, polyglot, python, dotnet, github-copilot, orchestration]
series: "Scaling AI-Native Software Engineering"
series_part: 7
---

> *"You will be assimilated. Resistance is futile."*
> — The Borg Collective, Star Trek: The Next Generation

Here's a problem I didn't have until I had an AI team: my agents don't all speak the same language.

Picard (my lead agent) reasons in whatever model GitHub Copilot hands him. Data (my code expert) writes C# and Go. But my LLM-heavy agents? They live in Python. LangGraph, FastAPI, the whole ecosystem. And my frontend tooling? Node.js all the way down. When I wanted to add a Python-based summarization agent to my Squad as an actual runnable service — not just a file, but a running process I could watch, debug, and wire into the rest of the system — I hit the wall.

The wall was the dev experience. Running a mixed Python/C#/Node.js stack in local dev meant a zoo of terminal windows, manually managed virtual environments, hardcoded ports, and zero unified observability. I'd open a log from my .NET API and have to mentally match it to what the Python agent was doing in a completely separate terminal. It was fine. It was also chaos.

Then Aspire 13 dropped. And the wall disappeared.

---

## What "Polyglot" Actually Means in Aspire 13

Aspire 13.0 is where the product stopped being ".NET Aspire" and became just **Aspire** — a full polyglot application platform. I don't mean that as marketing. I mean it literally changed what you can put in an AppHost.

Python is now a first-class citizen. Not "here's how you run a container with Python in it" — actually first-class. You get three different ways to declare Python workloads depending on what you're building:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Run a Python script directly
var etlJob = builder.AddPythonApp("etl-job", "../etl", "process_data.py");

// Run a Python module (think: celery, uvicorn)
var worker = builder.AddPythonModule("queue-worker", "../worker", "celery")
    .WithArgs("worker", "-A", "tasks", "--loglevel=info");

// ASGI app via uvicorn (FastAPI, Starlette, Quart)
var llmApi = builder.AddUvicornApp("llm-api", "../llm_agent", "main:app")
    .WithExternalHttpEndpoints()
    .WithHttpHealthCheck("/health");
```

And package management is automatic. If there's a `requirements.txt` or `pyproject.toml`, Aspire picks it up and handles the venv. You can explicitly opt into `uv` (which is 10–100x faster than pip) with `.WithUv()`. Or you can let Aspire figure it out. Either way, you don't manually activate a virtual environment. You just `aspire run`.

JavaScript got the same treatment. Vite apps, npm-based projects, automatic package manager detection. The AppHost doesn't care that your frontend is Node.js and your backend is C#. It just wires them together.

And critically for anyone connecting services across languages: connection properties now work uniformly across all of them. Azure resource connection strings are exposed as `HostName`, `Port`, `JdbcConnectionString`, or full URIs depending on what the consumer needs. Your Python FastAPI service doesn't need to parse a .NET-formatted connection string. It just asks for what it needs.

---

## Why This Matters Specifically for AI Agent Teams

Here's the thing about running an AI team at scale: [the agents I've built](/blog/2026/03/11/scaling-ai-part1-first-team) aren't all .NET processes. They can't be. The best LLM orchestration libraries right now are in Python — LangGraph, LangChain, the OpenAI SDK with all its async goodness. Semantic Kernel exists in C# and it's excellent, but if I want to run a LangGraph-based planning agent as an actual service, I'm writing Python.

Before Aspire 13, that meant my Squad had a split personality. The infrastructure — Ralph's watch loops, the task router, the GitHub integrations — lived in .NET and PowerShell. The LLM-heavy pieces were Python scripts I ran manually when I needed them. Not wired in. Not observed. Not part of the same distributed trace.

Now I can do this:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// The squad's coordination layer — .NET
var squadRouter = builder.AddProject<Projects.Squad_Router>("squad-router");

// Python-based LLM planning agent (LangGraph)
var planner = builder.AddUvicornApp("squad-planner", "../agents/planner", "main:app")
    .WithReference(squadRouter)
    .WithHttpHealthCheck("/health");

// Python-based summarization worker
var summarizer = builder.AddPythonModule("squad-summarizer", "../agents/summarizer", "summarize")
    .WithReference(planner);

// Node.js tooling layer (MCP server, webhook handler)
var tools = builder.AddNpmApp("squad-tools", "../tools")
    .WithReference(squadRouter);

// Redis for agent state and task queues
var redis = builder.AddRedis("agent-state");

squadRouter
    .WithReference(redis)
    .WithReference(planner)
    .WithReference(tools);
```

One `aspire run`. One dashboard. Every service — Python, Node.js, .NET — showing up together with unified logs, metrics, and distributed traces. When the planner agent makes an LLM call, I can see that span. When the summarizer picks up a job from Redis, that's a trace too. When they fail, they fail visibly, in one place.

This is the piece [I was missing in Part 3](/blog/2026/03/18/scaling-ai-part3-distributed) when I talked about Squad becoming a distributed system. I had the coordination model figured out. I just didn't have the local dev experience to match.

---

## What Running This Actually Looks Like

Let me be concrete. Here's what the Squad planner agent looks like as a FastAPI service:

```python
# agents/planner/main.py
from fastapi import FastAPI
from langchain_openai import AzureChatOpenAI
import os

app = FastAPI()

llm = AzureChatOpenAI(
    azure_endpoint=os.environ["AZURE_OPENAI_ENDPOINT"],
    api_key=os.environ["AZURE_OPENAI_KEY"],
    azure_deployment="gpt-4o",
)

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.post("/plan")
async def plan(task: dict):
    response = await llm.ainvoke(
        f"Break this task into parallel subtasks for specialist agents: {task['description']}"
    )
    return {"plan": response.content}
```

Aspire handles the `AZURE_OPENAI_ENDPOINT` and `AZURE_OPENAI_KEY` environment variables via connection references defined in the AppHost. GitHub Copilot drives the actual LLM calls at the agent reasoning level — the planner is just the orchestration layer that decides how to decompose work before handing off to the right specialist.

The AppHost wires the Python app to the rest of the system:

```csharp
var openAi = builder.AddConnectionString("azure-openai");

var planner = builder.AddUvicornApp("squad-planner", "../agents/planner", "main:app")
    .WithReference(openAi)
    .WithEnvironment("AZURE_OPENAI_DEPLOYMENT", "gpt-4o")
    .WithHttpHealthCheck("/health");
```

When I run this, the Aspire dashboard shows the planner service alongside every other Squad component. Health checks are tracked. If the LangGraph agent throws an exception, it shows up in the structured log view with the same trace ID as whatever triggered it from the .NET router. No more mentally joining logs across five terminal tabs.

And when I'm done developing? `aspire publish` generates production Dockerfiles for the Python services automatically, with proper venv setup baked in. I don't write a Dockerfile. Aspire writes the Dockerfile.

---

## How This Could Evolve: Squad as AppHost-Managed Workers

Right now, my Squad agents run as GitHub Copilot CLI sessions — long-running processes managed by Ralph's watch loop. That works. It's what [I showed in Part 4](/blog/2026/03/21/scaling-ai-part4-distributed-problems) when I solved the auth race conditions and lock contention. But there's a more elegant model sitting right in front of me.

Aspire 13.1 added MCP (Model Context Protocol) support directly in the platform. The `aspire mcp init` command configures your AI coding tools to discover and interact with your running AppHost. That means GitHub Copilot can query resource state, read structured logs, and inspect traces from a running Squad via MCP — without me setting any of that up.

Imagine Squad agents as Aspire-managed workers:

```csharp
// Each Squad agent becomes a managed resource
var picard = builder.AddPythonModule("picard-agent", "../agents/picard", "agent")
    .WithArgs("--role", "lead", "--routing-table", "routing.md")
    .WithReference(redis)
    .WithReference(squadRouter);

var data = builder.AddProject<Projects.Data_Agent>("data-agent")
    .WithReference(picard)
    .WithReference(redis);

var troi = builder.AddPythonModule("troi-agent", "../agents/troi", "agent")
    .WithArgs("--role", "blogger")
    .WithReference(picard);
```

Health checks tell Aspire when an agent is overloaded or stuck. Resource scaling handles burst workloads. The dashboard shows which agents are running, what they're processing, and where they're failing. This isn't hypothetical — it's exactly what Aspire is built for.

The part I'm actively exploring is agent-to-agent communication through Aspire's service discovery. Right now, Picard notifies Data via GitHub issue comments (slow, async, reliable). With Aspire-managed workers, they could use HTTP calls through discovered endpoints instead — same reliability model, dramatically lower latency.

---

## Try It Yourself

If you want to see Squad in action, the framework lives at [https://github.com/tamirdresher/squad](https://github.com/tamirdresher/squad). The routing table, the agent personas, the decisions.md pattern — it's all in there.

For the Aspire polyglot side, the fastest way to get started is:

```bash
# Install the Aspire CLI
curl -sSL https://aspire.dev/install.sh | bash

# Create a Python + React starter (demonstrates the polyglot model)
aspire new aspire-py-starter

# Run it
aspire run
```

The `aspire-py-starter` template gives you a FastAPI backend, Vite + React frontend, Redis, and OpenTelemetry — all running together locally with one command. It's the best 15-minute demo of what polyglot orchestration actually feels like.

One thing I'd suggest: after you get the starter running, try adding a second Python worker with `AddPythonModule` that connects to the same Redis instance. Wire it up, run it, watch both services show up in the dashboard. That's the moment it clicks. Two different Python processes, one AppHost, unified observability. Now imagine your agents living there.

---

The rebranding from ".NET Aspire" to "Aspire" isn't cosmetic. It's a statement about scope. This is no longer a .NET-first tool with some container support bolted on. It's a platform that meets your stack wherever it lives — Python, Node.js, .NET, containers — and gives you a coherent local dev experience across all of it.

For AI teams specifically, that's not a nice-to-have. My agents write code in whatever language makes sense for the job. The orchestration layer shouldn't punish that decision. With Aspire 13, it finally doesn't.

The Borg would approve. Resistance really is futile.
