output "gitlab_url" {
  description = "GitLab URL"
  value       = "http://${aws_instance.gitlab.public_ip}"
}

output "gitlab_public_ip" {
  description = "GitLab public IP"
  value       = aws_instance.gitlab.public_ip
}

output "ssh_command" {
  description = "SSH command"
  value       = "ssh -i <your-key>.pem ec2-user@${aws_instance.gitlab.public_ip}"
}

output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.gitlab.id
}

output "s3_backup_bucket" {
  description = "S3 backup bucket name"
  value       = aws_s3_bucket.gitlab_backups.id
}
