using FedRampDashboard.Api.Models;

namespace FedRampDashboard.Api.Services;

public interface IHistoryService
{
    Task<ControlDriftList> GetControlDriftAsync(string? environment, int currentPeriodDays, double driftThreshold);
}

public class HistoryService : IHistoryService
{
    private readonly ILogAnalyticsService _logAnalyticsService;

    public HistoryService(ILogAnalyticsService logAnalyticsService)
    {
        _logAnalyticsService = logAnalyticsService;
    }

    public async Task<ControlDriftList> GetControlDriftAsync(string? environment, int currentPeriodDays, double driftThreshold)
    {
        var envFilter = environment == "ALL" || string.IsNullOrEmpty(environment) 
            ? "" 
            : $"| where Environment_s == '{environment}'";

        var kqlQuery = $@"
            let current_period = ControlValidationResults_CL
            | where TimeGenerated between (ago({currentPeriodDays}d) .. now())
            {envFilter}
            | summarize 
                current_fail_rate = countif(Status_s == 'FAIL') * 1.0 / count() 
              by ControlId_s, ControlName_s, Environment_s;
            let prior_period = ControlValidationResults_CL
            | where TimeGenerated between (ago({currentPeriodDays * 2}d) .. ago({currentPeriodDays}d))
            {envFilter}
            | summarize 
                prior_fail_rate = countif(Status_s == 'FAIL') * 1.0 / count() 
              by ControlId_s, Environment_s;
            current_period
            | join kind=inner prior_period on ControlId_s, Environment_s
            | extend drift_pct = (current_fail_rate - prior_fail_rate) * 100
            | where drift_pct > {driftThreshold}
            | extend severity = case(
                drift_pct > 50, 'CRITICAL',
                drift_pct > 30, 'HIGH',
                drift_pct > 15, 'MEDIUM',
                'LOW'
            )
            | project ControlId_s, ControlName_s, Environment_s, current_fail_rate, prior_fail_rate, drift_pct, severity
            | order by drift_pct desc
        ";

        // TODO: Execute actual KQL query
        return new ControlDriftList
        {
            AnalysisTimestamp = DateTime.UtcNow,
            CurrentPeriodDays = currentPeriodDays,
            DriftThreshold = driftThreshold,
            DriftingControls = new()
        };
    }
}
