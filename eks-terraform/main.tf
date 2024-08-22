provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "master" {
  name = "jyothi-eks-master"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.master.name
}

resource "aws_iam_role" "worker" {
  name = "jyothi-eks-worker"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ec2.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "worker" {
  depends_on = [aws_iam_role.worker]
  name       = "jyothi-eks-worker-profile"
  role       = aws_iam_role.worker.name
}

# Re-add autoscaler policy if required
resource "aws_iam_policy" "autoscaler" {
  name = "jyothi-eks-autoscaler-policy"
  path = "/"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeTags",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "autoscaler" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.autoscaler.arn
}

# Attach necessary policies to the worker node role
resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker.name
}

 # data source 
 data "aws_vpc" "main" {
  tags = {
    Name = "Jumphost-vpc"  # Specify the name of your existing VPC
  }
}

data "aws_subnet" "public-subnet-01" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet-02"]
  }
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_subnet" "public-subnet-02" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet-02"]
  }
  vpc_id = data.aws_vpc.vpc.id
}

data "aws_security_group" "cicd_sg" {
  vpc_id = data.aws_vpc.vpc.id
  filter {
    
      name = "tag:Name"
      values = ["cicd_sg"]
    }
  }

resource "aws_eks_cluster" "eks" {
  name     = "project-eks"
  role_arn = aws_iam_role.master.arn

  vpc_config {
    subnet_ids = [
      data.aws_subnet.public-subnet-01.id,
      data.aws_subnet.public-subnet-02.id
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController
  ]
}


resource "aws_eks_node_group" "node-grp" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "dev-node-group"
  node_role_arn   = aws_iam_role.worker.arn
  subnet_ids      = [
    data.aws_subnet.public-subnet-01.id,
    data.aws_subnet.public-subnet-02.id
  ]
  instance_types  = ["t2.small"]
  disk_size       = 20
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  remote_access {
    ec2_ssh_key               = "devops-key"
    source_security_group_ids = [data.aws_security_group.cicd_sg.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly
  ]
}



