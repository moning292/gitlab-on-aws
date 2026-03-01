#!/bin/bash
set -e

# Update system
yum update -y
yum install -y curl openssh-server postfix perl nfs-utils

# Start and enable postfix
systemctl enable postfix
systemctl start postfix

# Mount EFS
mkdir -p /mnt/gitlab-data
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${efs_id}.efs.${aws_region}.amazonaws.com:/ /mnt/gitlab-data
echo "${efs_id}.efs.${aws_region}.amazonaws.com:/ /mnt/gitlab-data nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab

# Create GitLab directories on EFS
mkdir -p /mnt/gitlab-data/git-data
mkdir -p /mnt/gitlab-data/gitlab-rails/shared
mkdir -p /mnt/gitlab-data/gitlab-rails/uploads
mkdir -p /mnt/gitlab-data/gitlab-ci/builds

# Install GitLab CE
curl -sS https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
EXTERNAL_URL="http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" yum install -y gitlab-ce

# Configure GitLab to use EFS for all data and S3 for backups
cat >> /etc/gitlab/gitlab.rb <<EOF
git_data_dirs({
  "default" => {
    "path" => "/mnt/gitlab-data/git-data"
  }
})

gitlab_rails['shared_path'] = '/mnt/gitlab-data/gitlab-rails/shared'
gitlab_rails['uploads_directory'] = '/mnt/gitlab-data/gitlab-rails/uploads'
gitlab_ci['builds_directory'] = '/mnt/gitlab-data/gitlab-ci/builds'

gitlab_rails['backup_upload_connection'] = {
  'provider' => 'AWS',
  'region' => '${aws_region}',
  'use_iam_profile' => true
}
gitlab_rails['backup_upload_remote_directory'] = '${s3_bucket}'
gitlab_rails['backup_keep_time'] = 604800
EOF

# Configure and start GitLab
gitlab-ctl reconfigure
