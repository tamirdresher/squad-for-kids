var builder = DistributedApplication.CreateBuilder(args);

// Add a Kind cluster named "dev-cluster"
var cluster = builder.AddKindCluster("dev-cluster");

builder.Build().Run();
