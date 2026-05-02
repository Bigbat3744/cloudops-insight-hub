import json
import logging
import boto3
from datetime import datetime, timedelta
from typing import Dict, Any, List
from decimal import Decimal

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients (reused across warm starts)
ce_client = boto3.client("ce", region_name="us-east-1")
dynamodb = boto3.resource("dynamodb", region_name="us-east-1")
table = dynamodb.Table("cloudops-usage")


def lambda_handler(event, context) -> Dict[str, Any]:
    """
    CloudOps AWS Collector - Fetches cost data and stores in DynamoDB.

    Query parameters:
    - days: Number of days to look back (default: 7, max: 90)
    - store: Whether to store in DynamoDB (default: true)
    - date: Query historical data for specific date (YYYY-MM-DD)
    """

    logger.info("Lambda function invoked")

    try:
        query_params = event.get("queryStringParameters") or {}

        # Check if this is a historical query
        query_date = query_params.get("date")
        if query_date:
            historical_data = query_historical_data(query_date)

            return create_response(
                200,
                {
                    "message": "Historical data retrieved",
                    "timestamp": datetime.utcnow().isoformat(),
                    "version": "0.3.0",
                    "data": historical_data,
                },
            )

        # Parse query parameters
        query_params = event.get("queryStringParameters") or {}
        days = int(query_params.get("days", 7))
        should_store = query_params.get("store", "true").lower() != "false"

        # Validate input
        if days < 1 or days > 90:
            return create_response(
                400,
                {
                    "error": "Invalid parameter",
                    "message": "days must be between 1 and 90",
                },
            )

        # Fetch cost data
        cost_data = get_cost_data(days)

        # Store in DynamoDB if requested
        if should_store and cost_data["by_service"]:
            storage_result = store_cost_data(cost_data)
            cost_data["storage"] = storage_result

        # Build response
        response_body = {
            "message": "Cost data retrieved successfully",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "0.3.0",
            "data": cost_data,
        }

        return create_response(200, response_body)

    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        return create_response(
            500, {"error": "Internal server error", "message": str(e)}
        )


def get_cost_data(days: int) -> Dict[str, Any]:
    """Fetch AWS cost data from Cost Explorer."""

    end_date = datetime.utcnow().date()
    start_date = end_date - timedelta(days=days)

    logger.info(f"Fetching cost data from {start_date} to {end_date}")

    try:
        response = ce_client.get_cost_and_usage(
            TimePeriod={"Start": start_date.isoformat(), "End": end_date.isoformat()},
            Granularity="DAILY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )

        # Process the response
        cost_by_service = {}
        total_cost = 0.0

        for result_by_time in response["ResultsByTime"]:
            for group in result_by_time["Groups"]:
                service_name = group["Keys"][0]
                cost = float(group["Metrics"]["UnblendedCost"]["Amount"])

                if service_name in cost_by_service:
                    cost_by_service[service_name] += cost
                else:
                    cost_by_service[service_name] = cost

                total_cost += cost

        # Sort by cost (highest first)
        sorted_services = dict(
            sorted(cost_by_service.items(), key=lambda x: x[1], reverse=True)
        )

        return {
            "total_cost": round(total_cost, 2),
            "currency": "USD",
            "period_days": days,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "by_service": {
                service: round(cost, 2) for service, cost in sorted_services.items()
            },
            "service_count": len(sorted_services),
        }

    except Exception as e:
        logger.error(f"Error fetching cost data: {str(e)}")
        raise


def store_cost_data(cost_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Store cost data in DynamoDB using single-table design.

    Schema:
    - pk: COST#YYYY-MM-DD (partition key)
    - sk: SERVICE#<service_name> (sort key)
    - cost: Decimal (cost amount)
    - currency: String
    - timestamp: ISO timestamp
    - ttl: Unix timestamp (expires after 90 days)
    """

    try:
        today = datetime.utcnow().date().isoformat()
        timestamp = datetime.utcnow().isoformat()

        # Calculate TTL (90 days from now)
        ttl = int((datetime.utcnow() + timedelta(days=90)).timestamp())

        items_written = 0

        # Store summary record
        table.put_item(
            Item={
                "pk": f"COST#{today}",
                "sk": "SUMMARY",
                "total_cost": Decimal(str(cost_data["total_cost"])),
                "currency": cost_data["currency"],
                "service_count": cost_data["service_count"],
                "period_days": cost_data["period_days"],
                "timestamp": timestamp,
                "ttl": ttl,
            }
        )
        items_written += 1

        # Store per-service records
        for service, cost in cost_data["by_service"].items():
            if cost != 0:  # Skip zero-cost services
                table.put_item(
                    Item={
                        "pk": f"COST#{today}",
                        "sk": f"SERVICE#{service}",
                        "service_name": service,
                        "cost": Decimal(str(cost)),
                        "currency": cost_data["currency"],
                        "timestamp": timestamp,
                        "ttl": ttl,
                    }
                )
                items_written += 1

        logger.info(f"Stored {items_written} items in DynamoDB")

        return {
            "status": "success",
            "items_written": items_written,
            "table": "cloudops-usage",
            "date": today,
        }

    except Exception as e:
        logger.error(f"Error storing cost data: {str(e)}", exc_info=True)
        return {"status": "error", "message": str(e)}


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Create a properly formatted API Gateway response."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        },
        "body": json.dumps(body, indent=2, default=str),  # default=str handles Decimal
    }


def query_historical_data(date: str) -> Dict[str, Any]:
    """
    Query cost data for a specific date from DynamoDB.

    Args:
        date: ISO date string (YYYY-MM-DD)

    Returns:
        Dict containing cost data for that date
    """

    try:
        response = table.query(
            KeyConditionExpression="pk = :pk",
            ExpressionAttributeValues={":pk": f"COST#{date}"},
        )

        items = response.get("Items", [])

        if not items:
            return {
                "date": date,
                "status": "no_data",
                "message": f"No cost data found for {date}",
            }

        # Extract summary and services
        summary = next((item for item in items if item["sk"] == "SUMMARY"), None)
        services = [item for item in items if item["sk"].startswith("SERVICE#")]

        return {
            "date": date,
            "total_cost": float(summary.get("total_cost", 0)) if summary else 0,
            "service_count": len(services),
            "by_service": {
                item["service_name"]: float(item["cost"]) for item in services
            },
            "timestamp": summary.get("timestamp") if summary else None,
        }

    except Exception as e:
        logger.error(f"Error querying historical data: {str(e)}")
        raise
