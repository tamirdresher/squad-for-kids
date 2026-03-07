using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;

namespace FedRampDashboard.Functions
{
    public class TeamsClient
    {
        private readonly HttpClient _httpClient;
        private readonly ILogger _log;
        private readonly Dictionary<string, string> _webhookUrls;

        public TeamsClient(HttpClient httpClient, Dictionary<string, string> webhookUrls, ILogger log)
        {
            _httpClient = httpClient;
            _webhookUrls = webhookUrls;
            _log = log;
        }

        public async Task<bool> SendAlertAsync(Alert alert)
        {
            try
            {
                var webhookUrl = GetWebhookUrl(alert.Severity);
                if (string.IsNullOrEmpty(webhookUrl))
                {
                    _log.LogWarning($"No webhook URL configured for severity: {alert.Severity}");
                    return false;
                }

                var adaptiveCard = BuildAdaptiveCard(alert);

                var payload = new
                {
                    type = "message",
                    attachments = new[]
                    {
                        new
                        {
                            contentType = "application/vnd.microsoft.card.adaptive",
                            contentUrl = (string)null,
                            content = adaptiveCard
                        }
                    }
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync(webhookUrl, content);
                response.EnsureSuccessStatusCode();

                _log.LogInformation($"Teams alert sent successfully to {alert.Severity} channel");
                return true;
            }
            catch (Exception ex)
            {
                _log.LogError(ex, $"Failed to send Teams alert: {alert.AlertId}");
                return false;
            }
        }

        private string GetWebhookUrl(string severity)
        {
            var key = severity switch
            {
                "P0" => "critical",
                "P1" => "critical",
                "P2" => "medium",
                "P3" => "low",
                _ => "medium"
            };

            _webhookUrls.TryGetValue(key, out var url);
            return url;
        }

        private object BuildAdaptiveCard(Alert alert)
        {
            var color = alert.Severity switch
            {
                "P0" => "attention",
                "P1" => "warning",
                "P2" => "good",
                "P3" => "default",
                _ => "default"
            };

            var body = new List<object>
            {
                new
                {
                    type = "Container",
                    style = color,
                    items = new List<object>
                    {
                        new
                        {
                            type = "TextBlock",
                            size = "Large",
                            weight = "Bolder",
                            text = $"🚨 {GetAlertTitle(alert)}"
                        }
                    }
                },
                new
                {
                    type = "FactSet",
                    facts = BuildFactSet(alert)
                },
                new
                {
                    type = "TextBlock",
                    text = GetAlertDescription(alert),
                    wrap = true
                }
            };

            // Add remediation steps if present
            if (alert.RemediationSteps != null && alert.RemediationSteps.Any())
            {
                body.Add(new
                {
                    type = "Container",
                    items = new List<object>
                    {
                        new
                        {
                            type = "TextBlock",
                            text = "**Remediation Steps:**",
                            weight = "Bolder"
                        },
                        new
                        {
                            type = "TextBlock",
                            text = string.Join("\n\n", alert.RemediationSteps),
                            wrap = true
                        }
                    }
                });
            }

            return new
            {
                type = "AdaptiveCard",
                body = body,
                actions = BuildActions(alert),
                schema = "http://adaptivecards.io/schemas/adaptive-card.json",
                version = "1.4"
            };
        }

        private string GetAlertTitle(Alert alert)
        {
            return alert.AlertType switch
            {
                "control_drift" => $"Control Drift: {alert.Control?.Id}",
                "control_regression" => $"Control Regression: {alert.Control?.Id}",
                "threshold_breach" => $"Compliance Threshold Breach",
                "new_vulnerability" => $"New Vulnerability Detected",
                "compliance_deadline" => $"Compliance Deadline Approaching",
                "manual_review_needed" => $"Manual Review Required",
                _ => $"FedRAMP Alert"
            };
        }

        private List<object> BuildFactSet(Alert alert)
        {
            var facts = new List<object>
            {
                new { title = "Severity", value = alert.Severity },
                new { title = "Environment", value = alert.Environment },
                new { title = "Timestamp", value = alert.Timestamp.ToString("yyyy-MM-dd HH:mm:ss UTC") }
            };

            if (alert.Control != null)
            {
                facts.Add(new { title = "Control", value = $"{alert.Control.Id} - {alert.Control.Name}" });
                facts.Add(new { title = "Category", value = alert.Control.Category });
            }

            // Add type-specific facts
            if (alert.AlertType == "control_drift" && alert.Metrics != null)
            {
                if (alert.Metrics.TryGetValue("drift_percentage", out var driftPct))
                {
                    facts.Add(new { title = "Drift", value = $"{driftPct:F1}%" });
                }
            }
            else if (alert.AlertType == "new_vulnerability" && alert.Vulnerabilities != null && alert.Vulnerabilities.Any())
            {
                var vuln = alert.Vulnerabilities.First();
                facts.Add(new { title = "CVE", value = vuln.VulnerabilityId });
                facts.Add(new { title = "CVSS Score", value = vuln.CvssScore.ToString("F1") });
                facts.Add(new { title = "Package", value = $"{vuln.PackageName} {vuln.InstalledVersion}" });
            }
            else if (alert.AlertType == "compliance_deadline" && alert.Deadline != null)
            {
                facts.Add(new { title = "Deadline", value = alert.Deadline.DeadlineDate.ToString("yyyy-MM-dd") });
                facts.Add(new { title = "Days Remaining", value = alert.DaysUntilDeadline?.ToString() ?? "N/A" });
            }

            return facts;
        }

        private string GetAlertDescription(Alert alert)
        {
            return alert.AlertType switch
            {
                "control_drift" => GetMetricValue(alert, "drift_percentage") is double drift 
                    ? $"Control failure rate increased by {drift:F1}%." 
                    : "Control failure rate increased significantly.",
                "control_regression" => GetMetricValue(alert, "consecutive_failures") is int failures 
                    ? $"Control has {failures} consecutive failures in the last hour." 
                    : "Control has multiple consecutive failures.",
                "threshold_breach" => GetMetricValue(alert, "current_compliance_rate") is double rate 
                    ? $"Compliance rate dropped to {rate:F1}%." 
                    : "Compliance rate dropped below threshold.",
                "new_vulnerability" => alert.Vulnerabilities?.FirstOrDefault() is VulnerabilityInfo vuln 
                    ? $"New {vuln.Severity} vulnerability detected: {vuln.VulnerabilityId} (CVSS {vuln.CvssScore:F1})." 
                    : "New vulnerability detected.",
                "compliance_deadline" => alert.DaysUntilDeadline.HasValue 
                    ? $"Deadline '{alert.Deadline?.Description}' in {alert.DaysUntilDeadline} day(s)." 
                    : "Compliance deadline approaching.",
                "manual_review_needed" => $"Ambiguous test result requires manual review: {alert.ReviewReason ?? "Unknown reason"}.",
                _ => $"Alert ID: {alert.AlertId}"
            };
        }

        private object GetMetricValue(Alert alert, string key)
        {
            if (alert.Metrics != null && alert.Metrics.TryGetValue(key, out var value))
            {
                return value;
            }
            return null;
        }

        private List<object> BuildActions(Alert alert)
        {
            var actions = new List<object>();

            if (alert.Control != null)
            {
                actions.Add(new
                {
                    type = "Action.OpenUrl",
                    title = "View Dashboard",
                    url = $"https://fedramp-dashboard.contoso.com/controls/{alert.Control.Id}?env={alert.Environment}"
                });
            }

            if (!string.IsNullOrEmpty(alert.RunbookUrl))
            {
                actions.Add(new
                {
                    type = "Action.OpenUrl",
                    title = "Runbook",
                    url = alert.RunbookUrl
                });
            }

            actions.Add(new
            {
                type = "Action.OpenUrl",
                title = "Acknowledge",
                url = $"https://fedramp-dashboard.contoso.com/alerts/{alert.AlertId}/acknowledge"
            });

            return actions;
        }
    }
}
