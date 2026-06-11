# ============================================================
# vpc.tf — VPC, subnets, NAT gateway, route tables
# Module: terraform-aws-modules/vpc/aws  v6.6.1
# ============================================================
# Improvements over instructor baseline:
#  • Name derived from var.project_name — no hardcoded "test-vpc-01"
#  • DNS hostnames + support explicitly enabled (required for EKS)
#  • enable_vpn_gateway kept false (not needed here)
#  • map_public_ip_on_launch explicitly on public subnets only
#  • EKS-required subnet tags preserved
# ============================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  # NAT gateway — single gateway is enough for dev/staging
  # Set single_nat_gateway = false for production HA
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_vpn_gateway   = false

  # Public subnets get automatic public IPs (needed for bastion + ALB)
  map_public_ip_on_launch = true

  # Required by EKS so that Kubernetes can resolve node DNS names
  enable_dns_hostnames = true
  enable_dns_support   = true

  # ---- EKS subnet discovery tags ----------------------------
  # AWS Load Balancer Controller uses these to auto-discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                        = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"               = "1"
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}
