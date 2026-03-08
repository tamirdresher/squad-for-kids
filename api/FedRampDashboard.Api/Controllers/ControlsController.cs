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
        using var scope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["ControlId"] = controlId,
            ["Environment"] = environment ?? "ALL",
            ["Status"] = status ?? "ALL",
            ["Limit"] = limit,
            ["Offset"] = offset,
            ["Endpoint"] = "GetControlValidationResults"
        });
        
        var startExecution = DateTime.UtcNow;
        
        if (!IsValidControlId(controlId))
        {
            _logger.LogWarning("Invalid control ID format: {ControlId}", controlId);
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
            _logger.LogWarning("Invalid limit value: {Limit}", limit);
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
            _logger.LogInformation(
                "Retrieving control validation results: ControlId={ControlId}, Environment={Environment}, Status={Status}, Limit={Limit}, Offset={Offset}",
                controlId, environment, status, limit, offset);
            
            var results = await _controlsService.GetControlValidationResultsAsync(
                controlId, environment, status, startDate, endDate, limit, offset);
            
            var duration = (DateTime.UtcNow - startExecution).TotalMilliseconds;
            
            if (results.TotalResults == 0)
            {
                _logger.LogInformation(
                    "No validation results found: ControlId={ControlId}, Duration={Duration}ms",
                    controlId, duration);
                
                return NotFound(new ApiError
                {
                    ErrorCode = "CONTROL_NOT_FOUND",
                    Message = $"No validation results found for control {controlId}",
                    Timestamp = DateTime.UtcNow,
                    TraceId = HttpContext.TraceIdentifier
                });
            }

            _logger.LogInformation(
                "Control validation results retrieved: ControlId={ControlId}, TotalResults={Total}, Returned={Returned}, Duration={Duration}ms",
                controlId, results.TotalResults, results.Results.Count, duration);

            return Ok(results);
        }
        catch (Exception ex)
        {
            var duration = (DateTime.UtcNow - startExecution).TotalMilliseconds;
            _logger.LogError(ex, 
                "Error retrieving control validation results: ControlId={ControlId}, Duration={Duration}ms", 
                controlId, duration);
            
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
