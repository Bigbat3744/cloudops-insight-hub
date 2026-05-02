# Architecture Documentation

## System Design

### Components

1. **EventBridge Scheduler**
   - Triggers Lambda daily at 9 AM UTC
   - Ensures consistent cost data collection
   - No manual intervention required

2. **Lambda Function (Cost Collector)**
   - Queries AWS Cost Explorer API
   - Processes and aggregates cost data
   - Stores results in DynamoDB
   - Handles errors gracefully

3. **API Gateway**
   - Exposes REST endpoint for external access
   - Handles query parameter validation
   - CORS-enabled for web dashboard

4. **DynamoDB Table**
   - Single-table design with pk/sk pattern
   - TTL-enabled for 90-day retention
   - On-demand billing (no capacity planning)

5. **Web Dashboard**
   - Static HTML/JS hosted on S3
   - Chart.js for data visualization
   - Responsive design for mobile

### Data Flow 
[EventBridge Cron] ──────▶ [Lambda] ──────▶ [Cost Explorer API]
│
├──────▶ [DynamoDB Write]
│
└──────▶ [CloudWatch Logs]
[User Browser] ──────▶ [API Gateway] ──────▶ [Lambda] ──────▶ [DynamoDB Read]
│
└──────▶ [JSON Response]  

### Security

- **IAM Least Privilege**: Lambda role has only required permissions
- **API Authentication**: Can add API keys (currently anonymous for demo)
- **DynamoDB Encryption**: At-rest encryption enabled
- **CloudWatch Logs**: All invocations logged for audit trail

### Scalability

- **Lambda**: Auto-scales to 1000 concurrent executions
- **API Gateway**: Handles 10,000 requests/second
- **DynamoDB**: On-demand mode scales automatically
- **Bottleneck**: Cost Explorer API (5 requests/second limit)

### Cost Optimization

- Serverless architecture = pay-per-use
- DynamoDB on-demand = no idle capacity costs
- TTL = automatic data cleanup (no storage bloat)
- Free tier covers 100% of expected usage             
