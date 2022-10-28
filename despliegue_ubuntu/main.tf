provider "aws" {
  region     = "eu-west-3"
  # access_key = ""
  # secret_key = ""
}

variable "machine_name" {
  type    = string
  default = "aramirez-rhel8-1"
}

variable "ssh_key_path" {}

resource "aws_key_pair" "developer" {
  key_name   = "deployer-key-terraform-script"
  public_key = file(var.ssh_key_path)
}

variable "availability_zone" {}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  name                 = "vpc-main-v2"
  cidr                 = "10.0.0.0/16"
  azs                  = [var.availability_zone]
  private_subnets      = ["10.0.0.0/24", "10.0.1.0/24"]
  public_subnets       = ["10.0.100.0/24", "10.0.101.0/24"]
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_nat_gateway   = false
  enable_vpn_gateway   = false
  tags                 = { Terraform = "true", Environment = "dev" }
}

data "aws_ami" "rhel_8_5" {
  most_recent = true
  owners      = ["309956199498"] // Red Hat's Account ID
  filter {
    name   = "name"
    values = ["RHEL-8.5*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id
  # ingress
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"
  vpc_id      = module.vpc.vpc_id
  # ingress
  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_http"
  }
}

resource "aws_security_group" "allow_https" {
  name        = "allow_https"
  description = "Allow https inbound traffic"
  vpc_id      = module.vpc.vpc_id
  # ingress
  ingress {
    description = "https from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_https"
  }
}

resource "aws_ebs_volume" "web" {
  availability_zone = var.availability_zone
  size              = 4
  type              = "gp2"
  encrypted         = true
  # iops = 100
  tags = {
    Name = "web-ebs-partition"
  }
}

data "template_file" "userdata" {
  template = file("${path.module}/userdata.sh")
}

resource "aws_instance" "web" {
  # ami a instalar
  ami = data.aws_ami.rhel_8_5.id
  # tipo de instancia
  instance_type = "t2.micro"
  # clave ssh asociada por defecto
  key_name = aws_key_pair.developer.key_name
  # zona de disponibilidad
  availability_zone = var.availability_zone
  user_data         = data.template_file.userdata.rendered
  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.allow_http.id,
    aws_security_group.allow_https.id
  ]
  subnet_id = element(module.vpc.public_subnets, 1)
  tags = {
    # Name = "aramirez-rhel8"
    Name = var.machine_name
  }
}

resource "aws_volume_attachment" "web" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.web.id
  instance_id = aws_instance.web.id
}

resource "aws_eip" "eip" {
  instance = aws_instance.web.id
  vpc      = true
  tags = {
    Name = "web-epi"
  }
}

output "aws_key_pair-developer-key_pair_id" {
  value = aws_key_pair.developer.key_pair_id
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

# output "vpc_public_subnets" {
#   value = module.vpc.public_subnets
# }

output "vmachine_public_ip" {
  value = aws_instance.web.public_ip
}
