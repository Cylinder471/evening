terraform {
  required_version = ">= 1.11.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.94"
    }
  }

  backend "s3" {
    bucket = "cylinder-terraform-remote-state"
    key    = "dev/task2/terrafor.tfstate"
    region = "us-east-1"
    profile = "devops"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "devops"
}
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token

}
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      instance_types = ["m5.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 2
      subnet_ids     = module.vpc.private_subnets
    }
  }

  # добавляем пользователей с правами доступа
  access_entries = {
    "Pavel" = {
      principal_arn     = "arn:aws:iam::650251696415:user/Pavel"
      kubernetes_groups = []
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Name        = "eks-cluster"
    Terraform   = "true"
    Environment = "dev"
  }
}
data "aws_eks_cluster_auth" "eks" {
  name = module.eks.cluster_name
}