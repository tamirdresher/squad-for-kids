using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using FedRampDashboard.Api.Authorization;

namespace FedRampDashboard.Api.Middleware;

/// <summary>
/// Middleware for extracting and validating PoP (Proof-of-Possession) tokens.
/// 
/// PoP tokens replace standard Bearer tokens for enhanced security:
/// - Bound to the caller (MetaRP service principal key pair)
/// - Bound to the specific resource URL
/// - Cannot be replayed for different endpoints
/// </summary>
public class PopTokenValidationMiddleware
{
    private readonly RequestDelegate _next;
    private readonly PopTokenConfiguration _config;
    private readonly ILogger<PopTokenValidationMiddleware> _logger;

    public PopTokenValidationMiddleware(
        RequestDelegate next,
        IOptions<PopTokenConfiguration> config,
        ILogger<PopTokenValidationMiddleware> logger)
    {
        _next = next;
        _config = config.Value;
        _logger = logger;
    }

    public async Task InvokeAsync(
        HttpContext context,
        IPopTokenValidationService popTokenValidationService)
    {
        try
        {
            // Skip validation for health checks and swagger
            if (IsExemptEndpoint(context.Request.Path))
            {
                await _next(context);
                return;
            }

            // Extract token from Authorization header
            var authHeader = context.Request.Headers.Authorization.ToString();
            if (string.IsNullOrEmpty(authHeader))
            {
                if (_config.Required)
                {
                    _logger.LogWarning("Request missing Authorization header for {Path}", context.Request.Path);
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    await context.Response.WriteAsJsonAsync(new { error = "Missing Authorization header" });
                    return;
                }

                await _next(context);
                return;
            }

            var token = ExtractBearerToken(authHeader);
            if (string.IsNullOrEmpty(token))
            {
                if (_config.Required)
                {
                    _logger.LogWarning("Invalid Authorization header format for {Path}", context.Request.Path);
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    await context.Response.WriteAsJsonAsync(new { error = "Invalid Authorization header" });
                    return;
                }

                await _next(context);
                return;
            }

            // Check if this is a PoP token
            if (!popTokenValidationService.IsPopToken(token))
            {
                if (_config.Required)
                {
                    _logger.LogWarning("Received non-PoP token when PoP is required for {Path}", context.Request.Path);
                    context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                    await context.Response.WriteAsJsonAsync(new { error = "PoP token required" });
                    return;
                }

                await _next(context);
                return;
            }

            // Validate PoP token
            var requestUri = $"{context.Request.Scheme}://{context.Request.Host}{context.Request.PathBase}{context.Request.Path}";
            try
            {
                var validatedToken = await popTokenValidationService.ValidatePopTokenAsync(
                    token,
                    requestUri,
                    context.RequestAborted);

                context.Items["PopToken"] = validatedToken;
                context.Items["IsPopAuthenticated"] = true;

                _logger.LogDebug("PoP token validated for {Path}", context.Request.Path);
            }
            catch (SecurityTokenException ex)
            {
                _logger.LogWarning("PoP token validation failed: {Exception}", ex.Message);
                context.Response.StatusCode = StatusCodes.Status401Unauthorized;
                await context.Response.WriteAsJsonAsync(new { error = $"Token validation failed: {ex.Message}" });
                return;
            }

            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError("Unexpected error in PoP validation middleware: {Exception}", ex.Message);
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await context.Response.WriteAsJsonAsync(new { error = "Internal server error" });
        }
    }

    private string? ExtractBearerToken(string authHeader)
    {
        const string scheme = "Bearer ";
        if (authHeader.StartsWith(scheme, StringComparison.OrdinalIgnoreCase))
        {
            return authHeader.Substring(scheme.Length).Trim();
        }

        return null;
    }

    private bool IsExemptEndpoint(PathString path)
    {
        var pathStr = path.Value ?? "";
        var exemptPaths = new[]
        {
            "/health",
            "/healthz",
            "/.well-known",
            "/swagger",
            "/api-docs"
        };

        return exemptPaths.Any(exemptPath =>
            pathStr.StartsWith(exemptPath, StringComparison.OrdinalIgnoreCase));
    }
}

public static class PopTokenValidationMiddlewareExtensions
{
    public static IApplicationBuilder UsePopTokenValidation(this IApplicationBuilder app)
    {
        return app.UseMiddleware<PopTokenValidationMiddleware>();
    }
}
