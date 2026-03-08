using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using StackExchange.Redis;

namespace FedRampDashboard.Functions
{
    public static class AlertProcessor
    {
        private static readonly HttpClient _httpClient = new HttpClient();
        private static ConnectionMultiplexer _redis;

        [FunctionName("AlertProcessor")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            var startTime = DateTime.UtcNow;
            log.LogInformation("AlertProcessor triggered at {Timestamp}", startTime);

            try
            {
                // Initialize Redis connection if not already done
                if (_redis == null || !_redis.IsConnected)
                {
                    var redisConnection = Environment.GetEnvironmentVariable("RedisConnectionString");
                    _redis = ConnectionMultiplexer.Connect(redisConnection);
                    log.LogInformation("Redis connection established");
                }

                // Parse incoming alert
                var requestBody = await new StreamReader(req.Body).ReadToEndAsync();
                var alert = JsonConvert.DeserializeObject<Alert>(requestBody);

                if (alert == null)
                {
                    log.LogWarning("Invalid alert payload received");
                    return new BadRequestObjectResult("Invalid alert payload");
                }

                using (log.BeginScope(new Dictionary<string, object>
                {
                    ["AlertId"] = alert.AlertId,
                    ["AlertType"] = alert.AlertType,
                    ["Severity"] = alert.Severity,
                    ["Environment"] = alert.Environment,
                    ["ControlId"] = alert.Control?.Id ?? "none"
                }))
                {
                    log.LogInformation(
                        "Processing alert: AlertId={AlertId}, Type={AlertType}, Severity={Severity}, Environment={Environment}",
                        alert.AlertId, alert.AlertType, alert.Severity, alert.Environment);

                    // Step 1: Enrich alert with metadata
                    var enrichStart = DateTime.UtcNow;
                    await EnrichAlertAsync(alert, log);
                    log.LogInformation("Alert enrichment completed in {Duration}ms", 
                        (DateTime.UtcNow - enrichStart).TotalMilliseconds);

                    // Step 2: Check for duplicates (30-min window)
                    if (await IsDuplicateAsync(alert, log))
                    {
                        log.LogInformation("Alert {AlertId} is duplicate. Skipping.", alert.AlertId);
                        return new OkObjectResult(new { status = "duplicate", alert_id = alert.AlertId });
                    }

                    // Step 3: Check suppression rules
                    if (await IsSuppressedAsync(alert, log))
                    {
                        log.LogInformation("Alert {AlertId} is suppressed. Skipping.", alert.AlertId);
                        return new OkObjectResult(new { status = "suppressed", alert_id = alert.AlertId });
                    }

                    // Step 4: Route alert based on severity
                    var routingStart = DateTime.UtcNow;
                    var routingResults = await RouteAlertAsync(alert, log);
                    log.LogInformation("Alert routing completed in {Duration}ms", 
                        (DateTime.UtcNow - routingStart).TotalMilliseconds);

                    // Step 5: Store alert in cache for deduplication
                    await StoreAlertInCacheAsync(alert, log);

                    // Step 6: Log to Application Insights for audit trail
                    var totalDuration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                    log.LogInformation(
                        "Alert processed successfully: AlertId={AlertId}, Routing={Routing}, TotalDuration={Duration}ms",
                        alert.AlertId, JsonConvert.SerializeObject(routingResults), totalDuration);

                    return new OkObjectResult(new
                    {
                        status = "processed",
                        alert_id = alert.AlertId,
                        routing = routingResults,
                        processing_time_ms = totalDuration
                    });
                }
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                log.LogError(ex, "Error processing alert. Duration={Duration}ms", duration);
                return new StatusCodeResult(StatusCodes.Status500InternalServerError);
            }
        }

        private static async Task EnrichAlertAsync(Alert alert, ILogger log)
        {
            var enrichStart = DateTime.UtcNow;
            
            try
            {
                // Lookup control metadata
                if (alert.Control != null && string.IsNullOrEmpty(alert.Control.Name))
                {
                    var controlMetadata = GetControlMetadata(alert.Control.Id);
                    alert.Control.Name = controlMetadata.Name;
                    alert.Control.Category = controlMetadata.Category;
                    
                    log.LogInformation(
                        "Control metadata enriched: ControlId={ControlId}, ControlName={ControlName}, Category={Category}",
                        alert.Control.Id, alert.Control.Name, alert.Control.Category);
                }

                // Attach runbook URL
                if (string.IsNullOrEmpty(alert.RunbookUrl))
                {
                    alert.RunbookUrl = GetRunbookUrl(alert.AlertType, alert.Control?.Id);
                    log.LogInformation("Runbook URL attached: {RunbookUrl}", alert.RunbookUrl);
                }

                // Add default remediation steps if missing
                if (alert.RemediationSteps == null || !alert.RemediationSteps.Any())
                {
                    alert.RemediationSteps = GetDefaultRemediationSteps(alert.AlertType);
                    log.LogInformation(
                        "Default remediation steps added: Count={StepCount}",
                        alert.RemediationSteps.Count);
                }
                
                var duration = (DateTime.UtcNow - enrichStart).TotalMilliseconds;
                log.LogInformation(
                    "Alert enrichment completed: AlertId={AlertId}, Duration={Duration}ms",
                    alert.AlertId, duration);
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - enrichStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error enriching alert {AlertId}: Duration={Duration}ms", 
                    alert.AlertId, duration);
                throw;
            }
        }

