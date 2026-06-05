# =============================================================================
# File   : kodekloud-eks-iam-roles.tf
# Repo   : ibtisam-iq/silver-stack  (patches/)
# Origin : runbook/iac/terraform/provisioning/eks-on-kodekloud-aws-playground.md
# =============================================================================
#
# PURPOSE
# -------
# Creates the two IAM roles required to provision an EKS cluster on a
# KodeKloud AWS playground lab account.  These role names are the exact
# whitelisted strings in the KodeKloud AWS Organizations Service Control
# Policy (SCP) — any other name causes iam:PassRole to return implicitDeny
# and the entire cluster / node-group creation fails.
#
# WHY THIS FILE EXISTS
# --------------------
# KodeKloud lab accounts run under an AWS Organizations SCP that:
#   1. Blocks iam:PassRole for every role name EXCEPT "eksClusterRole" and
#      "eksNodeRole".
#   2. Blocks eks:CreateNodegroup unconditionally (all tools, all methods).
#
# This Terraform script is the first step of the workaround.  Run it once
# at the start of every lab session before creating the cluster.
#
# WHITELISTED ROLE NAMES (do NOT rename)
# ----------------------------------------
#   eksClusterRole  — passed to the EKS control plane  (eks.amazonaws.com)
#   eksNodeRole     — assumed by self-managed EC2 nodes (ec2.amazonaws.com)
#
# USAGE
# -----
#   mkdir ~/eks-iam-setup && cd ~/eks-iam-setup
#   cp <this-file> main.tf          # Terraform requires the file be named *.tf
#   terraform init
#   terraform apply -auto-approve
#
#   If eksClusterRole already exists from a previous session:
#     terraform import aws_iam_role.eks_cluster_role eksClusterRole
#     terraform apply -auto-approve
#
# NEXT STEP
# ---------
# After apply succeeds, create the cluster using either:
#   a) AWS Console — select eksClusterRole as the cluster service role
#   b) eksctl      — see patches/kodekloud-eks-cluster-eksctl.yaml
# Then provision self-managed worker nodes via the AL2023 CloudFormation
# template (eks:CreateNodegroup is blocked; managed node groups cannot be used).
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
# Assumed by the EKS control plane.  "eksClusterRole" is the whitelisted name.
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

  # Playground sessions may leave the role behind.  Ignore trust-policy drift
  # on import so `apply` does not try to overwrite it and hit iam:UpdateAssumeRolePolicy.
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
# Assumed by self-managed EC2 worker nodes.  "eksNodeRole" is the whitelisted name.
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

# Optional: enables AWS Systems Manager Session Manager access to nodes,
# avoiding SSH key management on ephemeral playground instances.
resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
