/**
 * Squad MCP Server — Tool Registry
 *
 * Exports all available tools
 */
export const TOOLS = [
    {
        name: "get_squad_health",
        description: "Get comprehensive squad health metrics including open issues, PRs, member capacity, and board status. Returns health status (healthy/warning/critical), team metrics, and per-member statistics.",
        inputSchema: {
            type: "object",
            properties: {
                includeMetrics: {
                    type: "boolean",
                    description: "Include detailed metrics in the response (default: true)",
                    default: true,
                },
            },
        },
    },
    // Future tools will be added here:
    // - triage_issue
    // - check_board_status
    // - get_member_capacity
    // - evaluate_routing
];
//# sourceMappingURL=index.js.map