provider "aws" {
    region = "ap-southeast-1"
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
variable "entry-script_location" {}

resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "${var.env_prefix}-vpc"
    }
}

resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id
    availability_zone = var.avail_zone
    cidr_block = var.subnet_cidr_block 
    tags = {
        Name = "${var.env_prefix}-subnet-1"
    }
}

output "dev-vpc-id" {
    value = aws_vpc.myapp-vpc.id
}

resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
        Name = "${var.env_prefix}-igw"
    }
}

# Create a new Route Table and associate the route table w/ subnet
# resource "aws_route_table" "myapp-rtb" {
#     vpc_id = aws_vpc.myapp-vpc.id
#     route {
#         cidr_block = "0.0.0.0/0"
#         gateway_id = aws_internet_gateway.myapp-igw.id
#     }
#     tags = {
#         Name = "${var.env_prefix}-main-rtb"
#     }
# }

# resource "aws_route_table_association" "myapp-rtb-a" {
#     subnet_id = aws_subnet.myapp-subnet-1.id
#     route_table_id = aws_route_table.myapp-rtb.id
# }

# Associate the Subnet with the exsiting default Route Table
resource "aws_default_route_table" "myapp-main-rtb" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name = "${var.env_prefix}-main-rtb"
    }
}

# Create a new SG
# resource "aws_security_group" "myapp-sg" {
#     name = "myapp-sg"
#     vpc_id = aws_vpc.myapp-vpc.id
#     ingress {
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         cidr_blocks = [var.my_ip]
#     }
#     ingress {
#         from_port = 8080
#         to_port = 8080
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]
#     }
#     egress {
#         from_port = 0
#         to_port = 0
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#         prefix_list_ids = []
#     }
#     tags = {
#         Name = "${var.env_prefix}-sg"
#     }
# }

resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        # cidr_blocks = [var.my_ip]
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        prefix_list_ids = []
    }
    tags = {
        Name = "${var.env_prefix}-default-sg"
    }
}

data "aws_ami" "latest-amzon-linux-image" {
    owners = ["amazon"]
    most_recent = true
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-*-hvm-*-x86_64-gp2"]
    }
    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

output "aws-ami-id" {
    value = data.aws_ami.latest-amzon-linux-image.id
}

output "public-ip-address" {
    value = aws_instance.myapp-server.public_ip
}

# Reusing the existing key in laptop
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest-amzon-linux-image.id
    instance_type = var.instance_type

    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone
    associate_public_ip_address = true
    # for self generated key pair in AWS portal
    # key_name = "server-key-pair"
    # for reusing the existing key in laptop
    key_name = aws_key_pair.ssh-key.key_name

    user_data = file(var.entry-script_location)

    tags = {
        Name = "${var.env_prefix}-server"
    }
}