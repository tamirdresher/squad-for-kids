using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FedRampDashboard.Api.Models;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Controllers;

[ApiController]
[Route("api/v1/environments")]
[Authorize]
public class EnvironmentsController : ControllerBase
{
    private readonly IEnvironmentsService _environmentsService;
    private readonly ILogger<EnvironmentsController> _logger;

    public EnvironmentsController(IEnvironmentsService environmentsService, ILogger<EnvironmentsController> logger)
    {
        _environmentsService = environmentsService;
        _logger = logger;
    }

    /// <summary>
    /// Get compliance summary for an environment
    /// </summary>
    [HttpGet("{environment}/summary")]
    [Authorize(Policy = "Dashboard.Read")]
    [ProducesResponseType(typeof(EnvironmentSummary), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetEnvironmentSummary(
        string environment,
        [FromQuery] string timeRange = "24h")
    {
        var validEnvironments = new[] { "DEV", "STG", "PROD" };
        if (!validEnvironments.Contains(environment.ToUpper()))
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_ENVIRONMENT",
                Message = $"Invalid environment: {environment}. Valid values: DEV, STG, PROD",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        var validTimeRanges = new[] { "24h", "7d", "30d", "90d" };
        if (!validTimeRanges.Contains(timeRange))
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_TIME_RANGE",
                Message = $"Invalid time range: {timeRange}. Valid values: 24h, 7d, 30d, 90d",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        try
        {
            var summary = await _environmentsService.GetEnvironmentSummaryAsync(environment.ToUpper(), timeRange);
            return Ok(summary);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving environment summary for {Environment}", environment);
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while retrieving environment summary",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }
}
