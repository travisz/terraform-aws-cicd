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

# CodeBuild IAM Permissions
data "template_file" "codepipeline_assume_role_template" {
  template = file("${path.module}/policies/codebuild_assume_role.json")
}

resource "aws_iam_role" "codebuild_assume_role" {
  name               = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codebuild-role"
  assume_role_policy = data.template_file.codepipeline_assume_role_template.rendered
}

# CodeBuild Policy Template
data "template_file" "codebuild_policy_template" {
  template = file("${path.module}/policies/codebuild.json")
  vars = {
    artifact_bucket           = aws_s3_bucket.artifact_bucket.arn
    aws_kms_key               = aws_kms_key.artifact_key.arn
    codebuild_project_package = aws_codebuild_project.package.id
  }
}

# CodeBuild Role Policy
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codepipeline-${data.aws_region.current.name}-${substr(random_uuid.id.result, 0, 7)}-codebuild-policy"
  role = aws_iam_role.codebuild_assume_role.id

  policy = data.template_file.codebuild_policy_template.rendered
}

# CodeBuild - Package
resource "aws_codebuild_project" "package" {
  name           = "${var.repo_name}-package"
  description    = "CodeBuild Package Project for ${var.repo_name}"
  service_role   = aws_iam_role.codebuild_assume_role.arn
  build_timeout  = var.build_timeout
  encryption_key = aws_kms_key.artifact_key.arn

  artifacts {
    packaging = "ZIP"
    type      = "CODEPIPELINE"
  }

  environment {
    compute_type    = var.build_compute_type
    image           = var.build_image
    type            = "LINUX_CONTAINER"
    privileged_mode = var.build_privileged
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = var.package_buildspec
  }
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
    name = "Package"

    action {
      name             = "Package"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source"]
      output_artifacts = ["package"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.package.name
      }
    }
  }
}