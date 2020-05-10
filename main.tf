provider "aws" {
  region = var.region
}

data "aws_region" "current" {}

# Random UUID
resource "random_uuid" "id" {}

# CodeCommit Resources
resource "aws_codecommit_repository" "repo" {
  repository_name = var.repo_name
  description     = "${var.repo_name} repository"
  default_branch  = var.repo_default_branch
}

# CodeDeploy Resources
# CodeDeploy Assume Role and Policy Attachment
data "aws_iam_policy_document" "codedeploy_policy_document" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codedeploy" {
  name               = "codedeploy-role"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_policy_document.json
}

resource "aws_iam_role_policy_attachment" "codedeploy_role" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.codedeploy.name
}

resource "aws_codedeploy_app" "codedeploy" {
  name = var.repo_name
}

resource "aws_codedeploy_deployment_group" "codedeploy_dg" {
  app_name               = aws_codedeploy_app.codedeploy.name
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_group_name  = "${var.repo_name}-deployment-group"
  service_role_arn       = aws_iam_role.codedeploy.arn
  autoscaling_groups     = var.asg_groups

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = var.tag_name_for_codedeploy
   }
  }

}

# Codepipeline Resources
# S3 bucket for Artifact storage
resource "aws_s3_bucket" "artifact_bucket" {
  bucket        = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}"
  acl           = "private"
  force_destroy = var.force_artifact_destroy
}

# Policy Document for CodePipeline Assume Role
data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

# IAM for CodePipeline with previously defined policy document
resource "aws_iam_role" "codepipeline_role" {
  name               = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json
}

# IAM Policy Template for CodePipeline to use CodeCommit and CodeBuild
data "template_file" "codepipeline_policy_template" {
  template = file("${path.module}/policies/codepipeline.json")
  vars = {
    aws_kms_key     = aws_kms_key.artifact_key.arn
    artifact_bucket = aws_s3_bucket.artifact_bucket.arn
  }
}

# Attach Policy Document for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy_attach" {
  name = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = data.template_file.codepipeline_policy_template.rendered
}

# Encryption key for artifacts
resource "aws_kms_key" "artifact_key" {
  description             = "kms-artifact-encryption-key"
  deletion_window_in_days = 10
}

# SNS URL
resource "aws_sns_topic" "approval" {
  name = "${var.repo_name}-deployment-approval"
}

# CodePipeline Creation
resource "aws_codepipeline" "codepipeline" {
  name     = var.repo_name
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.artifact_key.arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]

      configuration = {
        RepositoryName = var.repo_name
        BranchName     = var.repo_default_branch
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "Approval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        NotificationArn = aws_sns_topic.approval.arn
        CustomData      = "Approve Code Deployment for ${var.repo_name}"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Deploy"
      owner            = "AWS"
      provider         = "CodeDeploy"
      input_artifacts  = ["source"]
      version          = "1"

      configuration = {
        ApplicationName     = aws_codedeploy_app.codedeploy.name
        DeploymentGroupName = aws_codedeploy_deployment_group.codedeploy_dg.deployment_group_name
      }
    }
  }
}
