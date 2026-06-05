# =============================================================================
# File   : kodekloud-eks-iam-roles.tf
# Repo   : ibtisam-iq/silver-stack  (patches/)
# Origin : runbook/iac/terraform/provisioning/eks-on-kodekloud-aws-playground.md
# =============================================================================
#
# PURPOSE
# -------
# Creates the two SCP-whitelisted IAM roles required to provision an EKS
# cluster on a KodeKloud AWS playground lab account.  These are not arbitrary
# names — they are the exact strings the KodeKloud AWS Organizations Service
# Control Policy (SCP) allows through iam:PassRole.  Any other name returns
# implicitDeny and the entire cluster creation fails before a single resource
# is created.
#
# WHY THIS FILE EXISTS
# --------------------
# I hit these SCP blocks on every KodeKloud lab session before writing this.
# The policy enforces two hard restrictions at the AWS Organization level —
# no account-level override is possible:
#
#   1. iam:PassRole is allowed ONLY for roles named "eksClusterRole" or
#      "eksNodeRole".  I confirmed this via the IAM policy simulator:
#      EvalDecision returns implicitDeny, AllowedByOrganizations returns False.
#
#   2. eks:CreateNodegroup is blocked unconditionally — I verified this across
#      the Console, eksctl, AWS CLI, and Terraform.  All four return
#      AccessDeniedException.  Managed node groups are not an option here.
#
# Run this file once at the start of every lab session before creating
# the cluster.  Do not rename the roles.
#
# WHITELISTED ROLE NAMES (do NOT rename)
# ----------------------------------------
#   eksClusterRole  — passed to the EKS control plane  (eks.amazonaws.com)
#   eksNodeRole     — assumed by self-managed EC2 nodes (ec2.amazonaws.com)
#
# USAGE
# -----
#   mkdir ~/eks-iam-setup && cd ~/eks-iam-setup
#   cp <this-file> main.tf          # Terraform requires the entry file be *.tf
#   terraform init
#   terraform apply -auto-approve
#
#   If eksClusterRole already exists from a previous session, import it first:
#     terraform import aws_iam_role.eks_cluster_role eksClusterRole
#     terraform apply -auto-approve
#
# NEXT STEP
# ---------
# Once apply succeeds, create the EKS control plane using either:
#   a) AWS Console — select eksClusterRole as the cluster service role
#   b) eksctl      — use patches/kodekloud-eks-cluster-eksctl.yaml
#
# Provision worker nodes via the AL2023 CloudFormation self-managed node
# template.  eks:CreateNodegroup is blocked — managed node groups cannot
# be created on this platform regardless of the tool.
#
# FULL RUNBOOK
# ------------
# https://github.com/ibtisam-iq/runbook/blob/main/iac/terraform/provisioning/eks-on-kodekloud-aws-playground.md
# =============================================================================

provider "aws" {
  region = "us-east-1"
}

# -----------------------------------------------------------------------------
# EKS Cluster Role
# Assumed by the EKS control plane.  "eksClusterRole" is the SCP-whitelisted name.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  # Playground sessions often leave this role behind.  Ignoring trust-policy
  # drift on import prevents `apply` from attempting iam:UpdateAssumeRolePolicy,
  # which the SCP also restricts.
  lifecycle {
    ignore_changes = [assume_role_policy]
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -----------------------------------------------------------------------------
# EKS Node Role
# Assumed by self-managed EC2 worker nodes.  "eksNodeRole" is the SCP-whitelisted name.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Enables AWS Systems Manager Session Manager access to nodes — eliminates
# SSH key management on ephemeral playground instances.
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
