using Microsoft.Azure.Cosmos;

namespace FedRampDashboard.Api.Services;

public interface ICosmosDbService
{
    Task<IEnumerable<T>> QueryAsync<T>(string query, string partitionKey);
    Task<T?> GetItemAsync<T>(string id, string partitionKey);
}

public class CosmosDbService : ICosmosDbService
{
    private readonly Container _container;

    public CosmosDbService(CosmosClient cosmosClient, IConfiguration configuration)
    {
        var databaseName = configuration["CosmosDb:DatabaseName"] ?? "SecurityDashboard";
        var containerName = configuration["CosmosDb:ContainerName"] ?? "ControlValidationResults";
        _container = cosmosClient.GetContainer(databaseName, containerName);
    }

    public async Task<IEnumerable<T>> QueryAsync<T>(string query, string partitionKey)
    {
        var queryDefinition = new QueryDefinition(query);
        var queryOptions = new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(partitionKey)
        };

        var iterator = _container.GetItemQueryIterator<T>(queryDefinition, requestOptions: queryOptions);
        var results = new List<T>();

        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync();
            results.AddRange(response);
        }

        return results;
    }

    public async Task<T?> GetItemAsync<T>(string id, string partitionKey)
    {
        try
        {
            var response = await _container.ReadItemAsync<T>(id, new PartitionKey(partitionKey));
            return response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return default;
        }
    }
}
