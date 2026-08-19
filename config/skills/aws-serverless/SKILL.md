---
name: aws-serverless
description: Production-grade serverless architecture on AWS. Covers Lambda handlers (Node.js & Python), API Gateway / HTTP API integrations, DynamoDB single-table design, SQS event-driven partial batch failures, and cold start optimizations. Use when building serverless APIs, event-driven pipelines, or background workers on AWS.
---

# AWS Serverless Engineering Guide

Production-ready patterns, configurations, and best practices for building scalable, cost-effective serverless architectures on AWS.

---

## 1. Lambda Handler Patterns

### 1.1 Node.js 20+ Lambda Handler
```javascript
// src/handlers/itemHandler.js
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, GetCommand, PutCommand } = require('@aws-sdk/lib-dynamodb');

// Initialize outside handler to reuse connections across warm invocations
const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);

exports.handler = async (event, context) => {
  // Prevent Lambda from waiting for idle event loop connections
  context.callbackWaitsForEmptyEventLoop = false;

  try {
    const httpMethod = event.requestContext?.http?.method || event.httpMethod;
    
    if (httpMethod === 'GET') {
      const id = event.pathParameters?.id;
      if (!id) {
        return { statusCode: 400, body: JSON.stringify({ error: 'Missing id parameter' }) };
      }

      const res = await docClient.send(new GetCommand({
        TableName: process.env.TABLE_NAME,
        Key: { id }
      }));

      if (!res.Item) {
        return { statusCode: 404, body: JSON.stringify({ error: 'Item not found' }) };
      }

      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(res.Item)
      };
    }

    return { statusCode: 405, body: JSON.stringify({ error: 'Method Not Allowed' }) };
  } catch (error) {
    console.error('Lambda Execution Error:', error);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ error: 'Internal Server Error', requestId: context.awsRequestId })
    };
  }
};
```

### 1.2 Python 3.12+ Lambda Handler
```python
# src/handlers/item_handler.py
import json
import os
import logging
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Global initialization for warm reuse
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def handler(event, context):
    try:
        http_method = event.get('requestContext', {}).get('http', {}).get('method', event.get('httpMethod'))
        
        if http_method == 'GET':
            item_id = event.get('pathParameters', {}).get('id')
            if not item_id:
                return {'statusCode': 400, 'body': json.dumps({'error': 'Missing id parameter'})}

            response = table.get_item(Key={'id': item_id})
            item = response.get('Item')
            
            if not item:
                return {'statusCode': 404, 'body': json.dumps({'error': 'Item not found'})}

            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps(item)
            }

        return {'statusCode': 405, 'body': json.dumps({'error': 'Method Not Allowed'})}
    except Exception as e:
        logger.error(f"Error handling request: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal Server Error', 'requestId': context.aws_request_id})
        }
```

---

## 2. Event-Driven SQS Batch Processing with Partial Failures

```javascript
// src/handlers/sqsProcessor.js
exports.handler = async (event) => {
  const batchItemFailures = [];

  for (const record of event.Records) {
    try {
      const messageBody = JSON.parse(record.body);
      await processSingleMessage(messageBody);
    } catch (error) {
      console.error(`Failed to process message ${record.messageId}:`, error);
      // Report exact failed message ID so SQS retries ONLY this item
      batchItemFailures.push({
        itemIdentifier: record.messageId
      });
    }
  }

  return { batchItemFailures };
};

async function processSingleMessage(msg) {
  // Business logic for processing SQS payload
  console.log('Processed record:', msg.id);
}
```

---

## 3. Infrastructure as Code (AWS SAM Template)

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Globals:
  Function:
    Runtime: nodejs20.x
    Timeout: 15
    MemorySize: 512
    Architectures:
      - arm64
    Environment:
      Variables:
        TABLE_NAME: !Ref ItemsTable

Resources:
  HttpApi:
    Type: AWS::Serverless::HttpApi
    Properties:
      StageName: prod
      CorsConfiguration:
        AllowOrigins:
          - "*"
        AllowMethods:
          - GET
          - POST

  GetItemFunction:
    Type: AWS::Serverless::Function
    Properties:
      Handler: src/handlers/itemHandler.handler
      Events:
        GetItem:
          Type: HttpApi
          Properties:
            ApiId: !Ref HttpApi
            Path: /items/{id}
            Method: GET
      Policies:
        - DynamoDBReadPolicy:
            TableName: !Ref ItemsTable

  ProcessingQueue:
    Type: AWS::SQS::Queue
    Properties:
      VisibilityTimeout: 90 # 6x Lambda timeout
      RedrivePolicy:
        deadLetterTargetArn: !GetAtt DeadLetterQueue.Arn
        maxReceiveCount: 3

  DeadLetterQueue:
    Type: AWS::SQS::Queue
    Properties:
      MessageRetentionPeriod: 1209600 # 14 days

  ItemsTable:
    Type: AWS::DynamoDB::Table
    Properties:
      BillingMode: PAY_PER_REQUEST
      AttributeDefinitions:
        - AttributeName: id
          AttributeType: S
      KeySchema:
        - AttributeName: id
          KeyType: HASH
```

---

## 4. ⚠️ Production Sharp Edges & Solutions

| Vulnerability / Anti-Pattern | Severity | Root Cause | Engineering Solution |
| :--- | :--- | :--- | :--- |
| **All-or-Nothing SQS Retries** | 🔴 Critical | Throwing exception in SQS handler retries entire batch | Enable `ReportBatchItemFailures` and return `{ batchItemFailures: [...] }`. |
| **SQS Lambda Timeout Race** | 🔴 Critical | Queue Visibility Timeout <= Lambda timeout | Always set `VisibilityTimeout >= 6 * Lambda Timeout`. |
| **Connection Storms on RDBMS** | 🔴 Critical | Hundreds of concurrent Lambdas exhaust DB connection pool | Use **Amazon RDS Proxy** to manage and pool connections. |
| **Monolithic Lambda Packages** | 🟡 High | Bundling unused SDK modules causes slow cold starts | Bundle with `esbuild`, use ARM64 architecture, and keep package < 15MB. |
| **Unbounded Event Loop Waits** | 🟡 Medium | Open database pools prevent handler completion | Set `context.callbackWaitsForEmptyEventLoop = false` in Node.js. |
