variable "amazon_linux_ami" {
  default = "ami-0fef201115eefe936"
}

resource "aws_instance" "app" {
  ami                    = var.amazon_linux_ami
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.app.id]

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  tags = {
    Name = "devops-app-server"
  }
}