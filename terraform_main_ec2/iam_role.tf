# Define the IAM role
resource "aws_iam_role" "ec2_role" {
  name = "MyEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Example IAM Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"  # Change this to your desired policy ARN
}

# Create an IAM Instance Profile for the EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "MyEC2InstanceProfile"
  role = aws_iam_role.ec2_role.name  # This should be the IAM role's name
}