        private static async Task<bool> IsDuplicateAsync(Alert alert, ILogger log)
        {
            var checkStart = DateTime.UtcNow;
            
            try
            {
                var db = _redis.GetDatabase();
                var dedupKey = AlertHelper.GenerateDedupKey(alert.AlertType, alert.Control?.Id, alert.Environment);
                
                var exists = await db.KeyExistsAsync(dedupKey);
                
                var duration = (DateTime.UtcNow - checkStart).TotalMilliseconds;
                if (exists)
                {
                    log.LogWarning(
                        "Duplicate alert detected: AlertId={AlertId}, DedupKey={DedupKey}, Duration={Duration}ms",
                        alert.AlertId, dedupKey, duration);
                }
                
                return exists;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - checkStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error checking for duplicate alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false; // If cache is down, allow alert through
            }
        }

        private static async Task<bool> IsSuppressedAsync(Alert alert, ILogger log)
        {
            var suppressCheckStart = DateTime.UtcNow;
            
            try
            {
                // Check acknowledged alerts in Redis
                var db = _redis.GetDatabase();
                var ackKey = AlertHelper.GenerateAckKey(alert.AlertType, alert.Control?.Id, alert.Environment);
                var isAcknowledged = await db.KeyExistsAsync(ackKey);
                
                if (isAcknowledged)
                {
                    var duration = (DateTime.UtcNow - suppressCheckStart).TotalMilliseconds;
                    log.LogInformation(
                        "Alert suppressed: AlertId={AlertId}, Reason=Acknowledged, AckKey={AckKey}, Duration={Duration}ms",
                        alert.AlertId, ackKey, duration);
                    return true;
                }

                // Could check maintenance windows from Cosmos DB here
                // For now, just check cache

                var totalDuration = (DateTime.UtcNow - suppressCheckStart).TotalMilliseconds;
                log.LogInformation(
                    "Suppression check passed: AlertId={AlertId}, Duration={Duration}ms",
                    alert.AlertId, totalDuration);
                
                return false;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - suppressCheckStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error checking suppression rules for alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false; // If cache is down, allow alert through
            }
        }

        private static async Task<Dictionary<string, bool>> RouteAlertAsync(Alert alert, ILogger log)
        {
            var routeStart = DateTime.UtcNow;
            var results = new Dictionary<string, bool>();

            try
            {
                log.LogInformation(
                    "Starting alert routing: AlertId={AlertId}, Severity={Severity}",
                    alert.AlertId, alert.Severity);

                // Routing logic based on severity
                switch (alert.Severity)
                {
                    case "P0":
                        // P0: PagerDuty only (urgent)
                        results["pagerduty"] = await SendToPagerDutyAsync(alert, log);
                        log.LogInformation("Alert routed to PagerDuty: AlertId={AlertId}, Result={Result}", 
                            alert.AlertId, results["pagerduty"]);
                        break;

                    case "P1":
                        // P1: PagerDuty (low urgency) + Teams
                        results["pagerduty"] = await SendToPagerDutyAsync(alert, log);
                        results["teams"] = await SendToTeamsAsync(alert, log);
                        log.LogInformation(
                            "Alert routed to PagerDuty and Teams: AlertId={AlertId}, PagerDuty={PagerDutyResult}, Teams={TeamsResult}",
                            alert.AlertId, results["pagerduty"], results["teams"]);
                        break;

                    case "P2":
                        // P2: Teams only
                        results["teams"] = await SendToTeamsAsync(alert, log);
                        log.LogInformation("Alert routed to Teams: AlertId={AlertId}, Result={Result}",
                            alert.AlertId, results["teams"]);
                        break;

                    case "P3":
                        // P3: Log only (could implement email digest here)
                        log.LogInformation("P3 alert logged: AlertId={AlertId}, AlertType={AlertType}", 
                            alert.AlertId, alert.AlertType);
                        results["logged"] = true;
                        break;

                    default:
                        log.LogWarning(
                            "Unknown severity encountered: AlertId={AlertId}, Severity={Severity}. Routing to Teams.",
                            alert.AlertId, alert.Severity);
                        results["teams"] = await SendToTeamsAsync(alert, log);
                        break;
                }
                
                var duration = (DateTime.UtcNow - routeStart).TotalMilliseconds;
                log.LogInformation(
                    "Alert routing completed: AlertId={AlertId}, Routes={RouteCount}, Duration={Duration}ms",
                    alert.AlertId, results.Count, duration);

                return results;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - routeStart).TotalMilliseconds;
                log.LogError(ex,
                    "Error routing alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                throw;
            }
        }

