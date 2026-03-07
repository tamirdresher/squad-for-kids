#!/usr/bin/env node

/**
 * DevBox MCP Server - Phase 3
 * 
 * MCP server interface for Microsoft DevBox provisioning operations.
 * Wraps Phase 1 templates and Phase 2 scripts with MCP protocol.
 * 
 * @author B'Elanna (Infrastructure Expert)
 * @issue #65
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';
import * as path from 'path';
import { fileURLToPath } from 'url';

const execAsync = promisify(exec);
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Root path to DevBox provisioning scripts
const SCRIPTS_PATH = path.resolve(__dirname, '..', '..', 'scripts');

/**
 * Tool definitions for DevBox operations
 */
const TOOLS: Tool[] = [
  {
    name: 'devbox_list',
    description: 'List all DevBox instances for the authenticated user',
    inputSchema: {
      type: 'object',
      properties: {
        format: {
          type: 'string',
          enum: ['table', 'json'],
          description: 'Output format (default: json)',
          default: 'json',
        },
      },
    },
  },
  {
    name: 'devbox_create',
    description: 'Create a new DevBox instance with specified configuration',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name for the new DevBox (3-63 chars, alphanumeric and hyphens)',
          pattern: '^[a-zA-Z0-9-]{3,63}$',
        },
        devCenterName: {
          type: 'string',
          description: 'Dev Center name (optional, uses auto-detection if omitted)',
        },
        projectName: {
          type: 'string',
          description: 'Project name (optional, uses auto-detection if omitted)',
        },
        poolName: {
          type: 'string',
          description: 'Pool name (optional, uses auto-detection if omitted)',
        },
        waitForCompletion: {
          type: 'boolean',
          description: 'Wait for provisioning to complete',
          default: true,
        },
        timeoutMinutes: {
          type: 'number',
          description: 'Timeout in minutes for provisioning',
          default: 30,
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'devbox_clone',
    description: 'Clone an existing DevBox configuration to create a new instance',
    inputSchema: {
      type: 'object',
      properties: {
        newName: {
          type: 'string',
          description: 'Name for the cloned DevBox',
          pattern: '^[a-zA-Z0-9-]{3,63}$',
        },
        sourceName: {
          type: 'string',
          description: 'Source DevBox to clone (optional, auto-detects if omitted)',
        },
        waitForCompletion: {
          type: 'boolean',
          description: 'Wait for provisioning to complete',
          default: true,
        },
        timeoutMinutes: {
          type: 'number',
          description: 'Timeout in minutes for provisioning',
          default: 30,
        },
      },
      required: ['newName'],
    },
  },
  {
    name: 'devbox_show',
    description: 'Get detailed information about a specific DevBox instance',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name of the DevBox to query',
        },
        format: {
          type: 'string',
          enum: ['json', 'summary'],
          description: 'Output format (default: json)',
          default: 'json',
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'devbox_delete',
    description: 'Delete a DevBox instance (teardown)',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name of the DevBox to delete',
        },
        force: {
          type: 'boolean',
          description: 'Force deletion without confirmation',
          default: false,
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'devbox_status',
    description: 'Check the provisioning status of a DevBox',
    inputSchema: {
      type: 'object',
      properties: {
        name: {
          type: 'string',
          description: 'Name of the DevBox to check',
        },
      },
      required: ['name'],
    },
  },
  {
    name: 'devbox_bulk_create',
    description: 'Create multiple DevBox instances in parallel',
    inputSchema: {
      type: 'object',
      properties: {
        count: {
          type: 'number',
          description: 'Number of DevBoxes to create',
          minimum: 1,
          maximum: 20,
        },
        namePrefix: {
          type: 'string',
          description: 'Prefix for auto-generated names',
          default: 'devbox',
        },
        names: {
          type: 'array',
          items: {
            type: 'string',
            pattern: '^[a-zA-Z0-9-]{3,63}$',
          },
          description: 'Explicit array of names (overrides count and namePrefix)',
        },
        sequential: {
          type: 'boolean',
          description: 'Create sequentially instead of in parallel',
          default: false,
        },
        maxConcurrent: {
          type: 'number',
          description: 'Max concurrent operations (parallel mode)',
          default: 5,
        },
      },
    },
  },
];

/**
 * Execute PowerShell script with arguments
 */
async function executePowerShellScript(
  scriptName: string,
  args: string[] = []
): Promise<{ stdout: string; stderr: string }> {
  const scriptPath = path.join(SCRIPTS_PATH, scriptName);
  const command = `pwsh -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" ${args.join(' ')}`;

  try {
    const result = await execAsync(command, {
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });
    return result;
  } catch (error: any) {
    throw new Error(
      `Script execution failed: ${error.message}\nStdout: ${error.stdout}\nStderr: ${error.stderr}`
    );
  }
}

/**
 * Execute Azure CLI command
 */
async function executeAzCommand(
  args: string[]
): Promise<{ stdout: string; stderr: string }> {
  const command = `az ${args.join(' ')}`;

  try {
    const result = await execAsync(command, {
      maxBuffer: 10 * 1024 * 1024,
    });
    return result;
  } catch (error: any) {
    throw new Error(
      `Azure CLI command failed: ${error.message}\nStdout: ${error.stdout}\nStderr: ${error.stderr}`
    );
  }
}

/**
 * Handle tool execution
 */
