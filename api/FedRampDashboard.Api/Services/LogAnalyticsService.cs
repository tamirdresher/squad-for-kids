using Azure.Monitor.Query;
using Azure.Identity;

namespace FedRampDashboard.Api.Services;

public interface ILogAnalyticsService
{
    Task<IEnumerable<T>> QueryAsync<T>(string kqlQuery);
}

public class LogAnalyticsService : ILogAnalyticsService
{
    private readonly LogsQueryClient _logsClient;
    private readonly string _workspaceId;

    public LogAnalyticsService(IConfiguration configuration)
    {
        _workspaceId = configuration["LogAnalytics:WorkspaceId"] 
            ?? throw new InvalidOperationException("LogAnalytics:WorkspaceId not configured");
        _logsClient = new LogsQueryClient(new DefaultAzureCredential());
    }

    public async Task<IEnumerable<T>> QueryAsync<T>(string kqlQuery)
    {
        var response = await _logsClient.QueryWorkspaceAsync<T>(
            _workspaceId,
            kqlQuery,
            new QueryTimeRange(TimeSpan.FromDays(90)));

        return response.Value;
    }
}
