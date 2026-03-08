using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace FedRampDashboard.Functions
{
    public class AlertProcessor
    {
        private readonly ILogger<AlertProcessor> _logger;
        private static readonly HttpClient _httpClient = new HttpClient();
        private static ConnectionMultiplexer _redis;

        public AlertProcessor(ILogger<AlertProcessor> logger)
        {
            _logger = logger;
        }

        [Function("AlertProcessor")]
        public async Task<HttpResponseData> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequestData req)
        {
            var startTime = DateTime.UtcNow;
            _logger.LogInformation("AlertProcessor triggered at {Timestamp}", startTime);

            try
            {
                // Initialize Redis connection if not already done
                if (_redis == null || !_redis.IsConnected)
                {
                    var redisConnection = Environment.GetEnvironmentVariable("RedisConnectionString");
                    _redis = ConnectionMultiplexer.Connect(redisConnection);
                    _logger.LogInformation("Redis connection established");
                }

                // Parse incoming alert
                var alert = await JsonSerializer.DeserializeAsync<Alert>(req.Body);

                if (alert == null)
                {
                    _logger.LogWarning("Invalid alert payload received");
                    var badResponse = req.CreateResponse(HttpStatusCode.BadRequest);
                    await badResponse.WriteAsJsonAsync(new { error = "Invalid alert payload" });
                    return badResponse;
                }

                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["AlertId"] = alert.AlertId,
                    ["AlertType"] = alert.AlertType,
                    ["Severity"] = alert.Severity,
                    ["Environment"] = alert.Environment,
                    ["ControlId"] = alert.Control?.Id ?? "none"
                }))
                {
                    _logger.LogInformation(
                        "Processing alert: AlertId={AlertId}, Type={AlertType}, Severity={Severity}, Environment={Environment}",
                        alert.AlertId, alert.AlertType, alert.Severity, alert.Environment);

                    // Step 1: Enrich alert with metadata
                    var enrichStart = DateTime.UtcNow;
                    await EnrichAlertAsync(alert, _logger);
                    _logger.LogInformation("Alert enrichment completed in {Duration}ms", 
                        (DateTime.UtcNow - enrichStart).TotalMilliseconds);

                    // Step 2: Check for duplicates (30-min window)
                    if (await IsDuplicateAsync(alert, _logger))
                    {
                        _logger.LogInformation("Alert {AlertId} is duplicate. Skipping.", alert.AlertId);
                        var duplicateResponse = req.CreateResponse(HttpStatusCode.OK);
                        await duplicateResponse.WriteAsJsonAsync(new { status = "duplicate", alert_id = alert.AlertId });
                        return duplicateResponse;
                    }

                    // Step 3: Check suppression rules
                    if (await IsSuppressedAsync(alert, _logger))
                    {
                        _logger.LogInformation("Alert {AlertId} is suppressed. Skipping.", alert.AlertId);
                        var suppressedResponse = req.CreateResponse(HttpStatusCode.OK);
                        await suppressedResponse.WriteAsJsonAsync(new { status = "suppressed", alert_id = alert.AlertId });
                        return suppressedResponse;
                    }

                    // Step 4: Route alert based on severity
                    var routingStart = DateTime.UtcNow;
                    var routingResults = await RouteAlertAsync(alert, _logger);
                    _logger.LogInformation("Alert routing completed in {Duration}ms", 
                        (DateTime.UtcNow - routingStart).TotalMilliseconds);

                    // Step 5: Store alert in cache for deduplication
                    await StoreAlertInCacheAsync(alert, _logger);

                    // Step 6: logger to Application Insights for audit trail
                    var totalDuration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                    _logger.LogInformation(
                        "Alert processed successfully: AlertId={AlertId}, Routing={Routing}, TotalDuration={Duration}ms",
                        alert.AlertId, JsonSerializer.Serialize(routingResults), totalDuration);

                    var response = req.CreateResponse(HttpStatusCode.OK);
                    await response.WriteAsJsonAsync(new
                    {
                        status = "processed",
                        alert_id = alert.AlertId,
                        routing = routingResults,
                        processing_time_ms = totalDuration
                    });
                    return response;
                }
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogError(ex, "Error processing alert. Duration={Duration}ms", duration);
                var errorResponse = req.CreateResponse(HttpStatusCode.InternalServerError);
                await errorResponse.WriteAsJsonAsync(new { error = "Internal server error" });
                return errorResponse;
            }
        }

        private static async Task EnrichAlertAsync(Alert alert, ILogger logger)
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
                    
                    logger.LogInformation(
                        "Control metadata enriched: ControlId={ControlId}, ControlName={ControlName}, Category={Category}",
                        alert.Control.Id, alert.Control.Name, alert.Control.Category);
                }

                // Attach runbook URL
                if (string.IsNullOrEmpty(alert.RunbookUrl))
                {
                    alert.RunbookUrl = GetRunbookUrl(alert.AlertType, alert.Control?.Id);
                    logger.LogInformation("Runbook URL attached: {RunbookUrl}", alert.RunbookUrl);
                }

                // Add default remediation steps if missing
                if (alert.RemediationSteps == null || !alert.RemediationSteps.Any())
                {
                    alert.RemediationSteps = GetDefaultRemediationSteps(alert.AlertType);
                    logger.LogInformation(
                        "Default remediation steps added: Count={StepCount}",
                        alert.RemediationSteps.Count);
                }
                
                var duration = (DateTime.UtcNow - enrichStart).TotalMilliseconds;
                logger.LogInformation(
                    "Alert enrichment completed: AlertId={AlertId}, Duration={Duration}ms",
                    alert.AlertId, duration);
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - enrichStart).TotalMilliseconds;
                logger.LogError(ex, 
                    "Error enriching alert {AlertId}: Duration={Duration}ms", 
                    alert.AlertId, duration);
                throw;
            }
        }

        private static async Task<bool> IsDuplicateAsync(Alert alert, ILogger logger)
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
                    logger.LogWarning(
                        "Duplicate alert detected: AlertId={AlertId}, DedupKey={DedupKey}, Duration={Duration}ms",
                        alert.AlertId, dedupKey, duration);
                }
                
                return exists;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - checkStart).TotalMilliseconds;
                logger.LogError(ex, 
                    "Error checking for duplicate alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false; // If cache is down, allow alert through
            }
        }

        private static async Task<bool> IsSuppressedAsync(Alert alert, ILogger logger)
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
                    logger.LogInformation(
                        "Alert suppressed: AlertId={AlertId}, Reason=Acknowledged, AckKey={AckKey}, Duration={Duration}ms",
                        alert.AlertId, ackKey, duration);
                    return true;
                }

                // Could check maintenance windows from Cosmos DB here
                // For now, just check cache

                var totalDuration = (DateTime.UtcNow - suppressCheckStart).TotalMilliseconds;
                logger.LogInformation(
                    "Suppression check passed: AlertId={AlertId}, Duration={Duration}ms",
                    alert.AlertId, totalDuration);
                
                return false;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - suppressCheckStart).TotalMilliseconds;
                logger.LogError(ex, 
                    "Error checking suppression rules for alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false; // If cache is down, allow alert through
            }
        }

        private static async Task<Dictionary<string, bool>> RouteAlertAsync(Alert alert, ILogger logger)
        {
            var routeStart = DateTime.UtcNow;
            var results = new Dictionary<string, bool>();

            try
            {
                logger.LogInformation(
                    "Starting alert routing: AlertId={AlertId}, Severity={Severity}",
                    alert.AlertId, alert.Severity);

                // Routing logic based on severity
                switch (alert.Severity)
                {
                    case "P0":
                        // P0: PagerDuty only (urgent)
                        results["pagerduty"] = await SendToPagerDutyAsync(alert, logger);
                        logger.LogInformation("Alert routed to PagerDuty: AlertId={AlertId}, Result={Result}", 
                            alert.AlertId, results["pagerduty"]);
                        break;

                    case "P1":
                        // P1: PagerDuty (low urgency) + Teams
                        results["pagerduty"] = await SendToPagerDutyAsync(alert, logger);
                        results["teams"] = await SendToTeamsAsync(alert, logger);
                        logger.LogInformation(
                            "Alert routed to PagerDuty and Teams: AlertId={AlertId}, PagerDuty={PagerDutyResult}, Teams={TeamsResult}",
                            alert.AlertId, results["pagerduty"], results["teams"]);
                        break;

                    case "P2":
                        // P2: Teams only
                        results["teams"] = await SendToTeamsAsync(alert, logger);
                        logger.LogInformation("Alert routed to Teams: AlertId={AlertId}, Result={Result}",
                            alert.AlertId, results["teams"]);
                        break;

                    case "P3":
                        // P3: logger only (could implement email digest here)
                        logger.LogInformation("P3 alert logged: AlertId={AlertId}, AlertType={AlertType}", 
                            alert.AlertId, alert.AlertType);
                        results["logged"] = true;
                        break;

                    default:
                        logger.LogWarning(
                            "Unknown severity encountered: AlertId={AlertId}, Severity={Severity}. Routing to Teams.",
                            alert.AlertId, alert.Severity);
                        results["teams"] = await SendToTeamsAsync(alert, logger);
                        break;
                }
                
                var duration = (DateTime.UtcNow - routeStart).TotalMilliseconds;
                logger.LogInformation(
                    "Alert routing completed: AlertId={AlertId}, Routes={RouteCount}, Duration={Duration}ms",
                    alert.AlertId, results.Count, duration);

                return results;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - routeStart).TotalMilliseconds;
                logger.LogError(ex,
                    "Error routing alert {AlertId}: Duration={Duration}ms",
                    alert.AlertId, duration);
                throw;
            }
        }

        private static async Task StoreAlertInCacheAsync(Alert alert, ILogger logger)
        {
            var cacheStart = DateTime.UtcNow;
            
            try
            {
                var db = _redis.GetDatabase();
                var dedupKey = AlertHelper.GenerateDedupKey(alert.AlertType, alert.Control?.Id, alert.Environment);
                
                // Store with 30-minute TTL
                await db.StringSetAsync(dedupKey, alert.AlertId, TimeSpan.FromMinutes(30));
                
                var duration = (DateTime.UtcNow - cacheStart).TotalMilliseconds;
                logger.LogInformation(
                    "Alert stored in cache: AlertId={AlertId}, DedupKey={DedupKey}, TTL=30min, Duration={Duration}ms",
                    alert.AlertId, dedupKey, duration);
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - cacheStart).TotalMilliseconds;
                logger.LogError(ex, 
                    "Error storing alert {AlertId} in cache: Duration={Duration}ms",
                    alert.AlertId, duration);
            }
        }

        private static async Task<bool> SendToPagerDutyAsync(Alert alert, ILogger logger)
        {
            var sendStart = DateTime.UtcNow;
            
            try
            {
                var routingKey = Environment.GetEnvironmentVariable("PagerDutyRoutingKey");
                if (string.IsNullOrEmpty(routingKey))
                {
                    logger.LogWarning("PagerDuty routing key not configured");
                    return false;
                }

                logger.LogInformation(
                    "Sending alert to PagerDuty: AlertId={AlertId}, AlertType={AlertType}",
                    alert.AlertId, alert.AlertType);

                var client = new PagerDutyClient(_httpClient, routingKey, logger);
                var result = await client.SendAlertAsync(alert);
                
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                logger.LogInformation(
                    "PagerDuty send {Status}: AlertId={AlertId}, Duration={Duration}ms",
                    result ? "succeeded" : "failed", alert.AlertId, duration);
                
                return result;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                logger.LogError(ex, 
                    "Error sending alert {AlertId} to PagerDuty: Duration={Duration}ms",
                    alert.AlertId, duration);
                return false;
            }
        }

        private static async Task<bool> SendToTeamsAsync(Alert alert, ILogger logger)
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
                    logger.LogWarning("No Teams webhook URLs configured");
                    return false;
                }

                logger.LogInformation(
                    "Sending alert to Teams: AlertId={AlertId}, AlertType={AlertType}, Severity={Severity}",
                    alert.AlertId, alert.AlertType, alert.Severity);

                var client = new TeamsClient(_httpClient, webhookUrls, logger);
                var result = await client.SendAlertAsync(alert);
                
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                logger.LogInformation(
                    "Teams send {Status}: AlertId={AlertId}, Duration={Duration}ms",
                    result ? "succeeded" : "failed", alert.AlertId, duration);
                
                return result;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - sendStart).TotalMilliseconds;
                logger.LogError(ex, 
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
        [JsonPropertyName("alert_type")]
        public string AlertType { get; set; }

        [JsonPropertyName("alert_id")]
        public string AlertId { get; set; }

        [JsonPropertyName("severity")]
        public string Severity { get; set; }

        [JsonPropertyName("timestamp")]
        public DateTime Timestamp { get; set; }

        [JsonPropertyName("control")]
        public ControlInfo Control { get; set; }

        [JsonPropertyName("environment")]
        public string Environment { get; set; }

        [JsonPropertyName("region")]
        public string Region { get; set; }

        [JsonPropertyName("cloud")]
        public string Cloud { get; set; }

        [JsonPropertyName("metrics")]
        public Dictionary<string, object> Metrics { get; set; }

        [JsonPropertyName("runbook_url")]
        public string RunbookUrl { get; set; }

        [JsonPropertyName("remediation_steps")]
        public List<string> RemediationSteps { get; set; }

        [JsonPropertyName("vulnerabilities")]
        public List<VulnerabilityInfo> Vulnerabilities { get; set; }

        [JsonPropertyName("deadline")]
        public DeadlineInfo Deadline { get; set; }

        [JsonPropertyName("days_until_deadline")]
        public int? DaysUntilDeadline { get; set; }

        [JsonPropertyName("review_reason")]
        public string ReviewReason { get; set; }
    }

    public class VulnerabilityInfo
    {
        [JsonPropertyName("vulnerability_id")]
        public string VulnerabilityId { get; set; }

        [JsonPropertyName("severity")]
        public string Severity { get; set; }

        [JsonPropertyName("cvss_score")]
        public double CvssScore { get; set; }

        [JsonPropertyName("package_name")]
        public string PackageName { get; set; }

        [JsonPropertyName("installed_version")]
        public string InstalledVersion { get; set; }

        [JsonPropertyName("fixed_version")]
        public string FixedVersion { get; set; }

        [JsonPropertyName("image_name")]
        public string ImageName { get; set; }
    }

    public class DeadlineInfo
    {
        [JsonPropertyName("id")]
        public string Id { get; set; }

        [JsonPropertyName("type")]
        public string Type { get; set; }

        [JsonPropertyName("description")]
        public string Description { get; set; }

        [JsonPropertyName("deadline_date")]
        public DateTime DeadlineDate { get; set; }
    }

    public class ControlMetadata
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Category { get; set; }
    }
}
