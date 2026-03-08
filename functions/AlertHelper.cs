using System;
using System.Collections.Generic;

namespace FedRampDashboard.Functions
{
    /// <summary>
    /// Shared helper methods for alert processing
    /// </summary>
    public static class AlertHelper
    {
        /// <summary>
        /// Generates a consistent deduplication key for alerts
        /// </summary>
        /// <param name="alertType">Type of alert (e.g., control_drift, threshold_breach)</param>
        /// <param name="controlId">Control ID or null for global alerts</param>
        /// <param name="environment">Environment name (dev, stg, prod)</param>
        /// <returns>Redis key for deduplication</returns>
        public static string GenerateDedupKey(string alertType, string controlId, string environment)
        {
            return $"alert:dedup:{alertType}:{controlId ?? "global"}:{environment}";
        }

        /// <summary>
        /// Generates acknowledgment key for suppressed alerts
        /// </summary>
        /// <param name="alertType">Type of alert</param>
        /// <param name="controlId">Control ID or null for global alerts</param>
        /// <param name="environment">Environment name</param>
        /// <returns>Redis key for acknowledgment</returns>
        public static string GenerateAckKey(string alertType, string controlId, string environment)
        {
            return $"alert:ack:{alertType}:{controlId ?? "global"}:{environment}";
        }

        /// <summary>
        /// Severity mapping configuration
        /// </summary>
        public static class SeverityMapping
        {
            /// <summary>
            /// Maps internal P0-P3 severity to PagerDuty severity levels
            /// </summary>
            public static string ToPagerDuty(string severity)
            {
                return severity switch
                {
                    "P0" => "critical",
                    "P1" => "error",
                    "P2" => "warning",
                    "P3" => "info",
                    _ => "warning"
                };
            }

            /// <summary>
            /// Maps internal P0-P3 severity to Teams webhook routing key
            /// </summary>
            public static string ToTeamsWebhookKey(string severity)
            {
                return severity switch
                {
                    "P0" => "critical",
                    "P1" => "critical",
                    "P2" => "medium",
                    "P3" => "low",
                    _ => "medium"
                };
            }

            /// <summary>
            /// Maps internal P0-P3 severity to Teams Adaptive Card color style
            /// </summary>
            public static string ToTeamsCardStyle(string severity)
            {
                return severity switch
                {
                    "P0" => "attention",
                    "P1" => "warning",
                    "P2" => "good",
                    "P3" => "default",
                    _ => "default"
                };
            }
        }
    }
}
