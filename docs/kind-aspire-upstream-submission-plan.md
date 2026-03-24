# Kind Aspire — CommunityToolkit/Aspire Upstream Submission Plan

**Issue:** [#1428 — Submit PR to CommunityToolkit/Aspire](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1428)  
**Epic:** [#1422 — Public Aspire.Hosting.Kind Resource](https://github.com/tamirdresher_microsoft/tamresearch1/issues/1422)  
**Package:** `CommunityToolkit.Aspire.Hosting.Kind`  
**Target repo:** https://github.com/CommunityToolkit/Aspire  
**Prepared by:** Seven (Research & Docs)  
**Date:** 2026-03-24

---

## Overview

This document is the complete submission package plan for contributing a public .NET Aspire hosting integration for Kind (Kubernetes-in-Docker) clusters to the CommunityToolkit/Aspire community repository.

Kind fills a real gap in the Aspire ecosystem: `Aspire.Hosting.Kubernetes` deploys *to* existing Kubernetes clusters (manifest generation). The Kind integration creates *ephemeral* Kubernetes clusters *as Aspire resources* — ideal for local testing, CI pipelines, and developer sandboxes.

---

## ⚠️ Critical Gate: Open Issue First

**Before writing a single line of upstream code, open a Feature Request issue in CommunityToolkit/Aspire.**

From the PR template (verbatim):
> *Every PR needs to have a linked issue and have previously been approved. PRs that don't follow this will be rejected.*

**Action required:**
1. Navigate to https://github.com/CommunityToolkit/Aspire/issues/new?template=feature_proposal.yml
2. Title: `Add Hosting.Kind integration for ephemeral Kubernetes-in-Docker clusters`
3. Include the usage example below, and reference Andrey Noskov as original author
4. Wait for maintainer approval before submitting the PR
5. Record the upstream issue number here once created: `CommunityToolkit/Aspire#____`

---

## Step-by-Step Submission Plan

### Phase 1: Prerequisites (Before Touching the Upstream Repo)

| # | Task | Owner | Status |
|---|------|-------|--------|
| 1.1 | All three sub-issues merged: #1425 (core), #1426 (tests), #1427 (docs) | Data / Seven | ⬜ Pending sub-PRs |
| 1.2 | Open feature request issue in CommunityToolkit/Aspire | Tamir / Andrey | ⬜ Not started |
| 1.3 | Get maintainer approval on the upstream issue | Maddy Montaquila (PM contact) | ⬜ Not started |
| 1.4 | Fork CommunityToolkit/Aspire into the contributing account | Andrey Noskov (author) | ⬜ Not started |
| 1.5 | Create feature branch `feature/hosting-kind` in the fork | Author | ⬜ Not started |
| 1.6 | Sync fork with latest upstream `main` | Author | ⬜ Not started |

### Phase 2: File Structure Creation

The PR must add the following files to the upstream repo:

```
CommunityToolkit/Aspire/
├── src/
│   └── CommunityToolkit.Aspire.Hosting.Kind/
│       ├── CommunityToolkit.Aspire.Hosting.Kind.csproj   ← NEW
│       ├── KindClusterResource.cs                         ← NEW (adapt from internal)
│       ├── KindClusterLifecycleHook.cs                    ← NEW (adapt from internal)
│       ├── KindBuilderExtensions.cs                       ← NEW (adapt from internal)
│       ├── KindToolImageTags.cs                           ← NEW (version pinning)
│       ├── README.md                                      ← NEW
│       └── api/
│           └── CommunityToolkit.Aspire.Hosting.Kind.cs   ← AUTO-GENERATED (see below)
├── tests/
│   └── CommunityToolkit.Aspire.Hosting.Kind.Tests/
│       ├── CommunityToolkit.Aspire.Hosting.Kind.Tests.csproj  ← NEW
│       ├── KindClusterResourceTests.cs                         ← Unit tests
│       └── KindIntegrationTests.cs                            ← Integration tests
├── examples/
│   └── kind.AppHost/
│       ├── kind.AppHost.csproj                            ← NEW
│       └── Program.cs                                     ← NEW
└── .github/workflows/tests.yml                            ← MODIFY (add to matrix)
```

Plus: update root `README.md` to add Kind to the integration table.

### Phase 3: Source Adaptation Checklist

When adapting from internal (idk8s-infrastructure) to public:

- [ ] **Strip internal-only references** — Remove IMDS emulator, NHA/NRS service references
- [ ] **Namespaces** — Extension methods in `Aspire.Hosting`, resources in `Aspire.Hosting.ApplicationModel`
- [ ] **Sanitize kubeconfig handling** — No hardcoded paths, use temp directories
- [ ] **Remove internal NuGet dependencies** — Only public packages allowed
- [ ] **CLI path detection** — Auto-detect `kind` binary on PATH, configurable fallback
- [ ] **Docker prerequisite** — Clear error message if Docker not running
- [ ] **Image tag pinning** — Use `sha256` digest or `major.minor` tag format (not `latest`)
- [ ] **XML docs** — Every public API must have `<summary>`, `<param>`, `<returns>` docs

### Phase 4: .csproj Configuration

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Description>An Aspire hosting integration for Kind (Kubernetes-in-Docker) clusters. 
    Enables creating and managing ephemeral local Kubernetes clusters as Aspire resources 
    for local development and testing workflows.</Description>
    <AdditionalPackageTags>kind kubernetes k8s docker hosting</AdditionalPackageTags>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting" />
  </ItemGroup>
</Project>
```

### Phase 5: API Surface File (api/ folder)

The `api/CommunityToolkit.Aspire.Hosting.Kind.cs` file is auto-generated but must be committed. Run:

```sh
dotnet build && dotnet publish
# Then run the API compat tool to generate the file
./eng/testing/generate-api-surface.sh  # (check repo for exact script name)
```

Expected API surface:
```csharp
namespace Aspire.Hosting
{
    public static partial class KindBuilderExtensions
    {
        public static IResourceBuilder<KindClusterResource> AddKindCluster(
            this IDistributedApplicationBuilder builder, 
            string name,
            string? kindConfigPath = null) { throw null; }

        public static IResourceBuilder<KindClusterResource> WithKubernetesVersion(
            this IResourceBuilder<KindClusterResource> builder, 
            string version) { throw null; }

        public static IResourceBuilder<KindClusterResource> WithNodeCount(
            this IResourceBuilder<KindClusterResource> builder, 
            int nodeCount) { throw null; }
    }
}

namespace Aspire.Hosting.ApplicationModel
{
    public sealed partial class KindClusterResource : Resource, IResourceWithConnectionString
    {
        public KindClusterResource(string name) : base(default!) { }
        public ReferenceExpression ConnectionStringExpression { get { throw null; } }
        public ValueTask<string?> GetConnectionStringAsync(CancellationToken cancellationToken = default) { throw null; }
    }
}
```

### Phase 6: README.md (for NuGet package)

Template (adapt from Minio/Ollama pattern):

```markdown
# CommunityToolkit.Aspire.Hosting.Kind

Provides extension methods and resource definitions for the .NET Aspire AppHost 
to support running [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) clusters.

## Prerequisites

- [Docker](https://docker.com) running locally
- [Kind CLI](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed

## Getting Started

### Install the package

```dotnetcli
dotnet add package CommunityToolkit.Aspire.Hosting.Kind
```

### Example usage

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("my-cluster");

var myService = builder.AddProject<Projects.MyService>()
                       .WithReference(cluster);  // receives kubeconfig as env var

builder.Build().Run();
```

## Additional Information

https://learn.microsoft.com/dotnet/aspire/community-toolkit/hosting-kind

## Feedback & contributing

https://github.com/CommunityToolkit/Aspire
```

### Phase 7: Tests

#### Unit Tests (`KindClusterResourceTests.cs`)
```csharp
[Fact]
public void AddKindCluster_CreatesResourceWithCorrectName()
{
    var builder = DistributedApplication.CreateBuilder();
    builder.AddKindCluster("test-cluster");
    using var app = builder.Build();
    var model = app.Services.GetRequiredService<DistributedApplicationModel>();
    var resource = model.Resources.OfType<KindClusterResource>().Single();
    Assert.Equal("test-cluster", resource.Name);
}
```

#### Integration Tests (`KindIntegrationTests.cs`)
```csharp
[RequiresDocker]
public class KindIntegrationTests : IClassFixture<AspireIntegrationTestFixture<Projects.kind_AppHost>>
{
    [Fact]
    public async Task ClusterStartsAndBecomesHealthy()
    {
        await fixture.App.WaitForTextAsync("nodes", "my-cluster")
            .WaitAsync(TimeSpan.FromMinutes(4));
        // assert kubeconfig is accessible
    }
}
```

**CI note:** Integration tests require Docker and must have `[RequiresDocker]` — they will only run on Linux GitHub Actions runners (Windows runners don't support Linux containers).

### Phase 8: CI Pipeline Update

Edit `.github/workflows/tests.yml` — add `CommunityToolkit.Aspire.Hosting.Kind.Tests` to the test matrix. The exact format can be generated by running:

```sh
./eng/testing/generate-test-list-for-workflow.sh
```

Copy the output into `tests.yml`.

### Phase 9: Root README.md Update

Add a row to the integration table in the root `README.md`:

| Integration | NuGet | Description |
|------------|-------|-------------|
| `Hosting.Kind` | [![NuGet](...)](#) | Ephemeral Kubernetes-in-Docker clusters |

### Phase 10: Submit the PR

---

## CommunityToolkit/Aspire Contribution Requirements Checklist

From the official contributing guide and PR template:

### Process Requirements
- [ ] Feature request issue opened and approved in CommunityToolkit/Aspire (REQUIRED before PR)
- [ ] PR created from a feature branch in a fork (NOT from `main`)
- [ ] Based off latest upstream `main` (no stale base)
- [ ] No merge commits (rebase only)
- [ ] "Allow edits by maintainers" checkbox enabled on the PR
- [ ] One PR = One issue (no bundling unrelated changes)

### Code Quality Requirements
- [ ] Every public API has full XML documentation (`<summary>`, `<param>`, `<returns>`)
- [ ] Code follows `.editorconfig` style conventions
- [ ] No breaking changes
- [ ] `Nullable` enabled in csproj
- [ ] `ImplicitUsings` enabled in csproj

### Integration-Specific Requirements
- [ ] Project in `src/` with `CommunityToolkit.Aspire.Hosting.Kind` name
- [ ] Extension methods in `Aspire.Hosting` namespace
- [ ] Resources in `Aspire.Hosting.ApplicationModel` namespace
- [ ] `<Description>` in csproj (≤4000 chars total for NuGet)
- [ ] `<AdditionalPackageTags>` includes `hosting` tag + relevant tags
- [ ] `README.md` in the package folder
- [ ] `api/` folder with auto-generated API surface file committed
- [ ] Example AppHost in `examples/` directory
- [ ] Unit tests in `tests/` with correct naming convention
- [ ] Integration tests using `AspireIntegrationTestFixture<TExampleAppHost>`
- [ ] Docker-dependent tests marked with `[RequiresDocker]`
- [ ] `tests.yml` updated with new test project in matrix

### Documentation Requirements
- [ ] Root `README.md` updated with new integration in table
- [ ] PR to `microsoft/aspire.dev` for full public docs (can be follow-up)

### Versioning
- Version follows Aspire minor version parity (e.g., 9.x.y if Aspire is 9.x)
- Patch version is independent — no need to bump other packages

---

## Draft PR Description (for CommunityToolkit/Aspire)

```markdown
**Closes #<upstream-issue-number>**

## Summary

Adds `CommunityToolkit.Aspire.Hosting.Kind` — a new hosting integration that creates and 
manages ephemeral [Kind](https://kind.sigs.k8s.io/) (Kubernetes-in-Docker) clusters as 
first-class .NET Aspire resources.

## Motivation

While `Aspire.Hosting.Kubernetes` handles deployment *to* existing clusters, there was no 
Aspire resource for creating ephemeral local clusters *as part of* an Aspire application. 
This fills the gap for:

- **Local Kubernetes testing** without a cloud subscription
- **CI pipelines** needing isolated K8s environments per test run
- **Developer sandboxes** where Docker Compose isn't sufficient

This integration has been validated internally (thanks to Andrey Noskov, Craig Treasure, 
and the idk8s team) and is ready for the community.

## What's Included

- `KindClusterResource` — represents an ephemeral Kind cluster in the Aspire model
- `KindClusterLifecycleHook` — manages cluster create/delete lifecycle
- `KindBuilderExtensions` — fluent API (`AddKindCluster`, `WithNodeCount`, etc.)
- Full unit and integration test coverage
- Example AppHost demonstrating cluster + service deployment
- README with getting started guide

## Usage

```csharp
var builder = DistributedApplication.CreateBuilder(args);

var cluster = builder.AddKindCluster("dev-cluster")
    .WithNodeCount(3)
    .WithKubernetesVersion("v1.29.0");

builder.AddProject<Projects.MyApi>()
       .WithReference(cluster);

builder.Build().Run();
```

## Co-author

This integration is co-authored by Andrey Noskov (@andreyn), the original architect of 
this pattern within the idk8s/Celestial platform.

## PR Checklist

- [x] Created a feature/dev branch in fork
- [x] Based off latest main branch
- [x] No merge commits
- [x] Docs written (README.md in package folder)
- [x] NuGet description added to csproj
- [x] Tests added (unit + integration)
- [x] No breaking changes
- [x] Every new API has full XML docs
- [x] Code follows style conventions
```

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Maintainers reject Kind as "too environment-specific" | Medium | High | Pre-approval via upstream issue; Maddy Montaquila as PM contact |
| CI Docker support gaps (GitHub Actions Windows runner) | High | Medium | All container-dependent tests marked `[RequiresDocker]`, Linux runner only |
| `kind` CLI not in PATH in CI | High | Medium | Document prerequisite clearly; add CI setup step |
| Internal code sanitization misses something | Medium | High | Code review against sub-PR #1441/#1444/#1448 before upstream |
| Version mismatch with Aspire SDK version in upstream | Low | Medium | Check `global.json` and `Directory.Packages.props` in upstream before building |

---

## Key Contacts

| Role | Person |
|------|--------|
| Original author / co-author | Andrey Noskov (andreyn) |
| Aspire PM | Maddy Montaquila |
| Internal validator | Craig Treasure (Principal SDE, IDM Core Infra) |
| Community Toolkit maintainer (CoC contact) | Aaron Powell |

---

## References

- [CommunityToolkit/Aspire CONTRIBUTING.md](https://github.com/CommunityToolkit/Aspire/blob/main/CONTRIBUTING.md)
- [create-integration.md](https://github.com/CommunityToolkit/Aspire/blob/main/docs/create-integration.md)
- [diagnostics.md](https://github.com/CommunityToolkit/Aspire/blob/main/docs/diagnostics.md)
- [versioning.md](https://github.com/CommunityToolkit/Aspire/blob/main/docs/versioning.md)
- [PR template](https://github.com/CommunityToolkit/Aspire/blob/main/.github/PULL_REQUEST_TEMPLATE.md)
- [Minio integration (template)](https://github.com/CommunityToolkit/Aspire/tree/main/src/CommunityToolkit.Aspire.Hosting.Minio)
- [Ollama integration (template)](https://github.com/CommunityToolkit/Aspire/tree/main/src/CommunityToolkit.Aspire.Hosting.Ollama)
- Kind CLI: https://kind.sigs.k8s.io/
- Internal Epic: https://github.com/tamirdresher_microsoft/tamresearch1/issues/1422