async function handleToolCall(name: string, args: any): Promise<any> {
  switch (name) {
    case 'devbox_list': {
      const format = args.format || 'json';
      const azArgs = ['devcenter', 'dev', 'dev-box', 'list', '--output', format];
      const result = await executeAzCommand(azArgs);

      if (format === 'json') {
        return {
          content: [
            {
              type: 'text',
              text: result.stdout,
            },
          ],
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: `DevBox instances:\n${result.stdout}`,
            },
          ],
        };
      }
    }

    case 'devbox_create': {
      const scriptArgs = [`-DevBoxName`, `"${args.name}"`];

      if (args.devCenterName) {
        scriptArgs.push(`-DevCenterName`, `"${args.devCenterName}"`);
      }
      if (args.projectName) {
        scriptArgs.push(`-ProjectName`, `"${args.projectName}"`);
      }
      if (args.poolName) {
        scriptArgs.push(`-PoolName`, `"${args.poolName}"`);
      }
      if (args.waitForCompletion !== undefined) {
        scriptArgs.push(`-WaitForCompletion`, `$${args.waitForCompletion}`);
      }
      if (args.timeoutMinutes) {
        scriptArgs.push(`-TimeoutMinutes`, `${args.timeoutMinutes}`);
      }

      const result = await executePowerShellScript('provision.ps1', scriptArgs);

      return {
        content: [
          {
            type: 'text',
            text: `DevBox '${args.name}' created successfully.\n\nOutput:\n${result.stdout}`,
          },
        ],
      };
    }

    case 'devbox_clone': {
      const scriptArgs = [`-NewDevBoxName`, `"${args.newName}"`];

      if (args.sourceName) {
        scriptArgs.push(`-SourceDevBoxName`, `"${args.sourceName}"`);
      }
      if (args.waitForCompletion !== undefined) {
        scriptArgs.push(`-WaitForCompletion`, `$${args.waitForCompletion}`);
      }
      if (args.timeoutMinutes) {
        scriptArgs.push(`-TimeoutMinutes`, `${args.timeoutMinutes}`);
      }

      const result = await executePowerShellScript('clone-devbox.ps1', scriptArgs);

      return {
        content: [
          {
            type: 'text',
            text: `DevBox '${args.newName}' cloned successfully.\n\nOutput:\n${result.stdout}`,
          },
        ],
      };
    }

    case 'devbox_show': {
      const azArgs = [
        'devcenter',
        'dev',
        'dev-box',
        'show',
        '--name',
        args.name,
        '--output',
        'json',
      ];
      const result = await executeAzCommand(azArgs);

      if (args.format === 'summary') {
        const devBox = JSON.parse(result.stdout);
        const summary = `
DevBox: ${devBox.name}
Status: ${devBox.provisioningState}
Project: ${devBox.projectName}
Pool: ${devBox.poolName}
Dev Center: ${devBox.devCenterName}
Hardware: ${devBox.hardwareProfile?.skuName || 'N/A'}
Image: ${devBox.imageReference?.name || 'N/A'}
        `.trim();

        return {
          content: [
            {
              type: 'text',
              text: summary,
            },
          ],
        };
      } else {
        return {
          content: [
            {
              type: 'text',
              text: result.stdout,
            },
          ],
        };
      }
    }

    case 'devbox_delete': {
      const azArgs = [
        'devcenter',
        'dev',
        'dev-box',
        'delete',
        '--name',
        args.name,
      ];

      if (args.force) {
        azArgs.push('--yes');
      }

      const result = await executeAzCommand(azArgs);

      return {
        content: [
          {
            type: 'text',
            text: `DevBox '${args.name}' deleted successfully.\n\nOutput:\n${result.stdout}`,
          },
        ],
      };
    }

    case 'devbox_status': {
      const azArgs = [
        'devcenter',
        'dev',
        'dev-box',
        'show',
        '--name',
        args.name,
        '--output',
        'json',
        '--query',
        'provisioningState',
      ];
      const result = await executeAzCommand(azArgs);

      return {
        content: [
          {
            type: 'text',
            text: `DevBox '${args.name}' status: ${result.stdout.trim()}`,
          },
        ],
      };
    }

    case 'devbox_bulk_create': {
      const scriptArgs = [];

      if (args.names && args.names.length > 0) {
        const namesArg = args.names.map((n: string) => `"${n}"`).join(',');
        scriptArgs.push(`-Names`, `@(${namesArg})`);
      } else {
        if (args.count) {
          scriptArgs.push(`-Count`, `${args.count}`);
        }
        if (args.namePrefix) {
          scriptArgs.push(`-NamePrefix`, `"${args.namePrefix}"`);
        }
      }

      if (args.sequential !== undefined) {
        scriptArgs.push(`-Sequential:$${args.sequential}`);
      }
      if (args.maxConcurrent) {
        scriptArgs.push(`-MaxConcurrent`, `${args.maxConcurrent}`);
      }

      const result = await executePowerShellScript('bulk-provision.ps1', scriptArgs);

      return {
        content: [
          {
            type: 'text',
            text: `Bulk provisioning completed.\n\nOutput:\n${result.stdout}`,
          },
        ],
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

/**
 * Main server setup
 */
async function main() {
  const server = new Server(
    {
      name: '@microsoft/devbox-mcp-server',
      version: '1.0.0',
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // Handle list tools request
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
      tools: TOOLS,
    };
  });

  // Handle tool call request
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    try {
      const result = await handleToolCall(request.params.name, request.params.arguments);
      return result;
    } catch (error: any) {
      return {
        content: [
          {
            type: 'text',
            text: `Error: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  });

  // Connect to stdio transport
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error('DevBox MCP Server running on stdio');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
