# Squad Activity Monitor

A real-time terminal dashboard for monitoring squad member activity.

## Features

- 🎨 Beautiful terminal UI with Spectre.Console
- 🔄 Auto-refresh every 5 seconds (configurable)
- 📊 Color-coded status indicators (green/yellow/red)
- 📈 Activity age tracking
- 🎯 Parse orchestration logs automatically

## Usage

```bash
# Run with auto-refresh (default 5s)
dotnet run

# Custom refresh interval
dotnet run -- --interval 10

# Run once without refresh loop
dotnet run -- --once
```

## Build & Publish

```bash
# Build
dotnet build

# Publish as single-file executable
dotnet publish -c Release -r win-x64 --self-contained
```

The published executable will be at: `bin\Release\net10.0\win-x64\publish\squad-monitor.exe`

## How It Works

1. Finds team root by looking for `.squad` directory
2. Reads orchestration logs from `.squad/orchestration-log/`
3. Parses agent name, status, task, and outcome from markdown files
4. Displays in a formatted table with color coding and age indicators

## Status Color Coding

- 🟢 Green: Completed (✅)
- 🟡 Yellow: In Progress (⏳)
- 🔴 Red: Failed (❌)
- 🔵 Blue: Other statuses

## Requirements

- .NET 10.0 SDK
- Windows, Linux, or macOS
