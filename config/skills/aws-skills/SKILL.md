---
name: aws-skills
description: Master AWS cloud infrastructure, IaC automation with AWS CDK v2 and Terraform, architecture patterns, IAM security, containerization, and cost optimization. Use when architecting AWS solutions, writing CDK stacks, configuring VPC/IAM/ECS, or establishing cloud operational excellence.
---

# AWS Cloud Infrastructure & Architecture Engineering

Comprehensive, production-grade guide for developing, automating, and maintaining cloud infrastructure on Amazon Web Services (AWS) using modern Infrastructure as Code (IaC), Well-Architected principles, and enterprise security standards.

---

## Core Cloud Directives & Security Boundaries

- **Never Hardcode Credentials:** Use AWS IAM Roles, OIDC identity federation for GitHub Actions / CI pipelines, or AWS Secrets Manager. Never commit access keys or static secret tokens.
- **Dynamic Resource Naming:** Let CloudFormation / CDK generate unique physical resource names automatically. Hardcoding names (e.g. `functionName: 'my-fn'`) prevents parallel branch deployments, creates drift, and breaks multi-environment isolation.
- **Account-Level Environment Isolation:** Separate `dev`, `staging`, and `prod` across distinct AWS Accounts within AWS Organizations, rather than relying on naming prefixes inside a single account.
- **Least-Privilege IAM:** Scope IAM permissions tightly to exact resources and actions using ARNs, condition keys (`aws:PrincipalOrgID`, `aws:SecureTransport`), and permission boundaries.

---

## 1. AWS CDK v2 Infrastructure Patterns (TypeScript)

### 1.1 App Structure & Modular Stack Composition
```typescript
// bin/app.ts
import * as cdk from 'aws-cdk-lib';
import { NetworkStack } from '../lib/network-stack';
import { ComputeStack } from '../lib/compute-stack';

const app = new cdk.App();

const env: cdk.Environment = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION || 'us-east-1',
};

// 1. Foundation Network Layer
const networkStack = new NetworkStack(app, 'AppNetworkStack', {
  env,
  description: 'VPC, subnets, and VPC endpoints',
});

// 2. Compute Layer with dependency injection
const computeStack = new ComputeStack(app, 'AppComputeStack', {
  env,
  vpc: networkStack.vpc,
  description: 'ECS Fargate services and load balancing',
});
computeStack.addDependency(networkStack);

app.synth();
```

### 1.2 Production VPC with PrivateLink & VPC Endpoints
```typescript
// lib/network-stack.ts
import * as cdk from 'aws-cdk-lib';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import { Construct } from 'constructs';

export class NetworkStack extends cdk.Stack {
  public readonly vpc: ec2.IVpc;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    this.vpc = new ec2.Vpc(this, 'CoreVpc', {
      maxAzs: 2,
      natGateways: 1, // Single NAT Gateway for cost-efficiency in non-prod; 2 for prod HA
      subnetConfiguration: [
        {
          name: 'Public',
          subnetType: ec2.SubnetType.PUBLIC,
          cidrMask: 24,
        },
        {
          name: 'PrivateWithEgress',
          subnetType: ec2.SubnetType.PRIVATE_WITH_NAT,
          cidrMask: 24,
        },
        {
          name: 'IsolatedData',
          subnetType: ec2.SubnetType.PRIVATE_ISOLATED,
          cidrMask: 24,
        },
      ],
    });

    // Gateway Endpoints (Free of charge) for S3 and DynamoDB
    this.vpc.addGatewayEndpoint('S3Endpoint', {
      service: ec2.GatewayVpcEndpointAwsService.S3,
    });
    this.vpc.addGatewayEndpoint('DynamoDbEndpoint', {
      service: ec2.GatewayVpcEndpointAwsService.DYNAMODB,
    });
  }
}
```

### 1.3 Node.js & Python Optimized Lambda Bundling
```typescript
import * as lambdaNode from 'aws-cdk-lib/aws-lambda-nodejs';
import * as lambda from 'aws-cdk-lib/aws-lambda';
import * as logs from 'aws-cdk-lib/aws-logs';

// Node.js Lambda bundled automatically with esbuild
const apiHandler = new lambdaNode.NodejsFunction(this, 'ApiHandler', {
  runtime: lambda.Runtime.NODEJS_20_X,
  entry: 'src/handlers/api.ts',
  handler: 'handler',
  architecture: lambda.Architecture.ARM_64, // Graviton2: 20% cheaper, better performance
  memorySize: 1024,
  timeout: cdk.Duration.seconds(15),
  logRetention: logs.RetentionDays.ONE_MONTH,
  bundling: {
    minify: true,
    sourceMap: true,
    target: 'node20',
  },
  environment: {
    NODE_OPTIONS: '--enable-source-maps',
  },
});
```

