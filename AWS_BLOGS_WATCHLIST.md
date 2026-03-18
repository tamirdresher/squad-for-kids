# AWS Blogs Watchlist

> Added to the tech-news scanner as part of [issue #931](https://github.com/tamirdresher_microsoft/tamresearch1/issues/931).
> The scanner (`scripts/tech-news-scanner.js`) now polls these feeds daily alongside HackerNews, Reddit, and other sources.

---

## Blogs Added

### 1. AWS Architecture Blog
- **Feed URL:** `https://aws.amazon.com/blogs/architecture/feed/`
- **Web URL:** https://aws.amazon.com/blogs/architecture/
- **Scanner score:** 80 (high-signal — *all* articles included, not just keyword-matched)
- **Why it matters:**
  Deep dives into real-world architecture patterns from AWS Solutions Architects and customers.
  Topics span multi-region resiliency, microservices, event-driven design, data architectures,
  cost optimisation, and the Well-Architected Framework.
  Directly relevant for designing squad infrastructure on AWS and spotting patterns we can borrow.

### 2. AWS News Blog
- **Feed URL:** `https://aws.amazon.com/blogs/aws/feed/`
- **Web URL:** https://aws.amazon.com/blogs/aws/
- **Scanner score:** 85 (highest weight — official service launches and announcements)
- **Why it matters:**
  The official announcements channel for every new AWS service, feature GA, and weekly roundup.
  Knowing what AWS ships first means the squad can evaluate whether a new managed service
  replaces custom work we've built (e.g. a new Lambda feature that removes boilerplate,
  a new Bedrock model family, a new S3 capability).

### 3. AWS Compute Blog
- **Feed URL:** `https://aws.amazon.com/blogs/compute/feed/`
- **Web URL:** https://aws.amazon.com/blogs/compute/
- **Scanner score:** 75
- **Why it matters:**
  Covers Lambda, EC2, Fargate, Batch, App Runner, and serverless patterns end-to-end.
  Key for our serverless workloads — optimisation tricks, new runtime support (e.g. Rust, WASM),
  durable functions, and Graviton performance articles translate directly to cost and latency wins.

### 4. AWS Developer Tools Blog
- **Feed URL:** `https://aws.amazon.com/blogs/developer/feed/`
- **Web URL:** https://aws.amazon.com/blogs/developer/
- **Scanner score:** 70
- **Why it matters:**
  Covers SDK updates, CodePipeline/CodeBuild/CodeDeploy changes, CDK patterns, and developer
  productivity tooling. Any change in the AWS SDK (.NET, Go, JS) affects our integration code,
  and CDK updates feed directly into our infrastructure-as-code approach.

### 5. AWS Containers Blog
- **Feed URL:** `https://aws.amazon.com/blogs/containers/feed/`
- **Web URL:** https://aws.amazon.com/blogs/containers/
- **Scanner score:** 75
- **Why it matters:**
  EKS, ECS, Fargate, and ECR best practices. Kubernetes on AWS diverges from upstream in important
  ways (node groups, Pod Identity, VPC CNI). This blog surfaces those differences early.
  Also covers container security hardening, Graviton node pools, and GPU workloads — relevant
  for AI/ML containerised inference.

---

## Keywords Added to Scanner

The following keywords were added to `KEYWORDS` in `tech-news-scanner.js` so that AWS stories
appearing on HackerNews or Reddit are also captured:

```
aws, amazon web services, lambda, serverless, ec2, s3, dynamodb,
cloudformation, cdk, eks, ecs, fargate, bedrock, sagemaker,
step functions, eventbridge, api gateway, cognito, iam,
well-architected, multi-region, elasticache, rds, aurora,
graviton, outposts, wavelength, cloudfront, route 53
```

---

## Recent Articles Worth Reading (as of scan date)

### Architecture Patterns
- **[The Hidden Price Tag: Uncovering Hidden Costs with the AWS Well-Architected Framework](https://aws.amazon.com/blogs/architecture/the-hidden-price-tag-uncovering-hidden-costs-in-cloud-architectures-with-the-aws-well-architected-framework/)**  
  Cost visibility patterns using Cost Explorer + Well-Architected cost pillar reviews. Directly applicable to any team managing multi-service AWS deployments.

- **[Digital Transformation at Santander: Platform Engineering Revolutionising Cloud Infrastructure](https://aws.amazon.com/blogs/architecture/digital-transformation-at-santander-how-platform-engineering-is-revolutionizing-cloud-infrastructure/)**  
  Platform engineering at enterprise scale — internal developer platforms, golden paths, and self-service infrastructure.

- **[6,000 AWS accounts, three people, one platform: Lessons learned](https://aws.amazon.com/blogs/architecture/6000-aws-accounts-three-people-one-platform-lessons-learned/)**  
  Control Tower + Organizations at extreme scale. A rare "what we actually did" post from a real operations team.

- **[Fine-grained API authorization with Amazon Verified Permissions](https://aws.amazon.com/blogs/architecture/how-convera-built-fine-grained-api-authorization-with-amazon-verified-permissions/)**  
  Cedar policy language for attribute-based access control in APIs — a modern alternative to bespoke AuthZ layers.

### Compute & Serverless
- **[Optimizing Compute-Intensive Serverless Workloads with Multi-threaded Rust on AWS Lambda](https://aws.amazon.com/blogs/compute/optimizing-compute-intensive-serverless-workloads-with-multi-threaded-rust-on-aws-lambda/)**  
  Rust + Lambda for CPU-bound work with cold-start budgets. Relevant for any performance-critical background functions.

- **[Building fault-tolerant long-running applications with AWS Lambda durable functions](https://aws.amazon.com/blogs/compute/building-fault-tolerant-long-running-application-with-aws-lambda-durable-functions/)**  
  New durable-function pattern for Lambda (inspired by Azure Durable Functions). Replaces many Step Functions use cases.

### AWS Announcements
- **[Twenty years of Amazon S3 and building what's next](https://aws.amazon.com/blogs/aws/twenty-years-of-amazon-s3-and-building-whats-next/)**  
  S3's 20-year retrospective and roadmap. Worth reading for durability design lessons.

- **[Introducing account regional namespaces for Amazon S3 general purpose buckets](https://aws.amazon.com/blogs/aws/introducing-account-regional-namespaces-for-amazon-s3-general-purpose-buckets/)**  
  New S3 bucket-naming feature for multi-region and multi-account setups.

- **[Amazon Route 53 Global Resolver general availability](https://aws.amazon.com/blogs/aws/aws-weekly-roundup-amazon-s3-turns-20-amazon-route-53-global-resolver-general-availability-and-more-march-16-2026/)**  
  Global DNS resolver for cross-account / cross-region private hosted zones — simplifies VPC peering DNS.

---

## How the Scanner Uses These Sources

1. **All five AWS blogs are polled in parallel** with every other source (HN, Reddit, etc.)
2. **AWS Architecture Blog and AWS News Blog** include all recent articles (high-signal sources) regardless of keyword match
3. **AWS Compute, Developer Tools, and Containers blogs** apply the standard keyword filter to reduce noise
4. Articles appear in the daily **Tech News Digest** issue and Teams notification with source labelled `cloud/aws`
5. AWS-specific stories on HackerNews/Reddit are now also captured by the expanded keyword list

---

## Maintenance Notes

- If an AWS blog changes its feed URL, update `AWS_BLOGS` array in `scripts/tech-news-scanner.js`
- To add more AWS blogs (e.g. AWS Security, AWS Networking), add an entry to `AWS_BLOGS` — no other code changes needed
- Score tuning: increase score for a blog to promote it higher in the digest; decrease to reduce visibility
