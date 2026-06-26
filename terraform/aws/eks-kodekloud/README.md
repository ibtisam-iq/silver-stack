# EKS on KodeKloud AWS Playground (Terraform)

**Purpose:** This configuration provisions a production-pattern Amazon EKS cluster on the **KodeKloud AWS Playground** lab environment. 

Because the KodeKloud lab enforces strict AWS Organizations SCP (Service Control Policies), standard deployment methods like the EKS Terraform module, `eksctl`, and managed node groups silently fail. This Terraform configuration provides the verified workarounds required to build the cluster infrastructure within those constraints.

## 📖 Deployment Instructions & Runbook

The complete step-by-step guide on how to deploy and configure this cluster—including handling SCP restrictions, setting up the Bastion host, and attaching self-managed worker nodes via CloudFormation—is fully documented in my companion runbook. 

To avoid redundancy and maintain a single source of truth, **all deployment steps and scripts are kept in the runbook:**

👉 **[EKS on KodeKloud (Terraform) Runbook](https://runbook.ibtisam-iq.com/iac/terraform/provisioning/eks-on-kodekloud-terraform/)**

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
| Worker nodes | **Not provisioned by Terraform** — deployed via CloudFormation (see runbook) |

## Related Documentation

- [EKS challenges and fixes log](https://runbook.ibtisam-iq.com/iac/terraform/provisioning/eks-on-kodekloud-terraform-challenges/)
- [EKS on KodeKloud via eksctl (alternative manual approach)](https://runbook.ibtisam-iq.com/iac/terraform/provisioning/eks-on-kodekloud-eksctl/)
- [Deploy AWS Load Balancer Controller](https://runbook.ibtisam-iq.com/bootstrap/kubernetes/addons-eks/deploy-aws-load-balancer-controller/)
- [Install EBS CSI Driver](https://runbook.ibtisam-iq.com/bootstrap/kubernetes/addons-eks/install-ebs-csi-driver/)
