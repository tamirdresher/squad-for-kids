using Microsoft.Extensions.AI;
using System.ComponentModel;
using System.Text.RegularExpressions;

namespace CodeReviewArena.Tools;

/// <summary>
/// AI-callable tool: statically analyses the code snippet and returns structured metrics.
/// Demonstrates Microsoft.Extensions.AI tool/function-calling — the AI invokes this
/// automatically when it needs objective data to support its review.
/// </summary>
public static class CodeMetricsTool
{
    // ── Tool definition ───────────────────────────────────────────────────────

    [Description("Analyse a C# code snippet and return objective metrics: line count, cyclomatic complexity estimate, " +
                 "detected code smells, and a list of security-sensitive API calls found.")]
    public static CodeMetrics AnalyzeCode(
        [Description("The full C# source code to analyse")] string csharpCode)
    {
        var lines = csharpCode.Split('\n');
        var nonBlank = lines.Count(l => !string.IsNullOrWhiteSpace(l));

        // Cyclomatic complexity proxy: count branching keywords
        var branches = CountKeywords(csharpCode, "if", "else", "for", "foreach", "while", "case", "catch", "&&", "||", "??");
        var cyclomaticEstimate = 1 + branches;

        // Detect common smell patterns
        var smells = DetectSmells(csharpCode);

        // Detect security-sensitive APIs
        var securityHotspots = DetectSecurityHotspots(csharpCode);

        // Rough nesting depth
        int maxDepth = EstimateMaxNestingDepth(csharpCode);

        // Method count
        int methodCount = Regex.Matches(csharpCode,
            @"\b(public|private|protected|internal|static)\s+[\w<>\[\]]+\s+\w+\s*\(", RegexOptions.Compiled).Count;

        return new CodeMetrics(
            TotalLines: lines.Length,
            NonBlankLines: nonBlank,
            EstimatedCyclomaticComplexity: cyclomaticEstimate,
            MaxNestingDepth: maxDepth,
            MethodCount: methodCount,
            CodeSmells: smells.ToArray(),
            SecurityHotspots: securityHotspots.ToArray()
        );
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static int CountKeywords(string code, params string[] keywords) =>
        keywords.Sum(kw =>
        {
            int count = 0;
            int idx = 0;
            while ((idx = code.IndexOf(kw, idx, StringComparison.Ordinal)) >= 0)
            {
                count++;
                idx += kw.Length;
            }
            return count;
        });

    private static List<string> DetectSmells(string code)
    {
        var smells = new List<string>();

        if (code.Contains("Thread.Sleep", StringComparison.OrdinalIgnoreCase))
            smells.Add("Thread.Sleep detected — blocks thread pool; prefer async/await with Task.Delay");

        if (code.Contains(".Result", StringComparison.Ordinal) || code.Contains(".Wait()", StringComparison.Ordinal))
            smells.Add("Blocking on async (.Result / .Wait()) — deadlock risk in sync-over-async pattern");

        if (Regex.IsMatch(code, @"\bnew\s+\w+\s*\(.*\)\s*;", RegexOptions.None) &&
            !code.Contains("using ", StringComparison.Ordinal) && code.Contains("Stream", StringComparison.Ordinal))
            smells.Add("Possible undisposed Stream/resource — missing 'using' statement");

        if (Regex.IsMatch(code, @"catch\s*\(\s*Exception\s*\)", RegexOptions.None) &&
            !code.Contains("throw;", StringComparison.Ordinal))
            smells.Add("Swallowing exceptions — catch(Exception) without re-throw loses stack trace");

        if (code.Contains("DateTime.Now", StringComparison.Ordinal))
            smells.Add("DateTime.Now — time-zone sensitive; prefer DateTime.UtcNow in server-side code");

        if (Regex.IsMatch(code, @"string\s+\w+\s*=\s*""(password|secret|key|token|api_key)""\s*;",
            RegexOptions.IgnoreCase))
            smells.Add("Hardcoded credential literal detected");

        var longMethods = Regex.Matches(code,
            @"\b(?:public|private|protected)\s+\S+\s+(\w+)\s*\([^)]*\)\s*\{",
            RegexOptions.Compiled);
        if (longMethods.Count > 0)
        {
            var totalLength = code.Length;
            if (totalLength / Math.Max(longMethods.Count, 1) > 500)
                smells.Add("Methods appear long (>500 chars average) — consider decomposing");
        }

        return smells;
    }

    private static List<string> DetectSecurityHotspots(string code)
    {
        var hotspots = new List<string>();

        if (Regex.IsMatch(code, @"SqlCommand|SqlConnection|DbCommand", RegexOptions.IgnoreCase))
        {
            if (Regex.IsMatch(code, @"\$""|String\.Format|""\s*\+", RegexOptions.None))
                hotspots.Add("SQL INJECTION: Raw SQL built with string interpolation/concatenation");
            else
                hotspots.Add("ADO.NET direct SQL — verify parameterised queries are used");
        }

        if (Regex.IsMatch(code, @"Process\.Start|Shell\.Execute", RegexOptions.IgnoreCase))
            hotspots.Add("COMMAND INJECTION: Process.Start with user-controlled input");

        if (Regex.IsMatch(code, @"Path\.Combine|File\.ReadAll|File\.WriteAll", RegexOptions.IgnoreCase) &&
            Regex.IsMatch(code, @"\bfilename\b|\bpath\b|\bfilePath\b", RegexOptions.IgnoreCase))
            hotspots.Add("PATH TRAVERSAL: User-controlled path used with file APIs — missing canonicalisation");

        if (Regex.IsMatch(code, @"Convert\.FromBase64String|Convert\.ToBase64String", RegexOptions.IgnoreCase) &&
            code.Contains("secret", StringComparison.OrdinalIgnoreCase))
            hotspots.Add("WEAK CRYPTO: Base64 is encoding, not encryption — rolling your own crypto");

        if (Regex.IsMatch(code, @"MD5|SHA1(?!2)", RegexOptions.None))
            hotspots.Add("WEAK HASH: MD5/SHA1 are cryptographically broken for security purposes");

        if (Regex.IsMatch(code, @"[Pp]assword.*=.*""[^""]{3,}""", RegexOptions.None))
            hotspots.Add("HARDCODED PASSWORD: Credential literal in source code");

        if (Regex.IsMatch(code, @"Dictionary<string,\s*string>.*[Tt]oken|_tokenCache", RegexOptions.None))
            hotspots.Add("TOKEN LEAKAGE RISK: Static/in-memory token cache without TTL or size bound");

        return hotspots;
    }

    private static int EstimateMaxNestingDepth(string code)
    {
        int depth = 0, max = 0;
        foreach (char c in code)
        {
            if (c == '{') { depth++; if (depth > max) max = depth; }
            else if (c == '}') depth = Math.Max(0, depth - 1);
        }
        return max;
    }
}

/// <summary>
/// The structured result returned by <see cref="CodeMetricsTool.AnalyzeCode"/>.
/// </summary>
public sealed record CodeMetrics(
    int TotalLines,
    int NonBlankLines,
    int EstimatedCyclomaticComplexity,
    int MaxNestingDepth,
    int MethodCount,
    string[] CodeSmells,
    string[] SecurityHotspots
);
