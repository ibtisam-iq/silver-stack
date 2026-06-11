# ============================================================
# outputs.tf - values printed after terraform apply
# ============================================================

# ---- VPC ---------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Primary CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private (EKS node) subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public (NAT-GW + bastion) subnets"
  value       = module.vpc.public_subnets
}

# ---- EKS ---------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "HTTPS endpoint of the EKS API server (private)"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate, used in kubeconfig"
  value       = aws_eks_cluster.this.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL, needed for IRSA"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "kubeconfig_command" {
  description = "Run this on the bastion host to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.this.name}"
}

# ---- IAM (Self-managed nodes) ---------------------

output "eks_node_role_arn" {
  description = "ARN of eksNodeRole, needed for the CF self-managed node stack"
  value       = aws_iam_role.eks_node_role.arn
}

# ---- Bastion -----------------------------------------------

output "bastion_public_ip" {
  description = "Public IP address of the bastion host"
  value       = module.bastion.public_ip
}

output "bastion_ssh_command" {
  description = "SSH command to connect to the bastion host"
  value       = "ssh -i ${var.bastion_key_name}.pem ubuntu@${module.bastion.public_ip}"
}

output "bastion_ami_id" {
  description = "Ubuntu 26.04 AMI ID used for the bastion host"
  value       = data.aws_ami.ubuntu_2604.id
}

# ---- Account / Region --------------------------------------

output "aws_account_id" {
  description = "AWS account ID resources were deployed into"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region resources were deployed into"
  value       = data.aws_region.current.name
}
