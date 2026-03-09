/**
 * Agency Log Tailer Service
 * 
 * Tails active agency session logs from the .agency/logs directory
 * Parses structured logs for agent activity patterns including:
 * - Agent spawns and completions
 * - Tool calls such as edit, create, gh issue, gh pr
 * - Errors and failures
 * - GitHub actions
 */

export interface LogEntry {
  timestamp: string;
  level: 'TRACE' | 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  message: string;
  raw: string;
}

export interface AgencyActivity {
  agentSpawns: AgentSpawnEvent[];
  toolCalls: ToolCallEvent[];
  githubActions: GitHubActionEvent[];
  errors: ErrorEvent[];
  rawLogs: LogEntry[];
}

export interface AgentSpawnEvent {
  timestamp: string;
  agentName: string;
  task: string;
}

export interface ToolCallEvent {
  timestamp: string;
  tool: string;
  details: string;
}

export interface GitHubActionEvent {
  timestamp: string;
  action: 'issue_created' | 'issue_closed' | 'pr_created' | 'pr_merged' | 'comment_added';
  details: string;
}

export interface ErrorEvent {
  timestamp: string;
  message: string;
  level: 'ERROR' | 'WARN';
}

/**
 * Parse a single log line from agency session log
 * Format: YYYY-MM-DDTHH:mm:ss.msZ LEVEL ThreadId(N) module: file:line: message
 */
export function parseAgencyLogLine(line: string): LogEntry | null {
  // Pattern: 2026-03-08T13:52:03.509947Z  INFO main ThreadId(01) agency: client\agency\src\main.rs:243: 🤖 Agency 2026.3.7.5
  const logPattern = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(TRACE|DEBUG|INFO|WARN|ERROR)\s+.*?:\s+(.+)$/;
  const match = line.match(logPattern);
  
  if (!match) {
    return null;
  }
  
  const [, timestamp, level, message] = match;
  
  return {
    timestamp,
    level: level as LogEntry['level'],
    message: message.trim(),
    raw: line,
  };
}

/**
 * Detect agent spawn patterns in log messages
 */
export function detectAgentSpawn(entry: LogEntry): AgentSpawnEvent | null {
  // Look for patterns like:
  // - "Spawning agent X"
  // - "Starting agent X"
  // - Agent prompt with "You are X, the Y on this project"
  
  const spawnPatterns = [
    /spawning\s+agent[:\s]+(\w+)/i,
    /starting\s+agent[:\s]+(\w+)/i,
    /you are (\w+),\s+the\s+.+?\s+on this project/i,
  ];
  
  for (const pattern of spawnPatterns) {
    const match = entry.message.match(pattern);
    if (match) {
      return {
        timestamp: entry.timestamp,
        agentName: match[1],
        task: entry.message.substring(0, 100),
      };
    }
  }
  
  return null;
}

/**
 * Detect tool calls in log messages
 */
export function detectToolCall(entry: LogEntry): ToolCallEvent | null {
  // Look for patterns like:
  // - "Running tool: edit"
  // - "Executing: gh issue create"
  // - "Tool call: create"
  
  const toolPatterns = [
    /running tool[:\s]+(\w+)/i,
    /executing[:\s]+(gh\s+\w+\s+\w+)/i,
    /tool call[:\s]+(\w+)/i,
    /invoking[:\s]+(\w+)\s+tool/i,
  ];
  
  for (const pattern of toolPatterns) {
    const match = entry.message.match(pattern);
    if (match) {
      return {
        timestamp: entry.timestamp,
        tool: match[1],
        details: entry.message.substring(0, 100),
      };
    }
  }
  
  return null;
}

/**
 * Detect GitHub actions in log messages
 */
export function detectGitHubAction(entry: LogEntry): GitHubActionEvent | null {
  const ghPatterns = [
    { pattern: /gh\s+issue\s+create/i, action: 'issue_created' as const },
    { pattern: /gh\s+issue\s+close/i, action: 'issue_closed' as const },
    { pattern: /gh\s+pr\s+create/i, action: 'pr_created' as const },
    { pattern: /gh\s+pr\s+merge/i, action: 'pr_merged' as const },
    { pattern: /gh\s+issue\s+comment/i, action: 'comment_added' as const },
    { pattern: /gh\s+pr\s+comment/i, action: 'comment_added' as const },
  ];
  
  for (const { pattern, action } of ghPatterns) {
    if (pattern.test(entry.message)) {
      return {
        timestamp: entry.timestamp,
        action,
        details: entry.message.substring(0, 100),
      };
    }
  }
  
  return null;
}

/**
 * Detect errors in log messages
 */
export function detectError(entry: LogEntry): ErrorEvent | null {
  if (entry.level === 'ERROR' || entry.level === 'WARN') {
    return {
      timestamp: entry.timestamp,
      message: entry.message,
      level: entry.level,
    };
  }
  
  // Also catch messages with "error" or "failed" keywords
  if (/\b(error|failed|failure)\b/i.test(entry.message) && entry.level === 'INFO') {
    return {
      timestamp: entry.timestamp,
      message: entry.message,
      level: 'ERROR',
    };
  }
  
  return null;
}

/**
 * Parse agency log content and extract activity
 */
export function parseAgencyLog(content: string): AgencyActivity {
  const lines = content.split('\n');
  const activity: AgencyActivity = {
    agentSpawns: [],
    toolCalls: [],
    githubActions: [],
    errors: [],
    rawLogs: [],
  };
  
  for (const line of lines) {
    if (!line.trim()) continue;
    
    const entry = parseAgencyLogLine(line);
    if (!entry) continue;
    
    activity.rawLogs.push(entry);
    
    // Detect patterns
    const spawn = detectAgentSpawn(entry);
    if (spawn) {
      activity.agentSpawns.push(spawn);
    }
    
    const toolCall = detectToolCall(entry);
    if (toolCall) {
      activity.toolCalls.push(toolCall);
    }
    
    const ghAction = detectGitHubAction(entry);
    if (ghAction) {
      activity.githubActions.push(ghAction);
    }
    
    const error = detectError(entry);
    if (error) {
      activity.errors.push(error);
    }
  }
  
  return activity;
}

/**
 * Find the most recent agency session directory
 */
export async function findLatestSessionDir(): Promise<string | null> {
  // In a real implementation, this would:
  // 1. List directories in ~/.agency/logs/
  // 2. Sort by modification time
  // 3. Return the most recent session_* directory
  
  // For now, this is a placeholder that would be implemented by the backend
  return null;
}

/**
 * Tail the active agency session log
 * Returns new lines since last read
 */
export async function tailAgencyLog(_sessionDir: string, lastPosition: number = 0): Promise<{ content: string; newPosition: number }> {
  // In a real implementation, this would:
  // 1. Find the .log file in sessionDir
  // 2. Read from lastPosition to end of file
  // 3. Return new content and updated position
  
  // For now, this is a placeholder that would be implemented by the backend
  return { content: '', newPosition: lastPosition };
}

/**
 * Get log level color for display
 */
export function getLogLevelColor(level: LogEntry['level']): string {
  switch (level) {
    case 'ERROR':
      return '#f44336'; // red
    case 'WARN':
      return '#ff9800'; // orange
    case 'INFO':
      return '#2196f3'; // blue
    case 'DEBUG':
      return '#9e9e9e'; // gray
    case 'TRACE':
      return '#757575'; // light gray
    default:
      return '#000000'; // black
  }
}
