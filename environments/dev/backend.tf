# Remote state in S3 with native lockfile locking (Terraform >= 1.10).
# Backend settings are supplied at init time so no account-specific values
# are committed:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example.
terraform {
  backend "s3" {}
}
