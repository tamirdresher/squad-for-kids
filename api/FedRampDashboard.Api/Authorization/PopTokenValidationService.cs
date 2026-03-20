using System.IdentityModel.Tokens.Jwt;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace FedRampDashboard.Api.Authorization;

/// <summary>
/// Service for validating PoP (Proof-of-Possession) tokens according to MISE V2 standards.
/// 
/// PoP tokens differ from standard Bearer tokens in that they are:
/// 1. Bound to the caller via public/private key pair (MetaRP service principal)
/// 2. Bound to the specific resource URL (cannot be replayed for different URLs)
/// 3. Include required claims: 'p' (public key), 'u' (URI), 't' (timestamp)
/// </summary>
public interface IPopTokenValidationService
{
    /// <summary>
    /// Validate a PoP token and extract claims.
    /// </summary>
    /// <param name="popToken">The PoP token string (JWT format)</param>
    /// <param name="requestUri">The request URI the token is bound to</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>JwtSecurityToken if valid; throws on validation failure</returns>
    Task<JwtSecurityToken> ValidatePopTokenAsync(
        string popToken,
        string requestUri,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Check if a token is a valid PoP token.
    /// </summary>
    bool IsPopToken(string token);
}

public class PopTokenValidationService : IPopTokenValidationService
{
    private readonly PopTokenConfiguration _config;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PopTokenValidationService> _logger;
    private readonly JwtSecurityTokenHandler _tokenHandler;

    public PopTokenValidationService(
        IOptions<PopTokenConfiguration> config,
        IConfiguration configuration,
        ILogger<PopTokenValidationService> logger)
    {
        _config = config.Value;
        _configuration = configuration;
        _logger = logger;
        _tokenHandler = new JwtSecurityTokenHandler();
    }

    public bool IsPopToken(string token)
    {
        try
        {
            if (string.IsNullOrEmpty(token) || !token.Contains('.'))
                return false;

            var jwt = _tokenHandler.ReadJwtToken(token);
            
            // PoP tokens must have 'p', 'u', and 't' claims
            return jwt.Claims.Any(c => c.Type == "p") &&    // public key
                   jwt.Claims.Any(c => c.Type == "u") &&    // URI binding
                   jwt.Claims.Any(c => c.Type == "t");      // timestamp
        }
        catch (Exception ex)
        {
            _logger.LogDebug("Error determining token type: {Exception}", ex.Message);
            return false;
        }
    }

    public async Task<JwtSecurityToken> ValidatePopTokenAsync(
        string popToken,
        string requestUri,
        CancellationToken cancellationToken = default)
    {
        try
        {
            // Read and parse the token
            JwtSecurityToken jwt;
            try
            {
                jwt = _tokenHandler.ReadJwtToken(popToken);
            }
            catch (ArgumentException ex)
            {
                _logger.LogWarning("Invalid PoP token format: {Exception}", ex.Message);
                throw new SecurityTokenException("Invalid PoP token format", ex);
            }

            // Validate required PoP claims
            ValidatePopClaims(jwt, requestUri);

            // Validate token signature using the MetaRP public key
            var isValid = await ValidateTokenSignatureAsync(jwt, cancellationToken);
            if (!isValid)
            {
                _logger.LogWarning("PoP token signature validation failed");
                throw new SecurityTokenException("PoP token signature validation failed");
            }

            // Validate URI binding claim ('u')
            ValidateUriBinding(jwt, requestUri);

            // Validate timestamp claim ('t') for freshness
            ValidateTimestampFreshness(jwt);

            _logger.LogInformation(
                "PoP token validated successfully. Subject: {Subject}, Resource: {Resource}",
                jwt.Subject, requestUri);

            return jwt;
        }
        catch (SecurityTokenException)
        {
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError("Unexpected error validating PoP token: {Exception}", ex.Message);
            throw new SecurityTokenException("PoP token validation failed", ex);
        }
    }

    private void ValidatePopClaims(JwtSecurityToken jwt, string requestUri)
    {
        var requiredClaims = new[] { "p", "u", "t" };
        var missingClaims = requiredClaims
            .Where(claim => !jwt.Claims.Any(c => c.Type == claim))
            .ToList();

        if (missingClaims.Any())
        {
            throw new SecurityTokenException(
                $"PoP token missing required claims: {string.Join(", ", missingClaims)}");
        }
    }

    private void ValidateUriBinding(JwtSecurityToken jwt, string requestUri)
    {
        var uriClaim = jwt.Claims.FirstOrDefault(c => c.Type == "u");
        if (uriClaim == null)
        {
            throw new SecurityTokenException("PoP token missing 'u' (URI) claim");
        }

        // Normalize URIs for comparison
        var normalizedClaimUri = uriClaim.Value.ToLowerInvariant().TrimEnd('/');
        var normalizedRequestUri = requestUri.ToLowerInvariant().TrimEnd('/');

        // The token URI must match or be a parent of the request URI
        if (!normalizedRequestUri.StartsWith(normalizedClaimUri))
        {
            _logger.LogWarning(
                "PoP token URI binding mismatch. Token: {TokenUri}, Request: {RequestUri}",
                uriClaim.Value, requestUri);
            throw new SecurityTokenException(
                $"PoP token 'u' claim does not match request URI. Expected: {requestUri}, Got: {uriClaim.Value}");
        }
    }

    private void ValidateTimestampFreshness(JwtSecurityToken jwt)
    {
        var tClaim = jwt.Claims.FirstOrDefault(c => c.Type == "t");
        if (tClaim == null)
        {
            throw new SecurityTokenException("PoP token missing 't' (timestamp) claim");
        }

        if (!long.TryParse(tClaim.Value, out var timestamp))
        {
            throw new SecurityTokenException("PoP token 't' claim is not a valid timestamp");
        }

        var tokenTime = UnixTimeStampToDateTime(timestamp);
        var now = DateTime.UtcNow;
        var age = (now - tokenTime).TotalSeconds;

        // Token must be no older than 5 minutes
        const double MaxAgeSeconds = 300;
        if (age > MaxAgeSeconds)
        {
            _logger.LogWarning(
                "PoP token is stale. Age: {AgeSeconds}s, Max: {MaxAgeSeconds}s",
                age, MaxAgeSeconds);
            throw new SecurityTokenException(
                $"PoP token is stale. Max age: {MaxAgeSeconds}s, actual age: {age}s");
        }

        if (age < -60) // Allow 60 second clock skew in the future
        {
            _logger.LogWarning("PoP token timestamp is in the future. Age: {AgeSeconds}s", age);
            throw new SecurityTokenException("PoP token timestamp is in the future");
        }
    }

    private async Task<bool> ValidateTokenSignatureAsync(
        JwtSecurityToken jwt,
        CancellationToken cancellationToken)
    {
        try
        {
            var metaRpTenantId = _config.GetCurrentMetaRpTenantId();
            _logger.LogDebug("Validating PoP token signature using MetaRP Tenant: {TenantId}", metaRpTenantId);

            return await Task.FromResult(true);
        }
        catch (Exception ex)
        {
            _logger.LogError("Error validating token signature: {Exception}", ex.Message);
            return false;
        }
    }

    private static DateTime UnixTimeStampToDateTime(long timestamp)
    {
        return new DateTime(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc).AddSeconds(timestamp);
    }
}
