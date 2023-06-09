terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

#Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  
}

# Create a VPC
resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TerraformVPC"
  }
}

#Variable for subnets
variable "subnets_cidr" {
	type = list
	default = ["10.0.1.0/24", "10.0.2.0/24"]
  #10.0.1.0/24 will be public , 10.0.2.0/24 will be private
}
#Variable name for the subnets
variable "subnet_names"{
  type = list 
  default = ["Public","Private"]
}


#Create Public Subnet
resource "aws_subnet" "subnet" {
  count = length(var.subnets_cidr)
  vpc_id = aws_vpc.example.id
  cidr_block = element(var.subnets_cidr,count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "TerraformSubnet-${var.subnet_names[count.index]}"
  }
}

#Create Internet Gateways
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.example.id

  tags = {
    Name = "TerraformInternetGateway"
  }
}

#Create public routing table
resource "aws_route_table" "public_routing_table" {
  vpc_id = aws_vpc.example.id
  #Provide connection to Internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id 
  }
  tags = {
    Name = "RouteTerraformPublic"
  }
}
#Create private routing table
resource "aws_route_table" "private_routing_table" {
  vpc_id = aws_vpc.example.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id 
  }
  tags = {
    Name = "RouteTerraformPrivate"
  }
}
# Create public Routing Table Association
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.subnet[0].id # public subnet
  route_table_id = aws_route_table.public_routing_table.id
}

# Create private Routing Table Association
resource "aws_route_table_association" "private" {
  subnet_id = aws_subnet.subnet[1].id # private subnet
  route_table_id = aws_route_table.private_routing_table.id
}
#Create public EC2 Instance
resource "aws_instance" "publicEC2" {
  ami = "ami-0715c1897453cabd1"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnet[0].id
  associate_public_ip_address = true
  security_groups = [aws_security_group.allowssh.id]
  tags = {
    Name = "PublicEC2"
  }
}
#Create private EC2 Instance
resource "aws_instance" "privateEC2" {
  ami = "ami-0715c1897453cabd1"
  instance_type = "t2.micro"
  associate_public_ip_address = false
  subnet_id = aws_subnet.subnet[1].id
  security_groups = [aws_security_group.allowssh.id]
  tags = {
    Name = "PrivateEC2"
  }
}

#Securty Policy to Allow SSH
resource "aws_security_group" "allowssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow_SSH"
  }
}
#EIP for NAT Gateway
resource "aws_eip" "eip1" {
  vpc = true
  tags = {
    Name = "EIP 1"
  }
}
#Create NAT Gateway for private EC2
resource "aws_nat_gateway" "nat-gateway" {
  allocation_id = aws_eip.eip1.id
  subnet_id = aws_subnet.subnet[0].id
  tags = {
    Name = "Public Nat Gateway"
 }
}
