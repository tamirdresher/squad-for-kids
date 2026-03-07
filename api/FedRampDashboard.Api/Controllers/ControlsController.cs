using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FedRampDashboard.Api.Models;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Controllers;

[ApiController]
[Route("api/v1/controls")]
[Authorize]
public class ControlsController : ControllerBase
{
    private readonly IControlsService _controlsService;
    private readonly ILogger<ControlsController> _logger;

    public ControlsController(IControlsService controlsService, ILogger<ControlsController> logger)
    {
        _controlsService = controlsService;
        _logger = logger;
    }

    /// <summary>
    /// Get validation results for a specific control
    /// </summary>
    [HttpGet("{controlId}/validation-results")]
    [Authorize(Policy = "Controls.Read")]
    [ProducesResponseType(typeof(ControlValidationResultList), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetControlValidationResults(
        string controlId,
        [FromQuery] string? environment = "ALL",
        [FromQuery] string? status = "ALL",
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        [FromQuery] int limit = 100,
        [FromQuery] int offset = 0)
    {
        if (!IsValidControlId(controlId))
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_CONTROL_ID",
                Message = $"Invalid control ID format: {controlId}. Expected format: XX-N (e.g., SC-7, SI-2)",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        if (limit < 1 || limit > 1000)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_LIMIT",
                Message = "Limit must be between 1 and 1000",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        try
        {
            var results = await _controlsService.GetControlValidationResultsAsync(
                controlId, environment, status, startDate, endDate, limit, offset);
            
            if (results.TotalResults == 0)
            {
                return NotFound(new ApiError
                {
                    ErrorCode = "CONTROL_NOT_FOUND",
                    Message = $"No validation results found for control {controlId}",
                    Timestamp = DateTime.UtcNow,
                    TraceId = HttpContext.TraceIdentifier
                });
            }

            return Ok(results);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving control validation results for {ControlId}", controlId);
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while retrieving control validation results",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }

    private static bool IsValidControlId(string controlId)
    {
        return System.Text.RegularExpressions.Regex.IsMatch(controlId, @"^[A-Z]{2}-\d{1,2}$");
    }
}
