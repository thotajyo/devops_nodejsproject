resource "aws_instance" "ec2" {
  ami                    = "ami-0ae8f15ae66fe8cda"
  instance_type          = "t2.large"
  key_name               = "devops-key"
  subnet_id              = aws_subnet.public-subnet-01.id
  vpc_security_group_ids = [aws_security_group.cicd_sg.id]
  ## Attach IAM role to the EC2 instance 
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  root_block_device {
    volume_size = 8
  }
  user_data = templatefile("./install-tools.sh", {})

  tags = {
    Name = "Eks_instance"
  }
}
