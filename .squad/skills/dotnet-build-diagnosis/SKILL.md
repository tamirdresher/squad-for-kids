# Skill: .NET Build Failure Diagnosis

**Confidence:** high
**Domain:** dotnet, build-systems, dependency-management
**Last validated:** 2026-03-08

## Context

When a .NET project fails to build, systematic diagnosis identifies the root cause and determines if the blocker is fixable or requires escalation. This skill documents the process used to diagnose the Functions project build failure (64 errors).

## Diagnostic Process

### 1. Run a clean build with full output

```bash
cd {project-directory}
dotnet build
```

**Why:** Full output shows all errors, not just the first few. Note the error count and build time.

### 2. Categorize the errors

Group errors by type:
- **Missing namespace/assembly references:** `error CS0234: The type or namespace name '...' does not exist`
- **Missing types:** `error CS0246: The type or namespace name '...' could not be found`
- **Duplicate definitions:** `error CS0101: The namespace '...' already contains a definition for '...'`
- **Undefined names:** `error CS0103: The name '...' does not exist in the current context`

### 3. Identify missing packages

Common patterns:

| Error Pattern | Missing Package | How to Fix |
|---------------|----------------|------------|
| `Microsoft.AspNetCore` not found | `Microsoft.AspNetCore.App` framework reference | Add `<FrameworkReference Include="Microsoft.AspNetCore.App" />` to .csproj |
| `Microsoft.Azure.WebJobs` not found | Azure Functions SDK | Add `<PackageReference Include="Microsoft.NET.Sdk.Functions" Version="..." />` |
| `JsonPropertyName` not found | System.Text.Json | Usually included with .NET 8+, check TargetFramework |
| `HttpRequest`, `IActionResult` not found | ASP.NET Core types | Add `<FrameworkReference Include="Microsoft.AspNetCore.App" />` |

### 4. Check the .csproj file

Look for:
- **SDK attribute:** `<Project Sdk="Microsoft.NET.Sdk">` vs `<Project Sdk="Microsoft.NET.Sdk.Web">`
- **TargetFramework:** Should match the runtime (e.g., `net8.0`)
- **PackageReferences:** Are critical packages present?
- **FrameworkReferences:** ASP.NET Core apps need `<FrameworkReference Include="Microsoft.AspNetCore.App" />`

### 5. Restore packages

```bash
dotnet restore
dotnet build --no-restore
```

**Why:** Sometimes package restore is stale or corrupted.

### 6. Check for duplicate files

If `error CS0101: already contains a definition`, search for the duplicate:

```bash
grep -r "class {ClassName}" {project-directory}
```

**Fix:** Remove or rename one of the duplicate definitions.

## Example: Functions Project (Issue #119)

**Symptoms:**
- 64 build errors
- Build fails in 8.2 seconds
- Missing Azure Functions SDK dependencies

**Diagnosis:**
1. Ran `dotnet build` → 64 errors
2. Categorized errors:
   - **48 errors:** Missing System.Text.Json attributes (`JsonPropertyNameAttribute`)
   - **10 errors:** Missing Azure Functions types (`HttpRequest`, `FunctionName`, `HttpTrigger`)
   - **4 errors:** Missing ASP.NET Core types (`IActionResult`, `Microsoft.AspNetCore`)
   - **2 errors:** Duplicate `ControlInfo` class definition

**Root Cause:**
- Functions project .csproj is missing Azure Functions SDK package references
- Likely needs `Microsoft.NET.Sdk.Functions` NuGet package
- May need `<FrameworkReference Include="Microsoft.AspNetCore.App" />`
- Duplicate `ControlInfo` class needs to be deduplicated

**Outcome:**
- Issue #119 remains blocked on Functions build fix
- Recommended creating new issue: "Fix Functions project build errors"
- Documented specific package needs for quick resolution

## When to Use This Skill

- A .NET project fails to build with compilation errors
- Investigating why a project reference cannot be added (dependency must build first)
- Determining if a build blocker is fixable or requires escalation
- Creating detailed bug reports for build failures

## Key Insight

**Distinguish between CI/build system issues and source code/dependency issues:**
- CI issue: Workflows don't run, runners not available → Fix GitHub Actions settings
- Build issue: Code compiles but fails → Fix dependencies, package references, or code errors

In issue #119, the confusion was that #110 (CI runners fixed) was thought to fix the Functions build, but the Functions project has deeper dependency issues unrelated to CI.
