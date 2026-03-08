using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace FedRampDashboard.Api.Services;

public class CacheTelemetryService : ICacheTelemetryService
{
    private readonly TelemetryClient _telemetryClient;
    private readonly ILogger<CacheTelemetryService> _logger;

    public CacheTelemetryService(TelemetryClient telemetryClient, ILogger<CacheTelemetryService> logger)
    {
        _telemetryClient = telemetryClient;
        _logger = logger;
    }

    public void TrackCacheHit(string endpoint, string environment, string? controlCategory, double duration)
    {
        TrackCacheEvent("CacheHit", endpoint, environment, controlCategory, duration, "HIT");
    }

    public void TrackCacheMiss(string endpoint, string environment, string? controlCategory, double duration)
    {
        TrackCacheEvent("CacheMiss", endpoint, environment, controlCategory, duration, "MISS");
    }

    private void TrackCacheEvent(
        string eventName, 
        string endpoint, 
        string environment, 
        string? controlCategory, 
        double duration, 
        string status)
    {
        var eventTelemetry = new EventTelemetry(eventName)
        {
            Timestamp = DateTimeOffset.UtcNow
        };

        eventTelemetry.Properties["Endpoint"] = endpoint;
        eventTelemetry.Properties["Environment"] = environment ?? "ALL";
        eventTelemetry.Properties["ControlCategory"] = controlCategory ?? "none";
        eventTelemetry.Properties["CacheStatus"] = status;
        
        eventTelemetry.Metrics["Duration"] = duration;

        _telemetryClient.TrackEvent(eventTelemetry);

        _logger.LogInformation(
            "Cache event tracked: Event={EventName}, Endpoint={Endpoint}, Environment={Environment}, Duration={Duration}ms",
            eventName, endpoint, environment, duration);
    }
}
