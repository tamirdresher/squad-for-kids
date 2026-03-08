namespace FedRampDashboard.Api.Services;

public interface ICacheTelemetryService
{
    void TrackCacheHit(string endpoint, string environment, string? controlCategory, double duration);
    void TrackCacheMiss(string endpoint, string environment, string? controlCategory, double duration);
}
