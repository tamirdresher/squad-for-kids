using FedRampDashboard.Api.Models;

namespace FedRampDashboard.Api.Services;

public interface IEnvironmentsService
{
    Task<EnvironmentSummary> GetEnvironmentSummaryAsync(string environment, string timeRange);
}

public class EnvironmentsService : IEnvironmentsService
{
    private readonly ILogAnalyticsService _logAnalyticsService;

    public EnvironmentsService(ILogAnalyticsService logAnalyticsService)
    {
        _logAnalyticsService = logAnalyticsService;
    }

    public async Task<EnvironmentSummary> GetEnvironmentSummaryAsync(string environment, string timeRange)
    {
        var timeRangeKql = timeRange switch
        {
            "7d" => "ago(7d)",
            "30d" => "ago(30d)",
            "90d" => "ago(90d)",
            _ => "ago(24h)"
        };

        var kqlQuery = $@"
            ControlValidationResults_CL
            | where TimeGenerated > {timeRangeKql}
            | where Environment_s == '{environment}'
            | summarize 
                pass_count = countif(Status_s == 'PASS'),
                fail_count = countif(Status_s == 'FAIL'),
                last_test_time = max(TimeGenerated)
              by ControlId_s, ControlName_s
            | extend status = iff(fail_count > 0, 'FAIL', 'PASS')
        ";

        // TODO: Execute actual KQL query
        return new EnvironmentSummary
        {
            Environment = environment,
            Timestamp = DateTime.UtcNow,
            TimeRange = timeRange,
            ComplianceRate = 95.0,
            TotalControls = 20,
            PassingControls = 19,
            FailingControls = 1,
            ControlBreakdown = new(),
            RecentFailures = new()
        };
    }
}
