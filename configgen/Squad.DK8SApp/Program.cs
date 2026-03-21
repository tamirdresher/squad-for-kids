using ConfigurationGeneration.Dk8sApplication;
using ConfigurationGeneration.Generator;

namespace Squad.DK8SApp;

/// <summary>
/// Entry point for the Squad DK8S ConfigGen project.
///
/// Running this executable causes the ConfigGen framework to generate
/// Helm values, EV2 deployment manifests, and app-settings configuration
/// for all Squad agent DK8SApplications (Picard, B'Elanna, Worf, Ralph).
///
/// Usage:
///   dotnet run -- [--output-path &lt;path&gt;]
///
/// Generated output is placed under:
///   configgen/Squad.DK8SApp/generated/
/// </summary>
internal static class Program
{
    private static async Task Main(string[] args)
    {
        // Configure output paths relative to the repository root so generated
        // artefacts land in a consistent location regardless of where the
        // binary is run from.
        var repoRoot = GetRepositoryRoot();
        var outputBase = Path.Combine(repoRoot, "configgen", "Squad.DK8SApp", "generated");

        var builder = Generator.CreateBuilder<SquadTopology>(config =>
        {
            config.Ev2Settings = new Ev2BuilderSettings
            {
                Ev2OutputAbsoluteBasePath = Path.Combine(outputBase, "ev2"),
            };

            config.ManifestSettings = new ManifestBuilderSettings
            {
                ManifestOutputAbsolutePath  = Path.Combine(outputBase, "manifest"),
                ManifestSubjectPrefixOverride = "squad",
            };
        });

        // Register all Squad agents as DK8SApplications.
        // AddSimpleDk8sApplication wires up the K8SService/CronJob into the
        // EV2 deployment pipeline and generates Helm release manifests.
        builder.Resources.AddSimpleDk8sApplication<SquadTopology>(app =>
        {
            app.Subject   = new ResourceSubject("squad-agents");
            app.Namespace = Agents.SquadAgentDefaults.Namespace;

            // Helm release name prefix — individual agents use their
            // NameOverride as the release name suffix.
            app.ReleaseName = "squad";
        });

        using var host = builder.Build();
        await host.RunAsync();
    }

    /// <summary>
    /// Walks up from the executable location until it finds the directory
    /// containing a <c>.git</c> folder, returning that as the repository root.
    /// </summary>
    private static string GetRepositoryRoot()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            if (Directory.Exists(Path.Combine(dir.FullName, ".git")))
                return dir.FullName;
            dir = dir.Parent;
        }

        // Fallback: current working directory
        return Directory.GetCurrentDirectory();
    }
}
