import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(logging.INFO)

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])
LOOKBACK_DAYS = 7


def lambda_handler(event, context):
    params = event.get("queryStringParameters") or {}
    requested = params.get("date")

    try:
        if requested:
            if not is_valid_date(requested):
                return response(400, {"error": "Invalid parameter",
                                      "message": "date must be YYYY-MM-DD"})
            snapshot = load_snapshot(requested)
            if snapshot is None:
                return response(404, {"error": "Not found",
                                      "message": f"No cost snapshot for {requested}"})
        else:
            snapshot = latest_snapshot()
            if snapshot is None:
                return response(404, {"error": "Not found",
                                      "message": f"No cost snapshot in the last {LOOKBACK_DAYS} days"})

        return response(200, {"message": "Cost snapshot retrieved", "data": snapshot})

    except Exception:
        # Full details go to CloudWatch Logs; the caller only gets a reference ID
        logger.exception("Failed to read cost snapshot")
        return response(500, {"error": "Internal server error",
                              "request_id": context.aws_request_id})


def is_valid_date(value):
    if len(value) != 10:
        return False
    try:
        datetime.strptime(value, "%Y-%m-%d")
        return True
    except ValueError:
        return False


def latest_snapshot():
    today = datetime.now(timezone.utc).date()
    for offset in range(LOOKBACK_DAYS):
        snapshot = load_snapshot((today - timedelta(days=offset)).isoformat())
        if snapshot:
            return snapshot
    return None


def load_snapshot(date):
    items = table.query(KeyConditionExpression=Key("pk").eq(f"COST#{date}"))["Items"]
    summary = next((i for i in items if i["sk"] == "SUMMARY"), None)
    if summary is None:
        return None

    services = {
        i["service_name"]: float(i["cost"])
        for i in items if i["sk"].startswith("SERVICE#")
    }
    return {
        "date": date,
        "total_cost": float(summary["total_cost"]),
        "currency": summary.get("currency", "USD"),
        "period_days": int(summary["period_days"]),
        "service_count": int(summary["service_count"]),
        "by_service": dict(sorted(services.items(), key=lambda kv: kv[1], reverse=True)),
        "collected_at": summary.get("timestamp"),
    }


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }
