# ============================================================
# eks.tf - EKS cluster using raw AWS resources
# ============================================================
# Why not terraform-aws-modules/eks/aws?
#   The module v21.x silently drops bootstrap_cluster_creator_admin_permissions
#   when create_iam_role = false, leaving the cluster with no admin access.
#   Using raw resources gives direct, transparent control over every field
#   passed to the AWS API — no module abstraction in the way.
#
# KodeKloud SCP constraints handled:
#   1. iam:PassRole: eksClusterRole (whitelisted name) used via iam-eks.tf
#   2. iam:TagPolicy: no KMS encryption, no encryption IAM policy
#   3. eks:CreateNodegroup: no managed node groups; self-managed via CF
#   4. logs:DeleteLogGroup: EKS manages its own log group, not Terraform
#   5. eks:AssociateAccessPolicy: avoided via bootstrapClusterCreatorAdminPermissions
#   6. eks:DeleteAddon: preserve = true on all addons
# ============================================================

# ---- Security group: bastion to EKS API (port 443) ---------

resource "aws_security_group" "eks_additional" {
  name        = "${var.project_name}-eks-additional-sg"
  description = "Allow bastion host to reach EKS API on port 443"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTPS from bastion host"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-eks-additional-sg"
  }
}

# ---- EKS cluster -------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [aws_security_group.eks_additional.id]
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"

    # Directly passes bootstrapClusterCreatorAdminPermissions = true to the
    # AWS API at cluster creation time. EKS handles the admin access entry
    # internally — no eks:AssociateAccessPolicy call is made. This is the
    # only reliable way to get kubectl access under KodeKloud SCP constraints.
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# ---- OIDC provider (for IRSA) ------------------------------

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.project_name}-eks-oidc"
  }
}

# ---- Addons ------------------------------------------------
# preserve = true: eks:DeleteAddon is blocked by the KodeKloud SCP.
# Terraform abandons these resources in state on destroy without calling
# the AWS API, avoiding AccessDeniedException on terraform destroy.

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  preserve                    = true
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  preserve                    = true
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  preserve                    = true
}

# CoreDNS is intentionally excluded from Terraform management.
# aws_eks_addon for coredns waits up to 20 minutes for Active status,
# but CoreDNS stays Degraded until worker nodes exist to schedule its
# pods — terraform apply would hang and eventually time out on a fresh
# cluster with no nodes. EKS installs CoreDNS automatically as a
# built-in Kubernetes deployment; it becomes Running on its own once
# self-managed nodes join the cluster. No Terraform resource
# is needed and no manual step is required.

# ---- NO managed node groups -------------------------------------
# eks:CreateNodegroup is blocked unconditionally by the KodeKloud SCP.
# Worker nodes are provisioned as self-managed via the AWS CloudFormation 
# EKS node template after terraform apply.
