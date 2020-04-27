# terraform-aws-cicd

Terraform module for creating an AWS CodeCommit repository that is integrated into AWS CodeBuild and CodePipeline.

[![Actions Status](https://github.com/travisz/terraform-aws-cicd/workflows/GitHub%20Actions/badge.svg)](https://github.com/travisz/terraform-aws-cicd/actions)
![GitHub release](https://img.shields.io/github/release/travisz/terraform-aws-cicd.svg)
[![](https://img.shields.io/github/license/travisz/terraform-aws-cicd)](https://github.com/travisz/terraform-aws-cicd)
[![](https://img.shields.io/github/issues/travisz/terraform-aws-cicd)](https://github.com/travisz/terraform-aws-cicd)
[![](https://img.shields.io/github/issues-closed/travisz/terraform-aws-cicd)](https://github.com/travisz/terraform-aws-cicd)
[![](https://img.shields.io/github/languages/code-size/travisz/terraform-aws-cicd)](https://github.com/travisz/terraform-aws-cicd)
[![](https://img.shields.io/github/repo-size/travisz/terraform-aws-cicd)](https://github.com/travisz/terraform-aws-cicd)

## Notes
CodePipline in this module has **Source** and **Package** stages. Additional stages will be added later.

## CodeCommit Notes

When a new Codecommit repo is created it does **not** automatically create a default branch. After running this module you will need to clone the repoistory, add content and push to the `origin/<default_branch>` to initilize the repository. Once that is done Codebuild should start again and pull down the latest copy of the branch specified in the configuration.

## Basic Usage
```hcl
module "app-pipeline" {
  source    = "git::https://github.com/travisz/terraform-aws-cicd?ref=master"
  region    = "us-east-1"
  repo_name = "myapp"
}
```

## Inputs
| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-------:|:--------:|
| build_compute_type |Size of the CodeBuild Compute Tier | string | `BUILD_GENERAL1_SMALL` | no |
| build_image | The build image for CodeBuild to use | string | `aws/codebuild/standard:3.0` | no |
| build_privileged | Build the Docker Container in Privilged Mode | string | `false` | no |
| build_timeout | Timeout for Codebuild (minutes) | number | `10` | no |
| force_artifact_destroy | Force destroy S3 bucket upon deletion | boolean | `false` | no |
| package_buildspec | The buildspec file to be used during the package phase | string | `buildspec.yml` | no |
| region | The AWS Region to deploy into | string | `` | yes |
| repo_default_branch | Default branch of the repo to use | string | `master` | no |
| repo_name | Name of the respoitory to create in CodeCommit | string | `` | yes |
