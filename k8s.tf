resource "tls_private_key" "key-k8s" {
  algorithm = "RSA"
  rsa_bits  = 4096
  
}

resource "aws_key_pair" "k8s" {
  key_name   = "k8s-key"
  public_key = tls_private_key.key-k8s.public_key_openssh
}

resource "aws_vpc" "k8s" {
  cidr_block = "10.10.0.0/16"
}

resource "aws_subnet" "k8s" {
  vpc_id     = aws_vpc.k8s.id
  cidr_block = "10.10.1.0/24"
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s.id
  tags = {
    Name = "k8s-igw"
  }
}

resource "aws_route_table" "k8s_rt" {
  vpc_id = aws_vpc.k8s.id
  tags = {
    Name = "k8s-route-table"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.k8s_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.k8s_igw.id
}

resource "aws_route_table_association" "k8s_subnet_assoc" {
  subnet_id      = aws_subnet.k8s.id
  route_table_id = aws_route_table.k8s_rt.id
}


resource "aws_security_group" "k8s" {
  vpc_id = aws_vpc.k8s.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "10.244.0.0/16"]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "master_ssm_role" {
  name = "k8s-master-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

resource "aws_iam_role_policy" "master_ssm_policy" {
  name   = "k8s-master-ssm-policy"
  role   = aws_iam_role.master_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:PutParameter"]
      Resource = ["arn:aws:ssm:ap-south-1:${data.aws_caller_identity.current.account_id}:parameter/k8s/join-command"]
    }]
  })
}

resource "aws_iam_role" "worker_ssm_role" {
  name = "k8s-worker-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

resource "aws_iam_role_policy" "worker_ssm_policy" {
  name   = "k8s-worker-ssm-policy"
  role   = aws_iam_role.worker_ssm_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["ssm:GetParameter"]
      Resource = ["arn:aws:ssm:ap-south-1:${data.aws_caller_identity.current.account_id}:parameter/k8s/join-command"]
    }]
  })
}

resource "aws_iam_instance_profile" "master_ssm_profile" {
  name = "k8s-master-ssm-profile"
  role = aws_iam_role.master_ssm_role.name
  
}

resource "aws_iam_instance_profile" "worker_ssm_profile" {
  name = "k8s-worker-ssm-profile"
  role = aws_iam_role.worker_ssm_role.name
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_s3_bucket" "metric_bucket" {
  bucket = "my-metric-bucket"  # replace with a unique bucket name
  force_destroy = true  
}

# Upload the component.yaml file to the bucket
resource "aws_s3_object" "component_yaml" {
  bucket       = aws_s3_bucket.metric_bucket.bucket
  key          = "component.yaml"
  source       = "./component.yaml"
  content_type = "text/yaml"
  etag         = filemd5("component.yaml")
}

resource "aws_s3_object" "groovy_file" {
  bucket       = aws_s3_bucket.metric_bucket.bucket
  key          = "basic-security.groovy"
  source       = "./basic-security.groovy"
  content_type = "application/x-groovy"
  etag         = filemd5("basic-security.groovy")
}

# New S3 read policy resource
resource "aws_iam_policy" "s3_read_policy" {
  name = "k8s-master-s3-read-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::my-metric-bucket",       # replace with your bucket ARN
          "arn:aws:s3:::my-metric-bucket/*"     # replace with your bucket ARN + /*
        ]
      }
    ]
  })
}

# Attach the newly created S3 policy to the existing role
resource "aws_iam_role_policy_attachment" "attach_s3_read_policy_to_master_ssm_role" {
  role       = aws_iam_role.master_ssm_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.k8s.id
  key_name      = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s.id]
  tags = { Name = "k8s-master" }
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.master_ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x
    apt-get update
    apt-get install -y docker.io apt-transport-https curl awscli

    # If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update && apt-get install -y kubelet kubeadm kubectl

    kubeadm init --pod-network-cidr=10.244.0.0/16

    mkdir -p /root/.kube
    cp /etc/kubernetes/admin.conf /root/.kube/config
    export KUBECONFIG=/root/.kube/config
    until kubectl get nodes; do echo "not started"; done
    kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
    JOIN_COMMAND=$(kubeadm token create --print-join-command)
    aws ssm put-parameter --name /k8s/join-command --value "$JOIN_COMMAND" --type String --overwrite --region ap-south-1
    # Wait for all nodes to be Ready
    while [ $(kubectl get nodes --no-headers | grep -c ' NotReady ') -ne 0 ]; do
      echo "Waiting for all nodes to be Ready..."
      sleep 5
    done
    # Download the component.yaml from S3
    aws s3 cp s3://my-metric-bucket/component.yaml /home/ubuntu/component.yaml
    # Apply the component.yaml to the cluster
    kubectl apply -f /home/ubuntu/component.yaml
  EOF

}

resource "aws_instance" "worker" {
  count         = 4
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.k8s.id
  key_name      = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s.id]
  tags = { Name = "k8s-worker-${count.index + 1}" }
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.worker_ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x
    
    apt-get update
    apt-get install -y docker.io apt-transport-https curl awscli

    # Use new Kubernetes repo and keyring per pkgs.k8s.io
    # If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    apt-get update && apt-get install -y kubelet kubeadm kubectl
    master_ip=${aws_instance.master.private_ip}

    for i in {1..10}; do
        JOIN_COMMAND=$(aws ssm get-parameter --name /k8s/join-command --query Parameter.Value --output text --region ap-south-1)
        if [[ $JOIN_COMMAND == *"\\$master_ip"* ]]; then
            break
        fi
        echo "Waiting for correct join command..."
        sleep 5
    done
    $JOIN_COMMAND
    # You must manually SSH and run 'kubeadm join ...' here after cluster is ready
  EOF
}

resource "aws_instance" "my_jenkins" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  subnet_id     = aws_subnet.k8s.id
  key_name      = aws_key_pair.k8s.key_name
  vpc_security_group_ids = [aws_security_group.k8s.id]
  tags = { Name = "my-jenkins" }
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.master_ssm_profile.name

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -x
    apt-get update
    apt-get install -y docker.io curl awscli
    systemctl start docker
    systemctl enable docker
    mkdir -p /home/ubuntu/jenkins_init_scripts
    aws s3 cp s3://my-metric-bucket/basic-security.groovy /home/ubuntu/jenkins_init_scripts/basic-security.groovy
    chown -R ubuntu:ubuntu /home/ubuntu/jenkins_init_scripts
    cd /home/ubuntu
    # Run Jenkins container with mounted init scripts
    docker run -d -p 8080:8080 -p 50000:50000 \
      --name jenkins \
      -e JAVA_OPTS="-Djenkins.install.runSetupWizard=true" \
      -v jenkins_home:/var/jenkins_home \
      jenkins/jenkins:lts

  EOF
  
}

output "master_public_ip" {
  value = aws_instance.master.public_ip
}

output "workers_public_ips" {
  value = [for w in aws_instance.worker : w.public_ip]
}

output "k8s_private_key" {
  value     = tls_private_key.key-k8s.private_key_pem
  sensitive = true
}