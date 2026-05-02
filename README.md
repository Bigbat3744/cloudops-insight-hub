# ☁️ CloudOps Insight Hub

> **Serverless AWS cost monitoring and analysis platform**

[![AWS](https://img.shields.io/badge/AWS-Serverless-orange?logo=amazon-aws)](https://aws.amazon.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple?logo=terraform)](https://www.terraform.io)
[![Python](https://img.shields.io/badge/Python-3.10-blue?logo=python)](https://www.python.org)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 🎯 Project Overview

Automated AWS cost monitoring solution that collects, stores, and visualizes cloud spending across services. Built with serverless architecture for zero operational overhead and minimal cost (runs within AWS free tier).

**Live Demo:** [Dashboard Link](#) | **Video Demo:** [2-min walkthrough](#)

### Key Features

- ✅ **Automated Cost Collection** - Daily snapshots of AWS spending via EventBridge
- ✅ **Real-time API** - REST endpoint for cost data queries (7/30/90-day periods)
- ✅ **Historical Storage** - DynamoDB with 90-day TTL for cost trends
- ✅ **Interactive Dashboard** - Web-based visualization with Chart.js
- ✅ **Infrastructure as Code** - 100% Terraform-managed AWS resources
- ✅ **Production-Ready** - CloudWatch logging, error handling, IAM least-privilege

---

## 🏗️ Architecture

┌─────────────────┐         ┌──────────────────┐
│  EventBridge    │ ────────▶│  Lambda Function │
│  (Daily 9AM)    │         │  (Cost Collector)│
└─────────────────┘         └────────┬─────────┘
│
┌────────────────┼────────────────┐
│                │                │
▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ Cost Explorer│ │   DynamoDB   │ │  CloudWatch  │
│      API     │ │   (Storage)  │ │    (Logs)    │
└──────────────┘ └──────────────┘ └──────────────┘
│
▼
┌──────────────┐         ┌──────────────┐
│ API Gateway  │────────▶│  S3 + Web    │
│  (REST API)  │         │  (Dashboard) │
└──────────────┘         └──────────────┘

---

## 🚀 Quick Start

### Prerequisites

- AWS Account with CLI configured
- Terraform >= 1.0
- Python 3.10+

### Deploy Infrastructure

```bash
# Clone repository
git clone https://github.com/yourusername/cloudops-insight-hub
cd cloudops-insight-hub

# Deploy AWS resources
cd terraform/aws
terraform init
terraform apply

# Deploy Lambda function
cd ../../backend/aws-collector
zip -r lambda_deployment.zip lambda_function.py
aws lambda update-function-code \
  --function-name cloudops-aws-collector \
  --zip-file fileb://lambda_deployment.zip

# Get API endpoint
cd ../../terraform/aws
terraform output api_gateway_url
```

### Test API

```bash
# Fetch 7-day cost data
curl https://YOUR_API_URL/usage

# Query 30-day period
curl https://YOUR_API_URL/usage?days=30

# Get historical data for specific date
curl https://YOUR_API_URL/usage?date=2026-04-25
```

### Access Dashboard

```bash
# Update API URL in frontend/dashboard.html (line 185)
# Open in browser
open frontend/dashboard.html
```

---

## 📊 API Reference

### `GET /usage`

Fetch AWS cost data for specified period.

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `days` | integer | 7 | Lookback period (1-90 days) |
| `store` | boolean | true | Store data in DynamoDB |
| `date` | string | - | Query historical data (YYYY-MM-DD) |

**Response:**
```json
{
  "message": "Cost data retrieved successfully",
  "timestamp": "2026-04-25T12:00:00.000000",
  "version": "0.3.0",
  "data": {
    "total_cost": 12.45,
    "currency": "USD",
    "period_days": 7,
    "by_service": {
      "AWS Lambda": 0.05,
      "Amazon S3": 4.20,
      "Amazon DynamoDB": 0.00
    },
    "service_count": 11,
    "storage": {
      "status": "success",
      "items_written": 12
    }
  }
}
```

---

## 💰 Cost Analysis

**Monthly Operating Cost:** ~$0.00 (Free Tier)

| Service | Usage | Cost |
|---------|-------|------|
| Lambda | 30 invocations/month, 500ms avg | $0.00 (1M free) |
| API Gateway | ~100 requests/month | $0.00 (1M free) |
| DynamoDB | 25 GB storage, on-demand | $0.00 (25 GB free) |
| CloudWatch Logs | 5 GB/month | $0.00 (5 GB free) |
| EventBridge | 1 rule, 30 invocations | $0.00 (free) |

**Total:** $0.00/month within free tier limits

---

## 🛠️ Technology Stack

**AWS Services:**
- Lambda (Serverless compute)
- API Gateway (REST API)
- DynamoDB (NoSQL database)
- Cost Explorer (Cost data source)
- EventBridge (Scheduled triggers)
- CloudWatch (Logging & monitoring)
- IAM (Access control)
- S3 (Static website hosting)

**Infrastructure:**
- Terraform (Infrastructure as Code)
- Python 3.10 (Lambda runtime)
- Chart.js (Data visualization)

---

## 📈 Future Enhancements

- [ ] Multi-account cost aggregation
- [ ] Cost anomaly detection with SNS alerts
- [ ] Budget forecasting using historical trends
- [ ] Export to CSV/Excel for reporting
- [ ] Mobile app (React Native)
- [ ] Integration with Slack/Teams
- [ ] Comparison with Azure Cost Management API

---

## 🧪 Testing

```bash
# Test Lambda locally
cd backend/aws-collector
python -m pytest tests/

# Test API endpoint
curl -v https://YOUR_API_URL/usage?days=999
# Expected: 400 Bad Request

# Validate Terraform
cd terraform/aws
terraform validate
terraform fmt -check
```

---

## 📝 Project Structure

cloudops-insight-hub/
├── backend/
│   └── aws-collector/
│       ├── lambda_function.py      # Cost collection logic
│       └── lambda_deployment.zip   # Deployment package
├── frontend/
│   └── dashboard.html              # Interactive cost dashboard
├── terraform/
│   └── aws/
│       ├── main.tf                 # Infrastructure definition
│       ├── variables.tf            # Input variables
│       └── outputs.tf              # Output values
├── docs/
│   ├── architecture.md             # Detailed architecture
│   └── deployment-guide.md         # Step-by-step deployment
└── README.md                       # This file


---

## 👨‍💻 Author

**Olatan Soyoye**
- Cloud Engineer
- [Linkedin] https://www.linkedin.com/in/olaitan-soyoye-5a91b6b9?utm_source=share_via&utm_content=profile&utm_medium=member_ios |

---

## 🙏 Acknowledgments

Built as part of cloud engineering portfolio development. Inspired by real-world cost optimization challenges in enterprise AWS environments.

**Star this repo** if you found it helpful! ⭐
