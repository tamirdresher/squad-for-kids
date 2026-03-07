using System;
using System.IO;
using System.IO.Compression;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FedRampDashboard.Functions
{
    /// <summary>
    /// Archives expired Cosmos DB documents to Azure Blob Storage (cold archive)
    /// Triggered by: Cosmos DB change feed (TTL expiration events)
    /// </summary>
    public class ArchiveExpiredResults
    {
        private readonly ILogger<ArchiveExpiredResults> _logger;
        private readonly BlobServiceClient _blobServiceClient;
        
        private readonly string _storageAccountName;
        private readonly string _archiveContainerName;

        public ArchiveExpiredResults(ILogger<ArchiveExpiredResults> logger)
        {
            _logger = logger;
            
            _storageAccountName = Environment.GetEnvironmentVariable("StorageAccountName") 
                ?? throw new InvalidOperationException("StorageAccountName not configured");
            _archiveContainerName = Environment.GetEnvironmentVariable("ArchiveContainerName") ?? "validation-archive";
            
            // Initialize Blob Service client with Managed Identity
            var credential = new DefaultAzureCredential();
            var storageUri = new Uri($"https://{_storageAccountName}.blob.core.windows.net");
            _blobServiceClient = new BlobServiceClient(storageUri, credential);
        }

        [Function("ArchiveExpiredResults")]
        public async Task RunAsync(
            [CosmosDBTrigger(
                databaseName: "SecurityDashboard",
                containerName: "ControlValidationResults",
                Connection = "CosmosDbEndpoint",
                LeaseContainerName = "leases",
                CreateLeaseContainerIfNotExists = true)] 
            IReadOnlyList<Document> documents)
        {
            if (documents == null || documents.Count == 0)
            {
                return;
            }

            _logger.LogInformation("Processing {Count} expired Cosmos DB documents for archival", documents.Count);

            var containerClient = _blobServiceClient.GetBlobContainerClient(_archiveContainerName);
            await containerClient.CreateIfNotExistsAsync();

            int successCount = 0;
            int errorCount = 0;

            foreach (var doc in documents)
            {
                try
                {
                    // Check if document has TTL expired (deletion event)
                    // In Cosmos DB change feed, expired documents appear with _ts (time-to-live) metadata
                    var ttl = doc.GetPropertyValue<int?>("ttl");
                    if (ttl.HasValue && ttl.Value > 0)
                    {
                        // Document is not expired yet, skip
                        continue;
                    }

                    await ArchiveDocumentAsync(containerClient, doc);
                    successCount++;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to archive document {DocumentId}", doc.Id);
                    errorCount++;
                }
            }

            _logger.LogInformation(
                "Archival complete: {SuccessCount} succeeded, {ErrorCount} failed",
                successCount,
                errorCount);
        }

        private async Task ArchiveDocumentAsync(BlobContainerClient containerClient, Document document)
        {
            // Extract timestamp for organizing blobs by date
            var timestamp = document.GetPropertyValue<DateTime>("timestamp");
            var year = timestamp.Year;
            var month = timestamp.Month.ToString("D2");
            var day = timestamp.Day.ToString("D2");

            // Build blob path: validation-archive/YYYY/MM/DD/{environment}/{document-id}.json.gz
            var environment = document.GetPropertyValue<string>("environment");
            var blobName = $"{year}/{month}/{day}/{environment}/{document.Id}.json.gz";

            var blobClient = containerClient.GetBlobClient(blobName);

            // Serialize document to JSON
            var json = JsonSerializer.Serialize(document, new JsonSerializerOptions 
            { 
                WriteIndented = false 
            });

            // Compress with gzip
            using var compressedStream = new MemoryStream();
            using (var gzipStream = new GZipStream(compressedStream, CompressionMode.Compress, leaveOpen: true))
            using (var writer = new StreamWriter(gzipStream, Encoding.UTF8))
            {
                await writer.WriteAsync(json);
            }
            compressedStream.Position = 0;

            // Upload to Blob Storage with Archive access tier
            var uploadOptions = new BlobUploadOptions
            {
                AccessTier = Azure.Storage.Blobs.Models.AccessTier.Archive,
                Metadata = new Dictionary<string, string>
                {
                    { "environment", environment },
                    { "control_id", document.GetPropertyValue<string>("control")?.GetPropertyValue<string>("id") ?? "unknown" },
                    { "timestamp", timestamp.ToString("O") },
                    { "archived_at", DateTimeOffset.UtcNow.ToString("O") }
                }
            };

            await blobClient.UploadAsync(compressedStream, uploadOptions);

            _logger.LogInformation(
                "Archived document {DocumentId} to blob {BlobName} (size: {Size} bytes compressed)",
                document.Id,
                blobName,
                compressedStream.Length);
        }
    }

    // Helper class for Cosmos DB document
    public class Document
    {
        private readonly Dictionary<string, object> _properties = new();

        public string Id => GetPropertyValue<string>("id");

        public T GetPropertyValue<T>(string propertyName)
        {
            if (_properties.TryGetValue(propertyName, out var value))
            {
                if (value is T typedValue)
                {
                    return typedValue;
                }
                
                // Handle JSON element conversion
                if (value is JsonElement jsonElement)
                {
                    return JsonSerializer.Deserialize<T>(jsonElement.GetRawText());
                }
            }
            
            return default;
        }
    }
}
