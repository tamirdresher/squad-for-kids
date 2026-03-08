namespace FedRampDashboard.Api.Services;

public interface ICacheTelemetryService
{
    void TrackCacheHit(string endpoint, string method, string environment, string? controlCategory, double duration, string responseAge);
    void TrackCacheMiss(string endpoint, string method, string environment, string? controlCategory, double duration);
}
