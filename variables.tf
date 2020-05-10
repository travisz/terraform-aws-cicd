variable "asg_groups" {
  description = "List of the auto-scaling groups to associate with CodeDeploy's Deployment Group"
  type        = list
}

variable "build_compute_type" {
  default     = "BUILD_GENERAL1_SMALL"
  description = "Size of the CodeBuild Compute Tier (default: BUILD_GENERAL1_SMALL)"
  type        = string
}

variable "build_image" {
  default     = "aws/codebuild/standard:3.0"
  description = "The build image for CodeBuild to use (default: aws/codebuild/standard:3.0)"
  type        = string
}

variable "build_privileged" {
  default     = "false"
  description = "Build the Docker Container in Privilged Mode (default: false)"
  type        = bool
}

variable "build_timeout" {
  default     = "10"
  description = "Timeout for Codebuild (default: 10)"
  type        = number
}

variable "force_artifact_destroy" {
  default     = "false"
  description = "Force destroy S3 bucket upon deletion (default: false)"
  type        = bool
}

variable "package_buildspec" {
  description = "The buildspec file to be used during the package phase (default: buildspec.yml)"
  default     = "buildspec.yml"
  type        = string
}

variable "region" {
  description = "The AWS Region to deploy into"
  type        = string
}

variable "repo_default_branch" {
  default     = "master"
  description = "Default branch of the repo to use (default: master)"
  type        = string
}

variable "repo_name" {
  description = "Name of the respoitory to create in CodeCommit"
  type        = string
}

variable "tag_name_for_codedeploy" {
  description = "The Tag to use for the CodeDeploy Deployment Group"
  type        = string
}
