using System;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Monitor.Ingestion;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FedRampDashboard.Functions
{
    public class ProcessValidationResults
    {
        private readonly ILogger<ProcessValidationResults> _logger;
        private readonly CosmosClient _cosmosClient;
        private readonly LogsIngestionClient _logsClient;
        
        // Configuration from environment variables
        private readonly string _cosmosDbEndpoint;
        private readonly string _cosmosDbDatabase;
        private readonly string _cosmosDbContainer;
        private readonly string _logAnalyticsDceEndpoint;
        private readonly string _logAnalyticsDcrImmutableId;

        public ProcessValidationResults(ILogger<ProcessValidationResults> logger)
        {
            _logger = logger;
            
            // Cosmos DB configuration
            _cosmosDbEndpoint = Environment.GetEnvironmentVariable("CosmosDbEndpoint") 
                ?? throw new InvalidOperationException("CosmosDbEndpoint not configured");
            _cosmosDbDatabase = Environment.GetEnvironmentVariable("CosmosDbDatabase") ?? "SecurityDashboard";
            _cosmosDbContainer = Environment.GetEnvironmentVariable("CosmosDbContainer") ?? "ControlValidationResults";
            
            // Log Analytics configuration (optional)
            _logAnalyticsDceEndpoint = Environment.GetEnvironmentVariable("LogAnalyticsDceEndpoint");
            _logAnalyticsDcrImmutableId = Environment.GetEnvironmentVariable("LogAnalyticsDcrImmutableId");
            
            // Initialize Cosmos DB client with Managed Identity
            var credential = new DefaultAzureCredential();
            _cosmosClient = new CosmosClient(_cosmosDbEndpoint, credential);
            
            // Initialize Log Analytics client (if configured)
            if (!string.IsNullOrEmpty(_logAnalyticsDceEndpoint) && !string.IsNullOrEmpty(_logAnalyticsDcrImmutableId))
            {
                _logsClient = new LogsIngestionClient(new Uri(_logAnalyticsDceEndpoint), credential);
            }
        }

        /// <summary>
        /// Process validation results from Azure Monitor Event Grid
        /// Triggered by: Event Grid subscription on Azure Monitor custom metrics
        /// </summary>
        [Function("ProcessValidationResults")]
        public async Task RunAsync(
            [EventGridTrigger] EventGridEvent eventGridEvent)
        {
            var startTime = DateTime.UtcNow;
            
            try
            {
                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["EventId"] = eventGridEvent.Id,
                    ["EventType"] = eventGridEvent.EventType
                }))
                {
                    _logger.LogInformation(
                        "Processing validation result event: EventId={EventId}, EventType={EventType}",
                        eventGridEvent.Id, eventGridEvent.EventType);
                    
                    // Parse event data
                    var validationResult = JsonSerializer.Deserialize<ValidationResult>(eventGridEvent.Data.ToString());
                    
                    if (validationResult == null)
                    {
                        _logger.LogWarning("Failed to parse validation result from event {EventId}", eventGridEvent.Id);
                        return;
                    }
                    
                    using (_logger.BeginScope(new Dictionary<string, object>
                    {
                        ["ControlId"] = validationResult.ControlId,
                        ["Environment"] = validationResult.Environment,
                        ["Status"] = validationResult.Status
                    }))
                    {
                        _logger.LogInformation(
                            "Validation result parsed: ControlId={ControlId}, Environment={Environment}, Status={Status}, TestName={TestName}",
                            validationResult.ControlId, validationResult.Environment, 
                            validationResult.Status, validationResult.TestName);
                        
                        // Transform to Cosmos DB document
                        var cosmosDocument = TransformToCosmosDocument(validationResult);
                        
                        // Write to Cosmos DB
                        var cosmosStart = DateTime.UtcNow;
                        await WriteToCosmosDbAsync(cosmosDocument);
                        var cosmosDuration = (DateTime.UtcNow - cosmosStart).TotalMilliseconds;
                        _logger.LogInformation("Cosmos DB write completed in {Duration}ms", cosmosDuration);
                        
                        // Write to Log Analytics (if configured)
                        if (_logsClient != null)
                        {
                            var logAnalyticsStart = DateTime.UtcNow;
                            await WriteToLogAnalyticsAsync(validationResult);
                            var logAnalyticsDuration = (DateTime.UtcNow - logAnalyticsStart).TotalMilliseconds;
                            _logger.LogInformation("Log Analytics write completed in {Duration}ms", logAnalyticsDuration);
                        }
                        
                        var totalDuration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                        _logger.LogInformation(
                            "Successfully processed validation result: ControlId={ControlId}, TestName={TestName}, Status={Status}, TotalDuration={Duration}ms",
                            validationResult.ControlId, validationResult.TestName, validationResult.Status, totalDuration);
                    }
                }
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogError(ex, 
                    "Error processing validation result event: EventId={EventId}, Duration={Duration}ms", 
                    eventGridEvent.Id, duration);
                throw; // Trigger retry via Azure Functions runtime
            }
        }

        /// <summary>
        /// HTTP-triggered endpoint for direct validation result submission
        /// Alternative to Event Grid for testing and manual submissions
        /// </summary>
        [Function("SubmitValidationResult")]
        public async Task<HttpResponseData> SubmitAsync(
            [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
        {
            var startTime = DateTime.UtcNow;
            
            try
            {
                _logger.LogInformation("Received HTTP validation result submission");
                
                // Parse request body
                var validationResult = await JsonSerializer.DeserializeAsync<ValidationResult>(req.Body);
                
                if (validationResult == null)
                {
                    _logger.LogWarning("Invalid validation result JSON received");
                    var badRequestResponse = req.CreateResponse(System.Net.HttpStatusCode.BadRequest);
                    await badRequestResponse.WriteStringAsync("Invalid validation result JSON");
                    return badRequestResponse;
                }
                
                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["ControlId"] = validationResult.ControlId,
                    ["Environment"] = validationResult.Environment,
                    ["Status"] = validationResult.Status
                }))
                {
                    _logger.LogInformation(
                        "Processing validation result: ControlId={ControlId}, Environment={Environment}, Status={Status}",
                        validationResult.ControlId, validationResult.Environment, validationResult.Status);
                    
                    // Transform and store
                    var cosmosDocument = TransformToCosmosDocument(validationResult);
                    await WriteToCosmosDbAsync(cosmosDocument);
                    
                    if (_logsClient != null)
                    {
                        await WriteToLogAnalyticsAsync(validationResult);
                    }
                    
                    var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                    _logger.LogInformation(
                        "Validation result stored successfully: Id={Id}, Duration={Duration}ms",
                        cosmosDocument.Id, duration);
                    
                    // Return success
                    var response = req.CreateResponse(System.Net.HttpStatusCode.OK);
                    await response.WriteAsJsonAsync(new { 
                        message = "Validation result stored successfully",
                        id = cosmosDocument.Id,
                        timestamp = cosmosDocument.Timestamp,
                        processing_time_ms = duration
                    });
                    
                    return response;
                }
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
                _logger.LogError(ex, 
                    "Error processing HTTP validation result submission. Duration={Duration}ms", 
                    duration);
                
                var errorResponse = req.CreateResponse(System.Net.HttpStatusCode.InternalServerError);
                await errorResponse.WriteStringAsync($"Error: {ex.Message}");
                return errorResponse;
            }
        }

        private CosmosDocument TransformToCosmosDocument(ValidationResult result)
        {
            // Generate deterministic ID for deduplication
            var id = $"{result.Environment}-{result.ControlId}-{result.Timestamp:yyyyMMdd-HHmmss}".ToLowerInvariant();
            
            return new CosmosDocument
            {
                Id = id,
                Environment = result.Environment,
                Cluster = result.Cluster,
                Region = result.Region,
                Cloud = result.Cloud,
                Control = new ControlInfo
                {
                    Id = result.ControlId,
                    Name = result.ControlName,
                    Category = GetControlCategory(result.ControlId)
                },
                Test = new TestInfo
                {
                    Category = result.TestCategory,
                    Name = result.TestName,
                    Status = result.Status,
                    ExecutionTimeMs = result.ExecutionTimeMs
                },
                Details = result.Details,
                Metadata = new MetadataInfo
                {
                    PipelineId = result.Metadata?.PipelineId,
                    PipelineUrl = result.Metadata?.PipelineUrl,
                    CommitSha = result.Metadata?.CommitSha,
                    CommitMessage = result.Metadata?.CommitMessage,
                    Branch = result.Metadata?.Branch,
                    TriggeredBy = result.Metadata?.TriggeredBy,
                    IngestionTimestamp = DateTimeOffset.UtcNow
                },
                Timestamp = result.Timestamp,
                Ttl = 7776000 // 90 days in seconds
            };
        }

        private async Task WriteToCosmosDbAsync(CosmosDocument document)
        {
            var container = _cosmosClient.GetContainer(_cosmosDbDatabase, _cosmosDbContainer);
            
            // Upsert document (handles deduplication via ID)
            var response = await container.UpsertItemAsync(
                document,
                new PartitionKey(document.Environment));
            
            _logger.LogInformation(
                "Wrote to Cosmos DB: {Id}, RU charge: {RU}",
                document.Id,
                response.RequestCharge);
        }

        private async Task WriteToLogAnalyticsAsync(ValidationResult result)
        {
            if (_logsClient == null)
            {
                return;
            }
            
            try
            {
                var logEntry = new[]
                {
                    new
                    {
                        TimeGenerated = result.Timestamp,
                        Environment_s = result.Environment,
                        Cluster_s = result.Cluster,
                        ControlId_s = result.ControlId,
                        ControlName_s = result.ControlName,
                        TestCategory_s = result.TestCategory,
                        TestName_s = result.TestName,
                        Status_s = result.Status,
                        ExecutionTimeMs_d = result.ExecutionTimeMs,
                        Details_s = JsonSerializer.Serialize(result.Details),
                        PipelineId_s = result.Metadata?.PipelineId,
                        CommitSha_s = result.Metadata?.CommitSha
                    }
                };
                
                await _logsClient.UploadAsync(
                    _logAnalyticsDcrImmutableId,
                    "Custom-ControlValidationResults_CL",
                    logEntry);
                
                _logger.LogInformation("Wrote to Log Analytics");
            }
            catch (Exception ex)
            {
                // Log but don't fail - Log Analytics ingestion is best-effort
                _logger.LogWarning(ex, "Failed to write to Log Analytics");
            }
        }

        private static string GetControlCategory(string controlId)
        {
            // Map FedRAMP control IDs to categories
            return controlId switch
            {
                var c when c.StartsWith("SC-") => "System and Communications Protection",
                var c when c.StartsWith("SI-") => "System and Information Integrity",
                var c when c.StartsWith("AC-") => "Access Control",
                var c when c.StartsWith("CM-") => "Configuration Management",
                var c when c.StartsWith("RA-") => "Risk Assessment",
                var c when c.StartsWith("IR-") => "Incident Response",
                _ => "Unknown"
            };
        }
    }

    // Data models
    public class ValidationResult
    {
        public DateTimeOffset Timestamp { get; set; }
        public string Environment { get; set; }
        public string Cluster { get; set; }
        public string Region { get; set; }
        public string Cloud { get; set; }
        public string ControlId { get; set; }
        public string ControlName { get; set; }
        public string TestCategory { get; set; }
        public string TestName { get; set; }
        public string Status { get; set; }
        public int ExecutionTimeMs { get; set; }
        public JsonElement Details { get; set; }
        public MetadataResult Metadata { get; set; }
    }

    public class MetadataResult
    {
        public string PipelineId { get; set; }
        public string PipelineUrl { get; set; }
        public string CommitSha { get; set; }
        public string CommitMessage { get; set; }
        public string Branch { get; set; }
        public string TriggeredBy { get; set; }
    }

    public class CosmosDocument
    {
        [JsonPropertyName("id")]
        public string Id { get; set; }
        
        [JsonPropertyName("environment")]
        public string Environment { get; set; }
        
        [JsonPropertyName("cluster")]
        public string Cluster { get; set; }
        
        [JsonPropertyName("region")]
        public string Region { get; set; }
        
        [JsonPropertyName("cloud")]
        public string Cloud { get; set; }
        
        [JsonPropertyName("control")]
        public ControlInfo Control { get; set; }
        
        [JsonPropertyName("test")]
        public TestInfo Test { get; set; }
        
        [JsonPropertyName("details")]
        public JsonElement Details { get; set; }
        
        [JsonPropertyName("metadata")]
        public MetadataInfo Metadata { get; set; }
        
        [JsonPropertyName("timestamp")]
        public DateTimeOffset Timestamp { get; set; }
        
        [JsonPropertyName("ttl")]
        public int Ttl { get; set; }
    }

    public class ControlInfo
    {
        [JsonPropertyName("id")]
        public string Id { get; set; }
        
        [JsonPropertyName("name")]
        public string Name { get; set; }
        
        [JsonPropertyName("category")]
        public string Category { get; set; }
    }

    public class TestInfo
    {
        [JsonPropertyName("category")]
        public string Category { get; set; }
        
        [JsonPropertyName("name")]
        public string Name { get; set; }
        
        [JsonPropertyName("status")]
        public string Status { get; set; }
        
        [JsonPropertyName("execution_time_ms")]
        public int ExecutionTimeMs { get; set; }
    }

    public class MetadataInfo
    {
        [JsonPropertyName("pipeline_id")]
        public string PipelineId { get; set; }
        
        [JsonPropertyName("pipeline_url")]
        public string PipelineUrl { get; set; }
        
        [JsonPropertyName("commit_sha")]
        public string CommitSha { get; set; }
        
        [JsonPropertyName("commit_message")]
        public string CommitMessage { get; set; }
        
        [JsonPropertyName("branch")]
        public string Branch { get; set; }
        
        [JsonPropertyName("triggered_by")]
        public string TriggeredBy { get; set; }
        
        [JsonPropertyName("ingestion_timestamp")]
        public DateTimeOffset IngestionTimestamp { get; set; }
    }

    // Event Grid event model
    public class EventGridEvent
    {
        public string Id { get; set; }
        public string EventType { get; set; }
        public string Subject { get; set; }
        public DateTimeOffset EventTime { get; set; }
        public JsonElement Data { get; set; }
    }
}
