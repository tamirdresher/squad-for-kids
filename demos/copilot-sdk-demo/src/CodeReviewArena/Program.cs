// ═══════════════════════════════════════════════════════════════════════════
//  AI Code Review Arena  ·  Program.cs
//  Two AI judges review your code simultaneously, debate each other's findings,
//  then produce a consensus verdict — all live-streamed in your terminal.
// ═══════════════════════════════════════════════════════════════════════════

using Azure;
using Azure.AI.Inference;
using CodeReviewArena.Arena;
using CodeReviewArena.Judges;
using CodeReviewArena.Tools;
using CodeReviewArena.UI;
using Microsoft.Extensions.AI;
using Spectre.Console;

// ── Configuration ────────────────────────────────────────────────────────────
var githubToken = Environment.GetEnvironmentVariable("GITHUB_TOKEN")
    ?? throw new InvalidOperationException(
        "Set GITHUB_TOKEN to your GitHub PAT (no scopes required for GitHub Models).");

var model = Environment.GetEnvironmentVariable("COPILOT_MODEL") ?? "gpt-4o-mini";
var githubModelsEndpoint = new Uri("https://models.inference.ai.azure.com");

// ── Parse CLI arguments ───────────────────────────────────────────────────────
string? codeFile = null;
string? inlineCode = null;
string context = "Review this C# code snippet";
string judgeMode = "standard"; // standard | security | all
bool showToolDemo = false; // --tools: run tool-calling demo before the arena

for (int i = 0; i < args.Length; i++)
{
    switch (args[i])
    {
        case "--file" or "-f" when i + 1 < args.Length:
            codeFile = args[++i];
            break;
        case "--code" or "-c" when i + 1 < args.Length:
            inlineCode = args[++i];
            break;
        case "--context" or "-x" when i + 1 < args.Length:
            context = args[++i];
            break;
        case "--mode" or "-m" when i + 1 < args.Length:
            judgeMode = args[++i];
            break;
        case "--tools" or "-t":
            showToolDemo = true;
            break;
    }
}

// ── Build IChatClient via Azure.AI.Inference + Microsoft.Extensions.AI ───────
IChatClient CreateChatClient() =>
    new ChatCompletionsClient(
        githubModelsEndpoint,
        new AzureKeyCredential(githubToken))
        .AsChatClient(model);

// ── Select Judges based on mode ───────────────────────────────────────────────
var selectedPersonalities = judgeMode switch
{
    "security" => new[] { Personalities.StrictArchitect, Personalities.SecurityHawk },
    "all" => new[] { Personalities.StrictArchitect, Personalities.PragmaticAdvocate },
    _ => new[] { Personalities.StrictArchitect, Personalities.PragmaticAdvocate }
};

var judges = selectedPersonalities
    .Select(p => new Judge(CreateChatClient(), p))
    .ToArray();

// ── Load code to review ───────────────────────────────────────────────────────
string codeSnippet;

if (codeFile != null && File.Exists(codeFile))
{
    codeSnippet = await File.ReadAllTextAsync(codeFile);
    context = $"File: {Path.GetFileName(codeFile)}";
}
else if (inlineCode != null)
{
    codeSnippet = inlineCode;
}
else if (!Console.IsInputRedirected && args.Length == 0)
{
    // Interactive mode — load a built-in sample for demo purposes
    codeSnippet = BuiltInSamples.BuggyUserService;
    context = "UserService.cs — authentication and user management";
    AnsiConsole.MarkupLine("[dim]No code provided — using built-in demo sample.[/]");
    AnsiConsole.MarkupLine("[dim]Usage: dotnet run -- --file MyCode.cs  |  --code \"...\"  |  --tools (add tool-calling demo)[/]");
}
else if (Console.IsInputRedirected)
{
    // Pipe mode: cat MyFile.cs | dotnet run
    codeSnippet = await Console.In.ReadToEndAsync();
}
else
{
    AnsiConsole.MarkupLine("[red]Usage:[/] dotnet run -- --file <path.cs>  OR  --code \"<snippet>\"");
    return 1;
}

