variable "github_repository" {
  description = "owner/repo allowed to assume the CI plan role"
  type        = string
  default     = "Bigbat3744/cloudops-insight-hub"
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket_arn = "arn:aws:s3:::cloudops-tfstate-${data.aws_caller_identity.current.account_id}"
  state_key        = "cloudops-insight-hub/aws/terraform.tfstate"
}

# 1. Tell AWS to trust ID cards signed by GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# 2. Who may use the role: only pull requests in this one repo
data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:pull_request"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "cloudops-github-plan"
  description          = "Read-only role for terraform plan in GitHub Actions (PRs only)"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

# 3. What the role may do: read this stack's resources and the state file, nothing else
data "aws_iam_policy_document" "github_plan_permissions" {
  statement {
    sid = "ReadStackResources"
    actions = [
      "lambda:Get*", "lambda:List*",
      "iam:Get*", "iam:List*",
      "apigateway:GET",
      "dynamodb:Describe*", "dynamodb:List*",
      "logs:Describe*", "logs:ListTagsForResource", "logs:ListTagsLogGroup",
      "events:Describe*", "events:List*",
      "sns:Get*", "sns:List*",
      "cloudwatch:Describe*", "cloudwatch:GetDashboard", "cloudwatch:ListTagsForResource",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "ReadState"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/${local.state_key}"]
  }

  statement {
    sid       = "StateLockFile"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/${local.state_key}.tflock"]
  }
}

resource "aws_iam_role_policy" "github_plan" {
  name   = "cloudops-github-plan-read-only"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan_permissions.json
}
