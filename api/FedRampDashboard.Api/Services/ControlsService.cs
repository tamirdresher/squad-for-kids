using FedRampDashboard.Api.Models;

namespace FedRampDashboard.Api.Services;

public interface IControlsService
{
    Task<ControlValidationResultList> GetControlValidationResultsAsync(
        string controlId, 
        string? environment, 
        string? status, 
        DateTime? startDate, 
        DateTime? endDate, 
        int limit, 
        int offset);
}

public class ControlsService : IControlsService
{
    private readonly ICosmosDbService _cosmosDbService;

    public ControlsService(ICosmosDbService cosmosDbService)
    {
        _cosmosDbService = cosmosDbService;
    }

    public async Task<ControlValidationResultList> GetControlValidationResultsAsync(
        string controlId, 
        string? environment, 
        string? status, 
        DateTime? startDate, 
        DateTime? endDate, 
        int limit, 
        int offset)
    {
        var parameters = new Dictionary<string, object>
        {
            ["control_id"] = controlId,
            ["limit_val"] = limit,
            ["offset_val"] = offset
        };
        
        var filters = new List<string> { "c.control.id = @control_id" };
        
        if (!string.IsNullOrEmpty(environment) && environment != "ALL")
        {
            filters.Add("c.environment = @environment_param");
            parameters["environment_param"] = environment;
        }
        
        if (!string.IsNullOrEmpty(status) && status != "ALL")
        {
            filters.Add("c.test.status = @status_param");
            parameters["status_param"] = status;
        }
        
        if (startDate.HasValue)
        {
            filters.Add("c.timestamp >= @start_date");
            parameters["start_date"] = startDate.Value;
        }
        
        if (endDate.HasValue)
        {
            filters.Add("c.timestamp <= @end_date");
            parameters["end_date"] = endDate.Value;
        }

        var whereClause = string.Join(" AND ", filters);
        var query = $@"
            SELECT * FROM c 
            WHERE {whereClause}
            ORDER BY c.timestamp DESC
            OFFSET @offset_val LIMIT @limit_val
        ";

        // TODO: Execute parameterized Cosmos DB query
        // await _cosmosDbService.QueryAsync<T>(query, parameters);
        
        return new ControlValidationResultList
        {
            ControlId = controlId,
            ControlName = "Sample Control",
            TotalResults = 0,
            Results = new(),
            Pagination = new Pagination
            {
                Total = 0,
                Limit = limit,
                Offset = offset,
                HasMore = false
            }
        };
    }
}
