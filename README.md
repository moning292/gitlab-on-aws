# gitlab-on-aws

Deploy GitLab Community Edition on AWS using Terraform.

## Architecture

- EC2 instance running GitLab CE
- EFS for all GitLab data (repositories, uploads, CI builds)
- S3 for automated backups
- VPC with public subnet

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with credentials
- EC2 key pair created in your AWS region

## Usage

### 1. Clone and Configure

```bash
cd gitlab-on-aws
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:
```hcl
aws_region    = "us-east-1"        # Your AWS region
instance_type = "t3.medium"        # EC2 instance type
key_name      = "your-key-name"    # Your EC2 key pair name
allowed_cidr  = "0.0.0.0/0"        # IP range allowed to access GitLab
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Deployment takes ~10-15 minutes. GitLab installation happens automatically.

### 3. Access GitLab

After deployment completes:

```bash
# Get GitLab URL
terraform output gitlab_url

# SSH into instance to get initial root password
terraform output ssh_command
sudo cat /etc/gitlab/initial_root_password
```

Login with:
- Username: `root`
- Password: (from the file above)

### 4. Verify Storage

SSH into the instance and verify:
```bash
# Check EFS mount
df -h | grep gitlab-data

# Check GitLab data locations
sudo gitlab-rake gitlab:env:info
```

## Backup and Restore

### Manual Backup
```bash
sudo gitlab-backup create
```
Backups are automatically uploaded to S3.

### Restore from Backup
```bash
# List backups in S3
aws s3 ls s3://$(terraform output -raw s3_backup_bucket)/

# Restore (SSH into instance)
sudo gitlab-backup restore BACKUP=<timestamp>
```

## Cleanup

```bash
terraform destroy
```

**Note:** This will delete all resources including EFS data and S3 backups.

## Resources Created

- VPC with public subnet and internet gateway
- EC2 instance (t3.medium, 30GB EBS for OS only)
- EFS file system (encrypted, stores all GitLab data)
- S3 bucket (versioned, for backups)
- Security groups (SSH, HTTP, HTTPS, NFS)
- IAM role and instance profile (S3 access)

## Cost Estimate

- EC2 t3.medium: ~$30/month
- EFS: ~$0.30/GB/month
- S3: ~$0.023/GB/month
- Data transfer: Variable
