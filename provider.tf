terraform {
    required_providers {
        aws = {
        source  = "hashicorp/aws"
        version = "~> 4.0"
        }
    }
}

provider "aws" {
    region = "ap-south-1"
}

resource "tls_private_key" "mykey" {
    algorithm = "RSA"
    rsa_bits  = 4096
}
resource "aws_key_pair" "deployer" {
    key_name   = "deployer-key"
    public_key = tls_private_key.mykey.public_key_openssh
}

resource "aws_instance" "newinstance" {
    ami           = "ami-02d26659fd82cf299"
    instance_type = "t2.micro"
    key_name      = aws_key_pair.deployer.key_name
    user_data = <<-EOF
                #!/bin/bash
                exec > /var/log/user-data.log 2>&1
                echo "Starting user_data script"
                cd /home/ubuntu || exit 1
                echo "Hello, World!" > index.html
                sudo nohup python3 -m http.server 80 --directory /home/ubuntu > /dev/null 2>&1 &
                echo "HTTP server started"
    EOF
    tags = {
        Name = "MyFirstInstance"
    }
  
}

output "private_key" {
    value = tls_private_key.mykey.private_key_pem
    sensitive = true
}