        private static async Task StoreAlertInCacheAsync(Alert alert, ILogger log)
        {
            var cacheStart = DateTime.UtcNow;
            
            try
            {
                var db = _redis.GetDatabase();
                var dedupKey = AlertHelper.GenerateDedupKey(alert.AlertType, alert.Control?.Id, alert.Environment);
                
                // Store with 30-minute TTL
                await db.StringSetAsync(dedupKey, alert.AlertId, TimeSpan.FromMinutes(30));
                
                var duration = (DateTime.UtcNow - cacheStart).TotalMilliseconds;
                log.LogInformation(
                    "Alert stored in cache: AlertId={AlertId}, DedupKey={DedupKey}, TTL=30min, Duration={Duration}ms",
                    alert.AlertId, dedupKey, duration);
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - cacheStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error storing alert {AlertId} in cache: Duration={Duration}ms",
                    alert.AlertId, duration);
            }
        }

        private static async Task<bool> SendToPagerDutyAsync(Alert alert, ILogger log)
        {
            var sendStart = DateTime.UtcNow;
            
            try
            {
                var routingKey = Environment.GetEnvironmentVariable("PagerDutyRoutingKey");
                if (string.IsNullOrEmpty(routingKey))
                {
                    log.LogWarning("PagerDuty routing key not configured");
                    return false;
                }

                log.LogInformation(
                    "Sending alert to PagerDuty: AlertId={AlertId}, AlertType={AlertType}",
                    alert.AlertId, alert.AlertType);

                var client = new PagerDutyClient(_httpClient, routingKey, log);
                var result = await client.SendAlertAsync(alert);
                
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                log.LogInformation(
                    "PagerDuty send {Status}: AlertId={AlertId}, Duration={Duration}ms",
                    result ? "succeeded" : "failed", alert.AlertId, duration);
                
                return result;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error sending alert {AlertId} to PagerDuty: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false;
            }
        }

        private static async Task<bool> SendToTeamsAsync(Alert alert, ILogger log)
        {
            var sendStart = DateTime.UtcNow;
            
            try
            {
                var webhookUrls = new Dictionary<string, string>
                {
                    ["critical"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Critical"),
                    ["medium"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Medium"),
                    ["low"] = Environment.GetEnvironmentVariable("TeamsWebhookUrl-Low")
                };

                // Validate at least one webhook URL is configured
                if (!webhookUrls.Values.Any(url => !string.IsNullOrEmpty(url)))
                {
                    log.LogWarning("No Teams webhook URLs configured");
                    return false;
                }

                log.LogInformation(
                    "Sending alert to Teams: AlertId={AlertId}, AlertType={AlertType}, Severity={Severity}",
                    alert.AlertId, alert.AlertType, alert.Severity);

                var client = new TeamsClient(_httpClient, webhookUrls, log);
                var result = await client.SendAlertAsync(alert);
                
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                log.LogInformation(
                    "Teams send {Status}: AlertId={AlertId}, Duration={Duration}ms",
                    result ? "succeeded" : "failed", alert.AlertId, duration);
                
                return result;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                log.LogError(ex, 
                    "Error sending alert {AlertId} to Teams: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false;
            }
        }

        // Helper methods
        private static ControlMetadata GetControlMetadata(string controlId)
        {
            // Hardcoded control metadata (could load from config or Cosmos DB)
            var controls = new Dictionary<string, ControlMetadata>
            {
                ["SC-7"] = new ControlMetadata { Id = "SC-7", Name = "Boundary Protection", Category = "System and Communications Protection" },
                ["SC-8"] = new ControlMetadata { Id = "SC-8", Name = "Transmission Confidentiality and Integrity", Category = "System and Communications Protection" },
                ["SI-2"] = new ControlMetadata { Id = "SI-2", Name = "Flaw Remediation", Category = "System and Information Integrity" },
                ["SI-3"] = new ControlMetadata { Id = "SI-3", Name = "Malicious Code Protection", Category = "System and Information Integrity" },
                ["RA-5"] = new ControlMetadata { Id = "RA-5", Name = "Vulnerability Scanning", Category = "Risk Assessment" },
                ["CM-3"] = new ControlMetadata { Id = "CM-3", Name = "Configuration Change Control", Category = "Configuration Management" },
                ["IR-4"] = new ControlMetadata { Id = "IR-4", Name = "Incident Handling", Category = "Incident Response" },
                ["AC-3"] = new ControlMetadata { Id = "AC-3", Name = "Access Enforcement", Category = "Access Control" },
                ["CM-7"] = new ControlMetadata { Id = "CM-7", Name = "Least Functionality", Category = "Configuration Management" }
            };

            return controls.ContainsKey(controlId) 
                ? controls[controlId] 
                : new ControlMetadata { Id = controlId, Name = controlId, Category = "Unknown" };
        }

        private static string GetRunbookUrl(string alertType, string controlId)
        {
            var baseUrl = "https://wiki.contoso.com/runbooks";
            var slug = alertType.Replace("_", "-");
            return !string.IsNullOrEmpty(controlId) 
                ? $"{baseUrl}/{slug}-{controlId.ToLower()}" 
                : $"{baseUrl}/{slug}";
        }

        private static List<string> GetDefaultRemediationSteps(string alertType)
        {
            return alertType switch
            {
                "control_drift" => new List<string>
                {
                    "1. Review recent configuration changes in affected environment",
                    "2. Compare current state vs baseline",
                    "3. Identify root cause of drift",
                    "4. Apply remediation and validate"
                },
                "control_regression" => new List<string>
                {
                    "1. Check recent deployments",
                    "2. Review validation test results",
                    "3. Identify breaking change",
                    "4. Roll back or fix forward"
                },
                "threshold_breach" => new List<string>
                {
                    "1. Investigate failing controls",
                    "2. Assess impact and urgency",
                    "3. Prioritize remediation",
                    "4. Monitor compliance rate"
                },
                _ => new List<string>
                {
                    "1. Review alert details",
                    "2. Investigate root cause",
                    "3. Apply remediation",
                    "4. Validate fix"
                }
            };
        }
    }

    // Supporting classes
    public class Alert
    {
        [JsonProperty("alert_type")]
        public string AlertType { get; set; }

        [JsonProperty("alert_id")]
        public string AlertId { get; set; }

        [JsonProperty("severity")]
        public string Severity { get; set; }

        [JsonProperty("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonProperty("control")]
        public ControlInfo Control { get; set; }

        [JsonProperty("environment")]
        public string Environment { get; set; }

        [JsonProperty("region")]
        public string Region { get; set; }

        [JsonProperty("cloud")]
        public string Cloud { get; set; }

        [JsonProperty("metrics")]
        public Dictionary<string, object> Metrics { get; set; }

        [JsonProperty("runbook_url")]
        public string RunbookUrl { get; set; }

        [JsonProperty("remediation_steps")]
        public List<string> RemediationSteps { get; set; }

        [JsonProperty("vulnerabilities")]
        public List<VulnerabilityInfo> Vulnerabilities { get; set; }

        [JsonProperty("deadline")]
        public DeadlineInfo Deadline { get; set; }

        [JsonProperty("days_until_deadline")]
        public int? DaysUntilDeadline { get; set; }

        [JsonProperty("review_reason")]
        public string ReviewReason { get; set; }
    }

    public class ControlInfo
    {
        [JsonProperty("id")]
        public string Id { get; set; }

        [JsonProperty("name")]
        public string Name { get; set; }

        [JsonProperty("category")]
        public string Category { get; set; }
    }

    public class VulnerabilityInfo
    {
        [JsonProperty("vulnerability_id")]
        public string VulnerabilityId { get; set; }

        [JsonProperty("severity")]
        public string Severity { get; set; }

        [JsonProperty("cvss_score")]
        public double CvssScore { get; set; }

        [JsonProperty("package_name")]
        public string PackageName { get; set; }

        [JsonProperty("installed_version")]
        public string InstalledVersion { get; set; }

        [JsonProperty("fixed_version")]
        public string FixedVersion { get; set; }

        [JsonProperty("image_name")]
        public string ImageName { get; set; }
    }

    public class DeadlineInfo
    {
        [JsonProperty("id")]
        public string Id { get; set; }

        [JsonProperty("type")]
        public string Type { get; set; }

        [JsonProperty("description")]
        public string Description { get; set; }

        [JsonProperty("deadline_date")]
        public DateTime DeadlineDate { get; set; }
    }

    public class ControlMetadata
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Category { get; set; }
    }
}
