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
    [ResponseCache(Duration = 60, VaryByQueryKeys = new[] { "environment", "controlCategory" })]
    [ProducesResponseType(typeof(ComplianceStatus), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetComplianceStatus(
        [FromQuery] string? environment = "ALL",
        [FromQuery] string? controlCategory = null)
    {
        using var scope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["Environment"] = environment ?? "ALL",
            ["ControlCategory"] = controlCategory ?? "none",
            ["Endpoint"] = "GetComplianceStatus"
        });
        
        var startTime = DateTime.UtcNow;
        
        try
        {
            _logger.LogInformation(
                "Retrieving compliance status: Environment={Environment}, ControlCategory={ControlCategory}",
                environment, controlCategory);
            
            var status = await _complianceService.GetComplianceStatusAsync(environment, controlCategory);
            
            var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            _logger.LogInformation(
                "Compliance status retrieved successfully: OverallRate={OverallRate}%, Duration={Duration}ms",
                status.OverallComplianceRate, duration);
            
            return Ok(status);
        }
        catch (Exception ex)
        {
            var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            _logger.LogError(ex, 
                "Error retrieving compliance status: Environment={Environment}, Duration={Duration}ms", 
                environment, duration);
            
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
    [ResponseCache(Duration = 300, VaryByQueryKeys = new[] { "environment", "startDate", "endDate", "granularity" })]
    [ProducesResponseType(typeof(ComplianceTrend), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetComplianceTrend(
        [FromQuery] string environment,
        [FromQuery] DateTime startDate,
        [FromQuery] DateTime endDate,
        [FromQuery] string granularity = "daily")
    {
        using var scope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["Environment"] = environment,
            ["StartDate"] = startDate,
            ["EndDate"] = endDate,
            ["Granularity"] = granularity,
            ["Endpoint"] = "GetComplianceTrend"
        });
        
        var startExecution = DateTime.UtcNow;
        
        if (string.IsNullOrEmpty(environment))
        {
            _logger.LogWarning("Invalid request: Environment parameter missing");
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
            _logger.LogWarning(
                "Invalid date range: StartDate={StartDate}, EndDate={EndDate}", 
                startDate, endDate);
            
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
            _logger.LogInformation(
                "Retrieving compliance trend: Environment={Environment}, DateRange={StartDate} to {EndDate}, Granularity={Granularity}",
                environment, startDate, endDate, granularity);
            
            var trend = await _complianceService.GetComplianceTrendAsync(environment, startDate, endDate, granularity);
            
            var duration = (DateTime.UtcNow - startExecution).TotalMilliseconds;
            _logger.LogInformation(
                "Compliance trend retrieved: DataPoints={DataPoints}, Duration={Duration}ms",
                trend.DataPoints.Count, duration);
            
            return Ok(trend);
        }
        catch (Exception ex)
        {
            var duration = (DateTime.UtcNow - startExecution).TotalMilliseconds;
            _logger.LogError(ex, 
                "Error retrieving compliance trend: Environment={Environment}, Duration={Duration}ms", 
                environment, duration);
            
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
