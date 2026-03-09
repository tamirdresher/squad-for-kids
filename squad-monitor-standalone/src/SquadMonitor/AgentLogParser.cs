using System.Text.RegularExpressions;

namespace SquadMonitor;

public class AgentLogParser
{
    private readonly string _logDirectory;
    private readonly Dictionary<string, long> _filePositions = new();
    private readonly List<AgentLogEntry> _recentEntries = new();
    private const int MaxEntries = 50;

    public AgentLogParser(string? logDirectory = null)
    {
        _logDirectory = logDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".agency", "logs");
    }

    public List<AgentLogEntry> GetRecentEntries()
    {
        lock (_recentEntries)
        {
            return _recentEntries.ToList();
        }
    }

    public void ParseLatestLogs()
    {
        if (!Directory.Exists(_logDirectory))
            return;

        try
        {
            var sessionDirs = Directory.GetDirectories(_logDirectory, "session_*")
                .OrderByDescending(Directory.GetLastWriteTime)
                .Take(3);

            foreach (var sessionDir in sessionDirs)
            {
                var logFiles = Directory.GetFiles(sessionDir, "process-*.log")
                    .OrderByDescending(File.GetLastWriteTime)
                    .Take(2);

                foreach (var logFile in logFiles)
                {
                    ParseLogFile(logFile);
                }
            }
        }
        catch
        {
            // Silently fail if logs are inaccessible
        }
    }

    private void ParseLogFile(string filePath)
    {
        try
        {
            var fileInfo = new FileInfo(filePath);
            if (!fileInfo.Exists)
                return;

            if (!_filePositions.TryGetValue(filePath, out var lastPosition))
            {
                lastPosition = Math.Max(0, fileInfo.Length - 50000);
            }

            if (fileInfo.Length <= lastPosition)
                return;

            using var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            fs.Seek(lastPosition, SeekOrigin.Begin);
            using var reader = new StreamReader(fs);

            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                ParseLogLine(line, Path.GetFileName(filePath));
            }

            _filePositions[filePath] = fileInfo.Length;
        }
        catch
        {
            // Silently fail on file access errors
        }
    }

    private void ParseLogLine(string line, string logFileName)
    {
        AgentLogEntry? entry = null;

        // Parse tool invocations: "Tool invocation result: toolName"
        var toolMatch = Regex.Match(line, @"Tool invocation result:\s*([^\s]+)");
        if (toolMatch.Success)
        {
            entry = new AgentLogEntry
            {
                Timestamp = DateTime.Now,
                Type = "Tool",
                Agent = ExtractAgentFromFileName(logFileName),
                Message = $"Invoked tool: {toolMatch.Groups[1].Value}",
                LogFile = logFileName
            };
        }

        // Parse agent spawns: "agent_type": "task"
        if (entry == null && line.Contains("\"agent_type\":"))
        {
            var agentTypeMatch = Regex.Match(line, @"""agent_type"":\s*""([^""]+)""");
            if (agentTypeMatch.Success)
            {
                var agentType = agentTypeMatch.Groups[1].Value;
                var descMatch = Regex.Match(line, @"""description"":\s*""([^""]+)""");
                var description = descMatch.Success ? descMatch.Groups[1].Value : "Starting task";

                entry = new AgentLogEntry
                {
                    Timestamp = DateTime.Now,
                    Type = "SubAgent",
                    Agent = ExtractAgentFromFileName(logFileName),
                    Message = $"Spawned {agentType} agent: {description}",
                    LogFile = logFileName
                };
            }
        }

        // Parse task launches with descriptions
        if (entry == null && line.Contains("\"name\": \"task\""))
        {
            var descMatch = Regex.Match(line, @"""description"":\s*""([^""]+)""");
            if (descMatch.Success)
            {
                entry = new AgentLogEntry
                {
                    Timestamp = DateTime.Now,
                    Type = "Task",
                    Agent = ExtractAgentFromFileName(logFileName),
                    Message = $"Background task: {descMatch.Groups[1].Value}",
                    LogFile = logFileName
                };
            }
        }

        // Parse agent completions
        if (entry == null && Regex.IsMatch(line, @"(agent|task)\s+(completed|finished|done)", RegexOptions.IgnoreCase))
        {
            entry = new AgentLogEntry
            {
                Timestamp = DateTime.Now,
                Type = "Completion",
                Agent = ExtractAgentFromFileName(logFileName),
                Message = "Agent completed",
                LogFile = logFileName
            };
        }

        if (entry != null)
        {
            lock (_recentEntries)
            {
                _recentEntries.Add(entry);
                while (_recentEntries.Count > MaxEntries)
                {
                    _recentEntries.RemoveAt(0);
                }
            }
        }
    }

    private static string ExtractAgentFromFileName(string fileName)
    {
        // Extract from pattern: process-{pid}-{agent}.log
        var match = Regex.Match(fileName, @"process-\d+-(.+)\.log");
        if (match.Success)
        {
            return CapitalizeFirst(match.Groups[1].Value);
        }
        return "Unknown";
    }

    private static string CapitalizeFirst(string text)
    {
        if (string.IsNullOrEmpty(text))
            return text;
        return char.ToUpper(text[0]) + text.Substring(1).ToLower();
    }
}

public record AgentLogEntry
{
    public required DateTime Timestamp { get; init; }
    public required string Type { get; init; }
    public required string Agent { get; init; }
    public required string Message { get; init; }
    public required string LogFile { get; init; }
}
