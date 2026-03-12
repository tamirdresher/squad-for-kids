# Test which org the ADO MCP is actually connected to
$testResults = @{
    'MCP_list_projects' = 'Unknown'
    'MCP_search_results' = 'Unknown'  
    'Configured_Org' = 'Unknown'
}

# Check configured org
$repoConfig = Get-Content '.\.copilot\mcp-config.json' | ConvertFrom-Json
$globalConfig = Get-Content '~\.copilot\mcp-config.json' | ConvertFrom-Json
$testResults['Configured_Org'] = "Repo: $($repoConfig.mcpServers.'azure-devops'.args[-1]), Global: $($globalConfig.mcpServers.'azure-devops'.args[-1])"

Write-Host "=== Azure DevOps MCP Multi-Org Test Results ==="
$testResults | Format-Table -AutoSize
