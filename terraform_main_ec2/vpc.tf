resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "igw-name"
  }
}

resource "aws_subnet" "public-subnet-01" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"             # First Subnet
  availability_zone       = "us-east-1a"              # AZ 1
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-01"
  }
}

resource "aws_subnet" "public-subnet-02" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"             # Second Subnet
  availability_zone       = "us-east-1b"              # AZ 2 (Different AZ)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-02"
  }
}


resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public-subnet-01.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public-subnet-02.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "cicd_sg" {
  vpc_id      = aws_vpc.vpc.id
  description = "Allowing Jenkins, SonarQube, SSH, and other tools access"

  ingress = [
    for port in [22, 80, 443, 8080, 8081, 8443, 2375, 2376, 3000, 6443, 9000, 9090] : {
      description      = "Access for various tools"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      ipv6_cidr_blocks = ["::/0"]
      self             = false
      prefix_list_ids  = []
      security_groups  = []
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cicd_sg"
  }
}