---

## 2. ECS Fargate Container Architecture

```typescript
import * as ecs from 'aws-cdk-lib/aws-ecs';
import * as ecsPatterns from 'aws-cdk-lib/aws-ecs-patterns';

const cluster = new ecs.Cluster(this, 'AppCluster', {
  vpc: props.vpc,
  containerInsights: true,
});

// Load-Balanced Fargate Service
const fargateService = new ecsPatterns.ApplicationLoadBalancedFargateService(this, 'WebService', {
  cluster,
  memoryLimitMiB: 2048,
  cpu: 1024,
  desiredCount: 2,
  runtimePlatform: {
    cpuArchitecture: ecs.CpuArchitecture.ARM64,
    operatingSystemFamily: ecs.OperatingSystemFamily.LINUX,
  },
  taskImageOptions: {
    image: ecs.ContainerImage.fromAsset('./app'),
    containerPort: 8080,
    enableLogging: true,
    environment: {
      ASPNETCORE_ENVIRONMENT: 'Production',
    },
  },
  publicLoadBalancer: true,
});

// Target Group Health Check tuning
fargateService.targetGroup.configureHealthCheck({
  path: '/health',
  healthyThresholdCount: 2,
  unhealthyThresholdCount: 3,
  interval: cdk.Duration.seconds(30),
});
```

---

## 3. IAM Least-Privilege & Security Matrix

### 3.1 Strict S3 Bucket Policy (Enforcing TLS 1.2+ & KMS Encryption)
```typescript
import * as s3 from 'aws-cdk-lib/aws-s3';
import * as iam from 'aws-cdk-lib/aws-iam';

const secureBucket = new s3.Bucket(this, 'SecureDataBucket', {
  encryption: s3.BucketEncryption.S3_MANAGED,
  blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
  enforceSSL: true, // Denies non-HTTPS requests
  versioned: true,
  lifecycleRules: [
    {
      transitions: [
        {
          storageClass: s3.StorageClass.INTELLIGENT_TIERING,
          transitionAfter: cdk.Duration.days(30),
        },
      ],
    },
  ],
});
```

### 3.2 GitHub Actions OIDC Authentication (No Static Keys)
```typescript
import * as iam from 'aws-cdk-lib/aws-iam';

const githubProvider = new iam.OpenIdConnectProvider(this, 'GitHubOIDC', {
  url: 'https://token.actions.githubusercontent.com',
  clientIds: ['sts.amazonaws.com'],
});

const deployRole = new iam.Role(this, 'GitHubDeployRole', {
  assumedBy: new iam.FederatedPrincipal(
    githubProvider.openIdConnectProviderArn,
    {
      StringEquals: {
        'token.actions.githubusercontent.com:aud': 'sts.amazonaws.com',
      },
      StringLike: {
        'token.actions.githubusercontent.com:sub': 'repo:my-org/my-repo:ref:refs/heads/main',
      },
    },
    'sts:AssumeRoleWithWebIdentity'
  ),
  description: 'Role assumed by GitHub Actions for automated CI/CD deployments',
});
```

---

## 4. Operational Excellence & Cost Optimization

| Strategy | Implementation | Business Impact |
| :--- | :--- | :--- |
| **Graviton (ARM64)** | Set `architecture: Architecture.ARM_64` on Lambda & ECS | Up to 20% cost reduction + lower latency |
| **S3 Intelligent-Tiering** | Add lifecycle rule transitioning objects >30 days | Automatically cuts storage costs on cold data by up to 68% |
| **VPC Gateway Endpoints** | Add free Gateway endpoints for S3 & DynamoDB | Bypasses NAT Gateway data processing fees |
| **Log Retention** | Explicitly configure `logRetention: RetentionDays.ONE_MONTH` | Prevents runaway CloudWatch storage charges |
| **Single NAT in Non-Prod** | Set `natGateways: 1` for Dev/Staging environments | Saves ~$32/month per unnecessary NAT Gateway |

---

## Verification & Deployment Commands

```bash
# Synthesize CloudFormation template and check for warnings
cdk synth

# Compare local CDK changes against live AWS stack
cdk diff

# Security audit with cdk-nag or Checkov
npx cdk-nag

# Deploy targeted stack with strict approval check
cdk deploy AppComputeStack --require-approval broadening
```
