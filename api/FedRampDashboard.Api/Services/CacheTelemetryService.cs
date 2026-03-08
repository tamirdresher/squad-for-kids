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

    public void TrackCacheHit(string endpoint, string method, string environment, string? controlCategory, double duration, string responseAge)
    {
        TrackCacheEvent("CacheHit", endpoint, method, environment, controlCategory, duration, "HIT", responseAge);
    }

    public void TrackCacheMiss(string endpoint, string method, string environment, string? controlCategory, double duration)
    {
        TrackCacheEvent("CacheMiss", endpoint, method, environment, controlCategory, duration, "MISS", "0");
    }

    private void TrackCacheEvent(
        string eventName, 
        string endpoint,
        string method,
        string environment, 
        string? controlCategory, 
        double duration, 
        string status,
        string responseAge)
    {
        var eventTelemetry = new EventTelemetry(eventName)
        {
            Timestamp = DateTimeOffset.UtcNow
        };

        eventTelemetry.Properties["Endpoint"] = endpoint;
        eventTelemetry.Properties["Method"] = method;
        eventTelemetry.Properties["Environment"] = environment ?? "ALL";
        eventTelemetry.Properties["ControlCategory"] = controlCategory ?? "none";
        eventTelemetry.Properties["CacheStatus"] = status;
        eventTelemetry.Properties["ResponseAge"] = responseAge;
        
        eventTelemetry.Metrics["Duration"] = duration;

        _telemetryClient.TrackEvent(eventTelemetry);

        _logger.LogInformation(
            "Cache event tracked: Event={EventName}, Endpoint={Endpoint}, Environment={Environment}, Duration={Duration}ms, Status={Status}",
            eventName, endpoint, environment, duration, status);
    }
}
