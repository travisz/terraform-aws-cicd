output "artifact_bucket_id" {
  value = aws_s3_bucket.artifact_bucket.id
}

output "artifact_bucket_arn" {
  value = aws_s3_bucket.artifact_bucket.arn
}

output "codepipeline_id" {
  value = aws_codepipeline.codepipeline.id
}

output "kms_key_arn" {
  value = aws_kms_key.artifact_key.arn
}

output "repo_https_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_http
}

output "repo_ssh_endpoint" {
  value = aws_codecommit_repository.repo.clone_url_ssh
}
