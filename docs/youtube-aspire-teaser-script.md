# YouTube Script: "Add .NET Aspire in 15 Minutes"
**Series:** Aspire Workshop Teaser  
**Target length:** 12–15 minutes  
**GitHub repo:** [tamirdresher/aspire-workshop](https://github.com/tamirdresher/aspire-workshop)  
**Goal:** Get viewers to fork the workshop repo and enroll in the full course  
**Issue:** #737

---

## YouTube Metadata

### Title Options (A/B test these)
1. **"Add .NET Aspire to Your App in 15 Minutes (Dashboards, Service Discovery & Telemetry — FREE)"**
2. **".NET Aspire in 15 Minutes — Stop Babysitting Your Microservices"**
3. **"I Ran 5 Microservices Locally in 15 Minutes With Zero YAML — Here's How (.NET Aspire)"**

### Description Template
```
In this video I'll show you how to take a real distributed .NET app and add Aspire in under 15 minutes — getting a live dashboard, automatic service discovery, and built-in telemetry with almost zero config.

No YAML. No Docker Compose file that's 400 lines long. Just a few lines of C# and everything wires together.

📦 Fork the workshop repo and follow along:
https://github.com/tamirdresher/aspire-workshop

🎓 Want to go deeper? The full Aspire Workshop course covers:
- Custom resources and integrations
- Testing distributed apps with Aspire
- Production deployment
- Cloud and multi-cloud patterns

👇 Full course link in the pinned comment.

TIMESTAMPS:
0:00 – Hook: What you'll build
0:30 – Why Aspire exists (the microservices dev problem)
2:00 – Fork the repo and run the app
4:00 – The Aspire dashboard tour
6:30 – Service discovery: how it actually works
8:00 – Telemetry and distributed traces
10:00 – What's in the full course
12:00 – Call to action

#dotnet #aspire #microservices #csharp #cloudnative #dotnetaspire
```

### Tags
```
dotnet aspire, .NET Aspire tutorial, dotnet microservices, aspire dashboard, 
service discovery dotnet, distributed tracing dotnet, cloud native dotnet, 
csharp aspire, aspire workshop, dotnet observability, aspire telemetry,
microservices local dev, dotnet 9, aspire opentelemetry, aspire service defaults
```

---

## Full Script

---

### HOOK (0:00 – 0:30)

---

*(Camera on, energy up, no intro music needed — just start talking)*

Here's what I want to show you in the next 15 minutes: a fully distributed .NET app, running locally, with a live dashboard that shows you every service, every HTTP call, every database query — and I mean *every* call — with zero YAML, zero Docker Compose file from hell, and almost no configuration.

By the end of this video, you'll have forked my workshop repo, run it with one command, and watched the whole thing light up in a browser dashboard that honestly looks too good to be real.

Let's go.

---

### WHY ASPIRE (0:30 – 2:00)

---

Here's the thing about microservices local development: it's a disaster and everyone pretends it isn't.

I have been there. You have a perfectly clean architecture — API gateway, auth service, catalog service, orders service, maybe a background worker or two. It looks great in a diagram. And then you try to run it locally, and suddenly you have six terminal windows open, you're manually editing `appsettings.json` on three projects to point at the right ports, your service discovery is "I memorized which port does what," and you're debugging a problem that's actually a race condition between services starting in the wrong order — except you have no way to *see* that because your logs are spread across six different terminals.

And that's before you even get to telemetry. Distributed tracing? In local dev? Sure, technically possible. Practically, nobody does it, because the setup cost is 45 minutes of OpenTelemetry plumbing that you never quite finish.

This is what .NET Aspire solves. Not just for the "startup" moment — for the entire inner dev loop.

Aspire is a .NET orchestration framework. You write a small project called an AppHost — it's just C# — and in it you describe all the services that make up your application. Not with YAML. Not with container manifests. With code. With a fluent API that reads almost like English. And when you run that AppHost, Aspire starts everything, wires them together with automatic service discovery, injects the right connection strings, and gives you a live dashboard in your browser showing every service, every endpoint, every log, and every distributed trace.

It's the local dev experience we all wanted and somehow never had.

The full workshop I'm going to point you to covers the whole picture — custom resources, testing, cloud deployment, the works. But right now, in the next 13 minutes, I want to show you what "everything wires together" actually looks like. With a real app.

---

### DEMO SETUP (2:00 – 4:00)

---

*(Screen share: browser open to GitHub)*

Okay. The app we're using is called Bookstore — it's a simple distributed .NET app I built specifically for this workshop. It has a frontend, a books API, an orders service, a notification worker, and it talks to a PostgreSQL database and a Redis cache. Five services, two backing infrastructure pieces. Nothing exotic, but realistic enough to feel like actual work.

First: fork the repo. Hit the link in the description, fork it to your own account, clone it locally.

*(Cut to terminal)*

Once you've cloned it, the repo structure looks like this. You've got your individual service projects, and then you've got this `AppHost` project right here. That's the Aspire orchestrator. That's the one we care about.

Before you run it, two things you need:

First, the .NET Aspire workload. If you haven't installed it, one command:

```bash
dotnet workload install aspire
```

That's it. One command, two minutes, done.

Second, you need Docker running in the background — not because we're writing Docker Compose, but because Aspire uses it to spin up PostgreSQL and Redis as containers automatically. You don't write the container config. Aspire does. But Docker needs to be there to host them.

Now. The magic:

```bash
cd src/AppHost
dotnet run
```

*(Pause for effect)*

Watch what happens. Aspire starts all five services. It boots PostgreSQL, boots Redis, resolves all the service addresses automatically, injects connection strings into every service that needs them. And then it prints a URL.

*(Open browser, navigate to the Aspire dashboard)*

That URL opens this. The Aspire dashboard.

---

### FEATURE TOUR (4:00 – 10:00)

---

#### Dashboard Overview (4:00 – 5:00)

Let me just take a moment here because the first time I saw this I genuinely said "wait, this is built in?"

Every service you declared in the AppHost shows up here. Status — running, starting, failed. The URL it's listening on. Resource usage. And right here on the right, a live log stream. Every `ILogger` call from every service feeds into this dashboard automatically. No setup. No sidecar. It just works because Aspire wires OpenTelemetry into all your services by default when you add the ServiceDefaults project — which the workshop repo already has set up.

You can click into any service and see its logs in isolation. You can filter. You can search. You can do in five seconds what used to require `grep`-ing through terminal scrollback.

And look at this — the services tab. PostgreSQL, Redis, both showing as healthy. Aspire waited for them to be ready before starting the services that depend on them. That startup ordering problem I mentioned earlier? Gone.

#### Service Discovery (5:00 – 6:30)

Now here's the part that I think doesn't get enough credit.

Open up the AppHost code. Here's what wiring the books API to the orders service looks like:

```csharp
var booksApi = builder.AddProject<Projects.BooksApi>("books-api");

var ordersService = builder.AddProject<Projects.OrdersService>("orders-service")
    .WithReference(booksApi);
```

That `.WithReference(booksApi)` — that's service discovery. That one call tells Aspire: "when the orders service starts, inject an environment variable with the current URL of the books API." Doesn't matter what port it's on. Doesn't matter if it changes between runs. The orders service just asks for the `books-api` named endpoint and gets it.

On the consuming side, in the orders service, you register the HTTP client like this:

```csharp
builder.Services.AddHttpClient<IBooksClient, BooksClient>(
    static client => client.BaseAddress = new Uri("https+http://books-api"));
```

That `https+http://books-api` — that's the service name from the AppHost. Aspire resolves it to the actual address at runtime. You never hardcode a port. You never edit a config file when something moves. It just finds it.

This is how microservices should work in local dev, and honestly, it's how they should work in production too — which is what we cover in the full course.

#### Telemetry and Distributed Traces (6:30 – 8:30)

*(Browser, navigate to traces tab in dashboard)*

Okay. This is my favorite part.

Make a request to the Bookstore frontend — add a book to your cart. Now go to the traces tab in the dashboard.

You'll see a trace for that request. Not just "the frontend handled a request." You see the *entire chain*: frontend called orders service, orders service called books API, books API queried PostgreSQL, then orders service published an event to Redis, notification worker picked it up. Every hop. Every duration. Every database query, with the actual SQL.

*(Lean forward slightly)*

This is OpenTelemetry distributed tracing, built in, running locally, from the moment you ran `dotnet run`. No Jaeger to set up. No collector to configure. No 45-minute sidecar adventure. It's just there.

When something's slow, you can see exactly where. When something fails, you can see the exact call that threw. And here's the thing that changed how I debug — you can see *timing*. Sometimes the slow part isn't what you think it is. Sometimes it's not the database query that's taking 800ms; it's the retry behavior on your HTTP client making three calls when one would do. The trace shows you that.

Click into any span and you get the attributes: HTTP method, status code, database statement, service name, trace ID that connects it to the logs. This is production-grade observability, in local development, because Aspire wires it up by default.

#### Resources and Configuration (8:30 – 10:00)

Back to the dashboard — I want to show you the resources tab.

You'll see your PostgreSQL container here, with its connection string. Your Redis instance. The configuration Aspire injected into each service. This is huge for debugging configuration problems — you can verify in the dashboard that the right connection string actually made it to the right service without `Console.WriteLine`-ing your way through startup.

Aspire also supports parameters — values you can set at run time or pull from a secrets store. So if you want to swap in a real cloud database instead of the local container, you add a parameter, reference it in the AppHost, and Aspire handles the rest. The service doesn't change. The plumbing changes.

The AppHost is your app's infrastructure-as-code — but it's C#, not YAML. You can use loops, conditions, helper methods, all of it. If you have ten services that all need the same backing store, you write a helper method and call it once. That's the power here.

---

### WHAT'S NEXT (10:00 – 12:00)

---

So what's in the full workshop?

We've covered the happy path — the default stuff Aspire gives you out of the box. The full course is where it gets interesting.

**Custom resources.** What if you need to integrate with something Aspire doesn't have a built-in resource for? Azure Service Bus. A legacy gRPC service. A third-party API with a weird startup sequence. We walk through building custom Aspire resources and integrations — so the AppHost can orchestrate *anything*, not just the services on the integration list.

**Testing distributed apps.** This is the one people don't expect to find in an Aspire course. Aspire has a testing framework — `Aspire.Hosting.Testing` — that lets you spin up your entire distributed application in an xUnit test. Not mocks. The real services, the real containers, the real wire. You write an integration test, call an endpoint on the frontend, and assert on what the backend actually did. It sounds slow. It's surprisingly fast. And it catches bugs that unit tests will never catch, because those bugs only exist when services talk to each other.

**Deployment.** `aspire publish` generates Bicep, Dockerfiles, and Kubernetes manifests from your AppHost definition. We cover what you get, what you need to customize, and how to think about the gap between local orchestration and production deployment.

**Cloud integrations.** We cover the official Azure integrations and — this is the one I'm personally most excited about — we cover multi-cloud patterns, including how to wire in AWS services via the community integrations. Because not everyone is running 100% Azure, and Aspire is a lot more portable than people realize.

Each of those is a module with working code, exercises, and a demo app that builds on everything that came before it. Link is in the description.

---

### CALL TO ACTION (12:00 – 12:30)

---

That's the 15-minute version. Fork the repo — link is in the description — run the AppHost, and see it yourself. The moment it clicks is the moment you open that dashboard and realize your entire distributed app is right there in one screen and you haven't written a single line of infrastructure config.

If you want to go deeper, the full course is linked below. If you're watching this before launch, you're in luck — there's an early-bird discount for the first 100 enrollments, and I mean it when I say the testing module alone is worth the price.

Subscribe if you want more .NET content — I post on distributed systems, AI engineering, and occasionally complaining about YAML. Hit the bell if you want the notification when the next Aspire video drops, because I'm building a whole series on this.

See you in the next one.

---

## Production Notes

| Section | Screen | Notes |
|---------|--------|-------|
| Hook | Face cam | High energy, no lag — cut anything over 30s |
| Why Aspire | Face cam / slides | Keep punchy — one slide per pain point max |
| Demo Setup | Screen share: GitHub + terminal | Show fork flow live, real terminal |
| Dashboard Tour | Screen share: browser | Use the workshop Bookstore app running live |
| Service Discovery | Screen share: VS Code + browser | Show AppHost code alongside dashboard |
| Telemetry | Screen share: traces tab | Pre-generate some traffic so traces are populated |
| What's Next | Slides or face cam with b-roll | Quick cuts, course landing page preview |
| CTA | Face cam | Direct eye contact, energy up |

**Pre-record checklist:**
- [ ] Workshop repo forked and running locally (confirm `dotnet run` works from scratch)
- [ ] Dashboard bookmarked and pre-loaded
- [ ] Some traffic pre-generated in Bookstore for trace demo
- [ ] Course landing page URL ready for overlay
- [ ] Thumbnail designed (deep navy + cyan per brand guide, bold "15 MIN" typography)

---

*Script drafted by Troi for issue #737 — Aspire Workshop content monetization*  
*Voice: Tamir Dresher — conversational, energetic, no buzzwords*
