using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Middleware;

public class CacheTelemetryMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ICacheTelemetryService _cacheTelemetry;

    public CacheTelemetryMiddleware(
        RequestDelegate next, 
        ICacheTelemetryService cacheTelemetry)
    {
        _next = next;
        _cacheTelemetry = cacheTelemetry;
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
            ageHeader = "0";
        }

        var endpoint = context.Request.Path.Value ?? string.Empty;
        var method = context.Request.Method;
        var environment = context.Request.Query["environment"].ToString() ?? "ALL";
        var controlCategory = context.Request.Query["controlCategory"].ToString();

        // Delegate to service for consistent telemetry tracking
        if (isCacheHit)
        {
            _cacheTelemetry.TrackCacheHit(endpoint, method, environment, controlCategory, duration, ageHeader);
        }
        else
        {
            _cacheTelemetry.TrackCacheMiss(endpoint, method, environment, controlCategory, duration);
        }
    }
}

public static class CacheTelemetryMiddlewareExtensions
{
    public static IApplicationBuilder UseCacheTelemetry(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<CacheTelemetryMiddleware>();
    }
}
