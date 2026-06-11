# EKS on KodeKloud AWS Playground

> Terraform configuration for provisioning a production-pattern Amazon EKS cluster
> on a **KodeKloud AWS Playground** account — an environment where an AWS Organizations
> SCP silently blocks several standard EKS operations that work everywhere else.

This code exists because the standard approaches (EKS Terraform module, eksctl, managed
node groups) all fail on KodeKloud due to specific SCP restrictions. Every decision in
this configuration is a verified workaround for a concrete error. The companion runbook
documents every error encountered and its fix:
[eks-on-kodekloud-terraform-challenges.md](../../runbooks/eks-on-kodekloud-terraform-challenges.md)

---

## What This Provisions

| Resource | Detail |
|---|---|
| VPC | 3 AZs, public + private subnets, single NAT gateway |
| Bastion host | Ubuntu 26.04, public subnet, SSH-locked to operator IP |
| EKS cluster | v1.36, private API endpoint, `API_AND_CONFIG_MAP` auth |
| EKS addons | `vpc-cni`, `kube-proxy`, `eks-pod-identity-agent` (no CoreDNS) |
| OIDC provider | For IRSA (IAM Roles for Service Accounts) |
| IAM roles | `eksClusterRole`, `eksNodeRole` with exact SCP-whitelisted names |
| Worker nodes | **Not provisioned by Terraform** — use CloudFormation (see Phase 2) |

---

## Why Not the `terraform-aws-modules/eks` Module?

The EKS module v21.x silently drops `bootstrap_cluster_creator_admin_permissions`
when `create_iam_role = false`. Since KodeKloud's SCP only allows `iam:PassRole` for
roles named exactly `eksClusterRole`, `create_iam_role` must be `false` — which leaves
the cluster with no admin access. This configuration uses a raw `aws_eks_cluster`
resource to pass the setting directly to the AWS API, bypassing the module abstraction.

---

## SCP Restrictions and Workarounds

| Blocked Action | Workaround Applied |
|---|---|
| `iam:PassRole` (non-whitelisted name) | `iam-eks.tf` creates roles with exact names `eksClusterRole` / `eksNodeRole` |
| `iam:TagPolicy` | KMS encryption disabled entirely |
| `eks:CreateNodegroup` | Managed node groups removed; CloudFormation self-managed nodes used |
| `eks:AssociateAccessPolicy` | `bootstrap_cluster_creator_admin_permissions = true` on the raw cluster resource |
| `eks:DeleteAddon` | `preserve = true` on all `aws_eks_addon` resources |
| `logs:DeleteLogGroup` | EKS manages its own log group; not declared in Terraform |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Active KodeKloud lab session | Do not start with less than 45 minutes remaining |
| AWS CLI | `aws sts get-caller-identity` to confirm credentials |
| Terraform >= 1.5.7 | `terraform version` |
| kubectl | Required for Phase 2 (node verification) |

---

## Quick Start

### Phase 1 — Terraform Apply

```bash
git clone https://github.com/ibtisam-iq/silver-stack.git
cd silver-stack/terraform/aws/eks-kodekloud

# Configure KodeKloud lab credentials
aws configure
aws sts get-caller-identity

# Fresh state is required on each new KodeKloud lab session
# (account ID changes when the session expires)
rm -f terraform.tfstate terraform.tfstate.backup

terraform init
terraform apply
```

Expected apply time: 12 to 15 minutes (EKS control plane creation dominates).

After apply, the output includes the SSH command to connect to the bastion and the
`kubeconfig_command` to run on it.

### Phase 2 — Worker Nodes (CloudFormation)

Worker nodes cannot be provisioned by Terraform because `eks:CreateNodegroup` is
blocked. Run these commands from the bastion host after SSH-ing in.

```bash
# SSH to bastion using the output from terraform apply
ssh -i microservices-demo-bastion-key.pem ubuntu@<bastion_public_ip>

# Configure credentials on the bastion
aws configure   # same KodeKloud credentials
aws sts get-caller-identity

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name silver-stack-eks
kubectl get nodes   # should return "No resources found" — NOT Forbidden
```

