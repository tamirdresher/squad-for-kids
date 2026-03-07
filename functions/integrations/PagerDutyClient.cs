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
    public class PagerDutyClient
    {
        private readonly HttpClient _httpClient;
        private readonly string _routingKey;
        private readonly ILogger _log;

        public PagerDutyClient(HttpClient httpClient, string routingKey, ILogger log)
        {
            _httpClient = httpClient;
            _routingKey = routingKey;
            _log = log;
        }

        public async Task<bool> SendAlertAsync(Alert alert)
        {
            try
            {
                var payload = new
                {
                    routing_key = _routingKey,
                    event_action = "trigger",
                    dedup_key = alert.AlertId,
                    payload = new
                    {
                        summary = GetAlertSummary(alert),
                        severity = MapSeverityToPagerDuty(alert.Severity),
                        source = $"FedRAMP Dashboard - {alert.Environment}",
                        timestamp = alert.Timestamp.ToString("o"),
                        component = alert.Control?.Id,
                        group = alert.Control?.Category,
                        custom_details = new
                        {
                            alert_type = alert.AlertType,
                            control_id = alert.Control?.Id,
                            control_name = alert.Control?.Name,
                            environment = alert.Environment,
                            metrics = alert.Metrics,
                            runbook_url = alert.RunbookUrl
                        }
                    },
                    links = GetAlertLinks(alert)
                };

                var json = JsonConvert.SerializeObject(payload);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("https://events.pagerduty.com/v2/enqueue", content);
                response.EnsureSuccessStatusCode();

                var responseBody = await response.Content.ReadAsStringAsync();
                var result = JsonConvert.DeserializeObject<PagerDutyResponse>(responseBody);

                _log.LogInformation($"PagerDuty alert sent successfully. Dedup key: {result.DedupKey}");
                return true;
            }
            catch (Exception ex)
            {
                _log.LogError(ex, $"Failed to send PagerDuty alert: {alert.AlertId}");
                return false;
            }
        }

        private string GetAlertSummary(Alert alert)
        {
            return alert.AlertType switch
            {
                "control_drift" => $"[{alert.Severity}] Control Drift Detected: {alert.Control?.Id} ({alert.Environment})",
                "control_regression" => $"[{alert.Severity}] Control Regression: {alert.Control?.Id} ({alert.Environment})",
                "threshold_breach" => $"[{alert.Severity}] Compliance Threshold Breach: {alert.Environment}",
                "new_vulnerability" => $"[{alert.Severity}] New Vulnerability Detected: {alert.Vulnerabilities?.FirstOrDefault()?.VulnerabilityId} ({alert.Environment})",
                "compliance_deadline" => $"[{alert.Severity}] Compliance Deadline Approaching: {alert.Deadline?.Description}",
                "manual_review_needed" => $"[{alert.Severity}] Manual Review Required: {alert.Control?.Id} ({alert.Environment})",
                _ => $"[{alert.Severity}] FedRAMP Alert: {alert.AlertId}"
            };
        }

        private string MapSeverityToPagerDuty(string severity)
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

        private List<object> GetAlertLinks(Alert alert)
        {
            var links = new List<object>();

            if (!string.IsNullOrEmpty(alert.RunbookUrl))
            {
                links.Add(new
                {
                    href = alert.RunbookUrl,
                    text = "Runbook"
                });
            }

            if (alert.Control != null)
            {
                links.Add(new
                {
                    href = $"https://fedramp-dashboard.contoso.com/controls/{alert.Control.Id}?env={alert.Environment}",
                    text = "Dashboard"
                });
            }

            // Add CVE links for vulnerability alerts
            if (alert.AlertType == "new_vulnerability" && alert.Vulnerabilities != null)
            {
                foreach (var vuln in alert.Vulnerabilities.Take(3)) // Limit to 3 links
                {
                    links.Add(new
                    {
                        href = $"https://nvd.nist.gov/vuln/detail/{vuln.VulnerabilityId}",
                        text = vuln.VulnerabilityId
                    });
                }
            }

            return links;
        }
    }

    public class PagerDutyResponse
    {
        [JsonProperty("status")]
        public string Status { get; set; }

        [JsonProperty("message")]
        public string Message { get; set; }

        [JsonProperty("dedup_key")]
        public string DedupKey { get; set; }
    }
}
