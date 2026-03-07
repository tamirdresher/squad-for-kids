using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using FedRampDashboard.Api.Models;
using FedRampDashboard.Api.Services;

namespace FedRampDashboard.Api.Controllers;

[ApiController]
[Route("api/v1/reports")]
[Authorize]
public class ReportsController : ControllerBase
{
    private readonly IReportsService _reportsService;
    private readonly ILogger<ReportsController> _logger;

    public ReportsController(IReportsService reportsService, ILogger<ReportsController> logger)
    {
        _reportsService = reportsService;
        _logger = logger;
    }

    /// <summary>
    /// Export compliance report
    /// </summary>
    [HttpGet("compliance-export")]
    [Authorize(Policy = "Reports.Export")]
    [ProducesResponseType(typeof(ComplianceReport), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status200OK, Type = typeof(string))]
    [ProducesResponseType(typeof(ApiError), StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ExportComplianceReport(
        [FromQuery] string format = "json",
        [FromQuery] string? environment = "ALL",
        [FromQuery] DateTime? startDate = null,
        [FromQuery] DateTime? endDate = null,
        [FromQuery] bool includeDetails = false)
    {
        if (!startDate.HasValue || !endDate.HasValue)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "MISSING_DATE_RANGE",
                Message = "Start date and end date are required",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        if (endDate.Value <= startDate.Value)
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_DATE_RANGE",
                Message = "End date must be after start date",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        var validFormats = new[] { "json", "csv" };
        if (!validFormats.Contains(format.ToLower()))
        {
            return BadRequest(new ApiError
            {
                ErrorCode = "INVALID_FORMAT",
                Message = $"Invalid format: {format}. Valid values: json, csv",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }

        try
        {
            var report = await _reportsService.ExportComplianceReportAsync(
                format.ToLower(), environment, startDate.Value, endDate.Value, includeDetails);

            if (format.ToLower() == "csv")
            {
                var csv = ConvertReportToCsv(report);
                return File(System.Text.Encoding.UTF8.GetBytes(csv), "text/csv", 
                    $"compliance-report-{DateTime.UtcNow:yyyyMMdd}.csv");
            }

            return Ok(report);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error exporting compliance report");
            return StatusCode(500, new ApiError
            {
                ErrorCode = "INTERNAL_ERROR",
                Message = "An error occurred while exporting compliance report",
                Timestamp = DateTime.UtcNow,
                TraceId = HttpContext.TraceIdentifier
            });
        }
    }

    private static string ConvertReportToCsv(ComplianceReport report)
    {
        var csv = new System.Text.StringBuilder();
        csv.AppendLine("Control ID,Control Name,Pass Count,Fail Count,Compliance Rate");
        
        foreach (var control in report.ControlResults)
        {
            csv.AppendLine($"{control.ControlId},{control.ControlName},{control.PassCount},{control.FailCount},{control.ComplianceRate:F2}");
        }
        
        return csv.ToString();
    }
}