> **Stop if kubectl returns Forbidden or an auth error.** Proceeding with broken
> kubectl access means nodes will join but cannot be managed. See
> [Troubleshooting](#troubleshooting).

```bash
# Set variables
CLUSTER_NAME=silver-stack-eks
REGION=us-east-1

VPC_ID=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.resourcesVpcConfig.vpcId" --output text)

CLUSTER_SG=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

SUBNET_IDS=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
            "Name=tag:kubernetes.io/role/internal-elb,Values=1" \
  --query "Subnets[*].SubnetId" \
  --output text | tr '\t' ',')

API_SERVER=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.endpoint" --output text)

CA_DATA=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.certificateAuthority.data" --output text)

SERVICE_CIDR=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.kubernetesNetworkConfig.serviceIpv4Cidr" --output text)

K8S_VERSION=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.version" --output text)

AUTH_MODE_RAW=$(aws eks describe-cluster --name "$CLUSTER_NAME" \
  --query "cluster.accessConfig.authenticationMode" --output text)

case "$AUTH_MODE_RAW" in
  API)                AUTH_MODE_PARAM="EKS API" ;;
  API_AND_CONFIG_MAP) AUTH_MODE_PARAM="EKS API and ConfigMap" ;;
  CONFIG_MAP)         AUTH_MODE_PARAM="ConfigMap" ;;
esac

# Create EC2 key pair for node SSH access
aws ec2 create-key-pair \
  --key-name eks-nodes-key \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/eks-nodes-key.pem
chmod 400 ~/.ssh/eks-nodes-key.pem

# Confirm template parameter set before building params file
aws cloudformation get-template-summary \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2025-11-26/amazon-eks-nodegroup.yaml \
  --query "Parameters[].ParameterKey" \
  --output text | tr '\t' '\n' | sort

# Build parameters file
cat > /tmp/cf-params.json << EOF
[
  {"ParameterKey": "ClusterName",                         "ParameterValue": "$CLUSTER_NAME"},
  {"ParameterKey": "ClusterControlPlaneSecurityGroup",    "ParameterValue": "$CLUSTER_SG"},
  {"ParameterKey": "ApiServerEndpoint",                   "ParameterValue": "$API_SERVER"},
  {"ParameterKey": "CertificateAuthorityData",            "ParameterValue": "$CA_DATA"},
  {"ParameterKey": "ServiceCidr",                         "ParameterValue": "$SERVICE_CIDR"},
  {"ParameterKey": "AuthenticationMode",                  "ParameterValue": "$AUTH_MODE_PARAM"},
  {"ParameterKey": "NodeGroupName",                       "ParameterValue": "${CLUSTER_NAME}-nodes"},
  {"ParameterKey": "NodeInstanceType",                    "ParameterValue": "t3.medium"},
  {"ParameterKey": "NodeImageIdSSMParam",                 "ParameterValue": "/aws/service/eks/optimized-ami/$K8S_VERSION/amazon-linux-2023/x86_64/standard/recommended/image_id"},
  {"ParameterKey": "NodeVolumeSize",                      "ParameterValue": "20"},
  {"ParameterKey": "VpcId",                               "ParameterValue": "$VPC_ID"},
  {"ParameterKey": "Subnets",                             "ParameterValue": "$SUBNET_IDS"},
  {"ParameterKey": "KeyName",                             "ParameterValue": "eks-nodes-key"},
  {"ParameterKey": "NodeAutoScalingGroupMinSize",         "ParameterValue": "1"},
  {"ParameterKey": "NodeAutoScalingGroupMaxSize",         "ParameterValue": "3"},
  {"ParameterKey": "NodeAutoScalingGroupDesiredCapacity", "ParameterValue": "3"}
]
EOF

cat /tmp/cf-params.json   # verify no blank values before proceeding

# Launch stack
aws cloudformation create-stack \
  --stack-name eks-nodes-stack \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2025-11-26/amazon-eks-nodegroup.yaml \
  --parameters file:///tmp/cf-params.json \
  --capabilities CAPABILITY_IAM

# Poll until CREATE_COMPLETE
watch -n 10 "aws cloudformation describe-stacks \
  --stack-name eks-nodes-stack \
  --query 'Stacks[0].StackStatus' --output text"

# Verify nodes joined
kubectl get nodes
```

---

## File Structure

```
terraform/aws/eks-kodekloud/
├── terraform.tf      # Provider versions (aws ~> 6.42, tls ~> 4.0, http ~> 3.0)
├── variables.tf      # All input variables
├── data.tf           # AMI lookup, caller identity, region, operator IP
├── vpc.tf            # terraform-aws-modules/vpc v6.6.1
├── bastion.tf        # terraform-aws-modules/ec2-instance v6.4.0
├── iam-eks.tf        # eksClusterRole + eksNodeRole (SCP-whitelisted names)
├── eks.tf            # Raw aws_eks_cluster + OIDC provider + 3 addons
└── outputs.tf        # Cluster endpoint, bastion IP, SSH command, etc.
```

### Key Files

**`iam-eks.tf`** creates two IAM roles with names the KodeKloud SCP whitelists for
`iam:PassRole`. Any other name fails with `implicitDeny`. These roles must exist before
the cluster or the CloudFormation node stack is created.

**`eks.tf`** uses raw `aws_eks_cluster` (not the module) and sets
`bootstrap_cluster_creator_admin_permissions = true` directly on the resource. This
gives the cluster creator implicit admin access at creation time without triggering
`eks:AssociateAccessPolicy`. All addons have `preserve = true` to prevent
`terraform destroy` from calling `eks:DeleteAddon`.

---

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `dev` | Environment tag applied to all resources |
| `project_name` | `silver-stack` | Prefix for all resource names; determines cluster name |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `availability_zones` | `us-east-1a/b/c` | Three AZs for HA |
| `private_subnet_cidrs` | `10.0.1-3.0/24` | EKS node subnets |
| `public_subnet_cidrs` | `10.0.101-103.0/24` | Bastion + NAT gateway subnets |
| `kubernetes_version` | `1.36` | EKS control plane version |
| `bastion_instance_type` | `t3.micro` | Bastion EC2 size |
| `bastion_key_name` | `microservices-demo-bastion-key` | AWS key pair name |

Override any variable using a `terraform.tfvars` file:

```hcl
project_name       = "my-project"
kubernetes_version = "1.34"
bastion_key_name   = "my-bastion-key"
```

---

## Cleanup

```bash
# Delete the CloudFormation node stack first — VPC deletion fails while
# node security groups are still attached
aws cloudformation delete-stack --stack-name eks-nodes-stack

# Wait for DELETE_COMPLETE
aws cloudformation describe-stacks \
  --stack-name eks-nodes-stack \
  --query "Stacks[0].StackStatus" --output text

# Then destroy Terraform resources
terraform destroy
```

> `terraform destroy` may warn about `eks:DeleteAddon` even with `preserve = true`
> if addons are explicitly removed from config before destroy. Remove them from state
> first if this occurs: `terraform state rm 'aws_eks_addon.vpc_cni'` (and the others).

---

## Troubleshooting

For a complete log of every error encountered during development — including exact error
messages, root causes, and fixes — see:
[eks-on-kodekloud-terraform-challenges.md](../../runbooks/eks-on-kodekloud-terraform-challenges.md)

**kubectl returns Forbidden (403):**
An access entry exists but no policy is associated. This means `bootstrap_cluster_creator_admin_permissions`
was not set correctly at cluster creation time. The cluster must be recreated — this
setting is create-time only and cannot be changed after the fact. Wipe state and reapply.

**kubectl returns "server has asked for credentials" (401):**
Either AWS credentials are not configured on the bastion (`aws configure` not run), or
the access entry was deleted. Run `aws sts get-caller-identity` to confirm credentials
are working, then run `aws eks list-access-entries` to confirm the lab user's entry exists.

**`terraform apply` fails with `EntityAlreadyExists` on IAM roles:**
The previous KodeKloud session left `eksClusterRole` or `eksNodeRole` in place.
Import them: `terraform import aws_iam_role.eks_cluster_role eksClusterRole`

**`terraform plan` references resources from wrong account:**
Stale state from an expired session. Delete state: `rm -f terraform.tfstate terraform.tfstate.backup`

---

## Tested Environment

| Component | Version |
|---|---|
| Terraform | 1.5.7+ |
| AWS Provider | ~> 6.42 |
| EKS | 1.36 |
| Node AMI | AL2023 (via SSM parameter) |
| KodeKloud Playground | AWS (us-east-1) |

---

## Related

- [EKS on KodeKloud via eksctl (manual approach)](../../runbooks/eks-on-kodekloud-aws-playground.md)
- [EKS challenges and fixes](../../runbooks/eks-on-kodekloud-terraform-challenges.md)
- [Deploy AWS Load Balancer Controller](../../runbooks/addons-eks/deploy-aws-load-balancer-controller.md)
- [Install EBS CSI Driver](../../runbooks/addons-eks/install-ebs-csi-driver.md)