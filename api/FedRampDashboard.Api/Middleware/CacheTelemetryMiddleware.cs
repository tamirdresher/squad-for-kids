using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;

namespace FedRampDashboard.Api.Middleware;

public class CacheTelemetryMiddleware
{
    private readonly RequestDelegate _next;
    private readonly TelemetryClient _telemetryClient;
    private readonly ILogger<CacheTelemetryMiddleware> _logger;

    public CacheTelemetryMiddleware(
        RequestDelegate next, 
        TelemetryClient telemetryClient, 
        ILogger<CacheTelemetryMiddleware> logger)
    {
        _next = next;
        _telemetryClient = telemetryClient;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        var originalBodyStream = context.Response.Body;
        
        using var responseBody = new MemoryStream();
        context.Response.Body = responseBody;
        
        var startTime = DateTime.UtcNow;
        await _next(context);
        var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
        
        // Track cache telemetry for compliance endpoints
        if (context.Request.Path.StartsWithSegments("/api/v1/compliance") && 
            context.Response.StatusCode == 200)
        {
            TrackCacheTelemetry(context, duration);
        }
        
        // Copy response back to original stream
        responseBody.Seek(0, SeekOrigin.Begin);
        await responseBody.CopyToAsync(originalBodyStream);
        context.Response.Body = originalBodyStream;
    }

    private void TrackCacheTelemetry(HttpContext context, double duration)
    {
        var ageHeader = context.Response.Headers["Age"].FirstOrDefault();
        var isCacheHit = !string.IsNullOrEmpty(ageHeader) && int.TryParse(ageHeader, out var age) && age > 0;
        
        // Add Age header if not already present (cache miss)
        if (string.IsNullOrEmpty(ageHeader))
        {
            context.Response.Headers["Age"] = "0";
            isCacheHit = false;
        }

        var eventTelemetry = new EventTelemetry(isCacheHit ? "CacheHit" : "CacheMiss")
        {
            Timestamp = DateTimeOffset.UtcNow
        };

        eventTelemetry.Properties["Endpoint"] = context.Request.Path.Value ?? string.Empty;
        eventTelemetry.Properties["Method"] = context.Request.Method;
        eventTelemetry.Properties["CacheStatus"] = isCacheHit ? "HIT" : "MISS";
        eventTelemetry.Properties["ResponseAge"] = ageHeader ?? "0";
        eventTelemetry.Properties["Environment"] = context.Request.Query["environment"].ToString() ?? "ALL";
        eventTelemetry.Properties["ControlCategory"] = context.Request.Query["controlCategory"].ToString() ?? "none";
        
        eventTelemetry.Metrics["Duration"] = duration;
        
        _telemetryClient.TrackEvent(eventTelemetry);

        _logger.LogInformation(
            "Cache telemetry tracked: Endpoint={Endpoint}, Status={Status}, Age={Age}s, Duration={Duration}ms",
            context.Request.Path.Value, 
            isCacheHit ? "HIT" : "MISS", 
            ageHeader, 
            duration);
    }
}

public static class CacheTelemetryMiddlewareExtensions
{
    public static IApplicationBuilder UseCacheTelemetry(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<CacheTelemetryMiddleware>();
    }
}