// ── Run the Arena ─────────────────────────────────────────────────────────────
var display = new ArenaDisplay();
display.RenderBanner();
display.RenderCodePreview(codeSnippet, context);

using var cts = new CancellationTokenSource();
Console.CancelKeyPress += (_, e) => { e.Cancel = true; cts.Cancel(); };

// ── Optional: Tool Calling Demo (--tools flag) ─────────────────────────────
if (showToolDemo)
{
    var toolDemo = new ToolCallDemo(CreateChatClient());
    await toolDemo.RunAsync(codeSnippet, cts.Token);

    AnsiConsole.MarkupLine("[dim]─── Now handing off to the full Arena for the debate ───[/]");
    AnsiConsole.WriteLine();
}

try
{
    var orchestrator = new ArenaOrchestrator(judges, display);
    var result = await orchestrator.RunAsync(codeSnippet, context, cts.Token);
    return 0;
}
catch (OperationCanceledException)
{
    AnsiConsole.MarkupLine("\n[yellow]Arena cancelled.[/]");
    return 1;
}
catch (Exception ex)
{
    AnsiConsole.WriteException(ex, ExceptionFormats.ShortenEverything);
    return 2;
}

// ── Built-in sample code (for zero-config demo) ───────────────────────────────
static class BuiltInSamples
{
    public const string BuggyUserService = """
        using System.Data.SqlClient;

        public class UserService
        {
            private readonly string _connectionString;

            public UserService(string connectionString)
            {
                _connectionString = connectionString;
            }

            // Authenticate user and return JWT token
            public string Login(string username, string password)
            {
                using var conn = new SqlConnection(_connectionString);
                conn.Open();

                // Build query directly from user input
                var query = $"SELECT * FROM Users WHERE Username='{username}' AND Password='{password}'";
                using var cmd = new SqlCommand(query, conn);
                using var reader = cmd.ExecuteReader();

                if (reader.Read())
                {
                    var userId = reader["Id"].ToString();
                    var role = reader["Role"].ToString();

                    // Generate token with 10-year expiry, signed with hardcoded key
                    var token = GenerateJwt(userId!, role!, TimeSpan.FromDays(3650), "super-secret-key-123");
                    return token;
                }

                return string.Empty; // Return empty string on failure (not exception)
            }

            public void DeleteUser(int userId)
            {
                using var conn = new SqlConnection(_connectionString);
                conn.Open();
                // Hard delete, no soft-delete, no audit log
                var cmd = new SqlCommand($"DELETE FROM Users WHERE Id={userId}", conn);
                cmd.ExecuteNonQuery();
            }

            public List<User> GetAllUsers()
            {
                var users = new List<User>();
                using var conn = new SqlConnection(_connectionString);
                conn.Open();
                using var cmd = new SqlCommand("SELECT * FROM Users", conn);
                using var reader = cmd.ExecuteReader();
                while (reader.Read())
                {
                    users.Add(new User
                    {
                        Id = (int)reader["Id"],
                        Username = reader["Username"].ToString()!,
                        Password = reader["Password"].ToString()!, // Returning plaintext passwords!
                        Role = reader["Role"].ToString()!,
                        Email = reader["Email"].ToString()!
                    });
                }
                return users;
            }

            // Cache of all admin tokens (never expires, never cleared)
            private static readonly Dictionary<string, string> _tokenCache = new();

            public string GetAdminToken(string adminId)
            {
                if (!_tokenCache.ContainsKey(adminId))
                {
                    _tokenCache[adminId] = GenerateJwt(adminId, "admin", TimeSpan.FromDays(3650), "super-secret-key-123");
                }
                return _tokenCache[adminId];
            }

            private static string GenerateJwt(string userId, string role, TimeSpan expiry, string secret)
            {
                // Simplified for brevity — real implementation uses Jose/JWT library
                var payload = $"{userId}:{role}:{DateTime.UtcNow.Add(expiry):O}";
                return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(payload + "." + secret));
            }
        }

        public record User(int Id = 0, string Username = "", string Password = "", string Role = "", string Email = "");
        """;
}
