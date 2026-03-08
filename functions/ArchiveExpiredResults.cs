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

            var startTime = DateTime.UtcNow;
            _logger.LogInformation(
                "Processing {Count} Cosmos DB documents for archival", 
                documents.Count);

            var containerClient = _blobServiceClient.GetBlobContainerClient(_archiveContainerName);
            await containerClient.CreateIfNotExistsAsync();

            int successCount = 0;
            int errorCount = 0;
            int skippedCount = 0;
            long totalBytesArchived = 0;

            foreach (var doc in documents)
            {
                try
                {
                    // Check if document has TTL expired (deletion event)
                    var ttl = doc.GetPropertyValue<int?>("ttl");
                    if (ttl.HasValue && ttl.Value > 0)
                    {
                        skippedCount++;
                        continue;
                    }

                    var docId = doc.Id;
                    using (_logger.BeginScope(new Dictionary<string, object>
                    {
                        ["DocumentId"] = docId,
                        ["Environment"] = doc.GetPropertyValue<string>("environment") ?? "unknown"
                    }))
                    {
                        var archiveStart = DateTime.UtcNow;
                        var bytesArchived = await ArchiveDocumentAsync(containerClient, doc);
                        var archiveDuration = (DateTime.UtcNow - archiveStart).TotalMilliseconds;
                        
                        totalBytesArchived += bytesArchived;
                        successCount++;
                        
                        _logger.LogInformation(
                            "Document archived: DocumentId={DocumentId}, Size={Size} bytes, Duration={Duration}ms",
                            docId, bytesArchived, archiveDuration);
                    }
                }
                catch (Exception ex)
                {
                    errorCount++;
                    _logger.LogError(ex, "Failed to archive document {DocumentId}", doc.Id);
                }
            }

            var totalDuration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            _logger.LogInformation(
                "Archival batch complete: Success={SuccessCount}, Errors={ErrorCount}, Skipped={SkippedCount}, TotalBytes={TotalBytes}, Duration={Duration}ms",
                successCount, errorCount, skippedCount, totalBytesArchived, totalDuration);
        }

        private async Task<long> ArchiveDocumentAsync(BlobContainerClient containerClient, Document document)
        {
            var archiveStart = DateTime.UtcNow;
            
            try
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

                var originalSizeBytes = Encoding.UTF8.GetByteCount(json);
                var compressedSizeBytes = compressedStream.Length;
                var compressionRatio = (1.0 - (double)compressedSizeBytes / originalSizeBytes) * 100;

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

                var duration = (DateTime.UtcNow - archiveStart).TotalMilliseconds;
                _logger.LogInformation(
                    "Document archived successfully: DocumentId={DocumentId}, BlobPath={BlobPath}, OriginalSize={OriginalSizeKb}KB, CompressedSize={CompressedSizeKb}KB, Compression={CompressionRatio}%, AccessTier=Archive, Duration={Duration}ms",
                    document.Id,
                    blobName,
                    originalSizeBytes / 1024,
                    compressedSizeBytes / 1024,
                    compressionRatio,
                    duration);

                return compressedSizeBytes;
            }
            catch (Exception ex)
            {
                var duration = (DateTime.UtcNow - archiveStart).TotalMilliseconds;
                _logger.LogError(ex,
                    "Error archiving document {DocumentId}: Duration={Duration}ms",
                    document.Id, duration);
                throw;
            }
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
