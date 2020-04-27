output "artifact_bucket" {
  value = aws_s3_bucket.artifact_bucket.id
}

output "codebuild_package_id" {
  value = aws_codebuild_project.package.id
}

output "codepipeline_id" {
  value = aws_codepipeline.codepipeline.id
}

output "repo_https_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_http
}

output "repo_ssh_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_ssh
}
