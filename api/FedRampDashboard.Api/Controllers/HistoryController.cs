using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FedRampDashboard.Api.Models;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Controllers;

[ApiController]
[Route("api/v1/history")]
[Authorize]
public class HistoryController : ControllerBase
{
    private readonly IHistoryService _historyService;
    private readonly ILogger<HistoryController> _logger;

    public HistoryController(IHistoryService historyService, ILogger<HistoryController> logger)
    {
        _historyService = historyService;
        _logger = logger;
    }

    /// <summary>
    /// Get control drift detection results
    /// </summary>
    [HttpGet("control-drift")]
    [Authorize(Policy = "Analytics.Read")]
    [ProducesResponseType(typeof(ControlDriftList), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> GetControlDrift(
        [FromQuery] string? environment = "ALL",
        [FromQuery] int currentPeriodDays = 7,
        [FromQuery] double driftThreshold = 10.0)
    {
        if (currentPeriodDays < 1 || currentPeriodDays > 30)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_PERIOD",
                Message = "Current period days must be between 1 and 30",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        if (driftThreshold < 0 || driftThreshold > 100)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_THRESHOLD",
                Message = "Drift threshold must be between 0 and 100",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        try
        {
            var drift = await _historyService.GetControlDriftAsync(environment, currentPeriodDays, driftThreshold);
            return Ok(drift);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving control drift");
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while retrieving control drift",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }
}
