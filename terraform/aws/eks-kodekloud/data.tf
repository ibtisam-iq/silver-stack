# ============================================================
# data.tf — data sources (AMI lookup, caller IP)
# ============================================================

# ----------------------------------------------------------
# Operator's current public IP — used to lock bastion SSH
# ingress to exactly the machine running `terraform apply`
# ----------------------------------------------------------
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# ----------------------------------------------------------
# Ubuntu 26.04 LTS (Noble Numbat) AMI
# Owner: 099720109477 = Canonical
# Filter matches the exact naming convention used by Canonical
# for Ubuntu 26.04 with GP3-backed storage (hvm-ssd-gp3).
# most_recent = true always picks the latest patch release.
#
# Equivalent AWS CLI command:
#   export AMI_ID=$(aws ec2 describe-images \
#     --owners 099720109477 \
#     --filters \
#       "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*" \
#       "Name=state,Values=available" \
#     --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
#     --output text)
# ----------------------------------------------------------
data "aws_ami" "ubuntu_2604" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ----------------------------------------------------------
# Current AWS account identity — useful for ARN construction
# and for asserting which account we are deploying into.
# ----------------------------------------------------------
data "aws_caller_identity" "current" {}

# ----------------------------------------------------------
# Current AWS region — allows outputs and resource names to
# reference the region without hardcoding.
# ----------------------------------------------------------
data "aws_region" "current" {}
