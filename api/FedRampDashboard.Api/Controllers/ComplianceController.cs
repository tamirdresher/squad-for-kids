using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FedRampDashboard.Api.Models;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Controllers;

[ApiController]
[Route("api/v1/compliance")]
[Authorize]
public class ComplianceController : ControllerBase
{
    private readonly IComplianceService _complianceService;
    private readonly ILogger<ComplianceController> _logger;

    public ComplianceController(IComplianceService complianceService, ILogger<ComplianceController> logger)
    {
        _complianceService = complianceService;
        _logger = logger;
    }

    /// <summary>
    /// Get real-time compliance status
    /// </summary>
    [HttpGet("status")]
    [Authorize(Policy = "Dashboard.Read")]
    [ProducesResponseType(typeof(ComplianceStatus), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetComplianceStatus(
        [FromQuery] string? environment = "ALL",
        [FromQuery] string? controlCategory = null)
    {
        try
        {
            var status = await _complianceService.GetComplianceStatusAsync(environment, controlCategory);
            return Ok(status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving compliance status");
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while retrieving compliance status",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }

    /// <summary>
    /// Get compliance trend over time
    /// </summary>
    [HttpGet("trend")]
    [Authorize(Policy = "Dashboard.Read")]
    [ProducesResponseType(typeof(ComplianceTrend), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetComplianceTrend(
        [FromQuery] string environment,
        [FromQuery] DateTime startDate,
        [FromQuery] DateTime endDate,
        [FromQuery] string granularity = "daily")
    {
        if (string.IsNullOrEmpty(environment))
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_PARAMETER",
                Message = "Environment parameter is required",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        if (endDate <= startDate)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_DATE_RANGE",
                Message = "End date must be after start date",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        try
        {
            var trend = await _complianceService.GetComplianceTrendAsync(environment, startDate, endDate, granularity);
            return Ok(trend);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving compliance trend");
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while retrieving compliance trend",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }
}
