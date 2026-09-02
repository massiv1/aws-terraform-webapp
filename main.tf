terraform {
  required_providers {
    aws = { 
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" { 
  region = "eu-central-1"
}

resource "aws_vpc" "main" { 
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public1" { 
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-1"
  }

}


resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true        

  tags = {
    Name = "public-subnet-2"
  }
}


resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-2"
  }
}

resource "aws_subnet" "isolated1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "isolated-subnet-1"
  }
}

resource "aws_subnet" "isolated2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "isolated-subnet-2"
  }
}

resource "aws_internet_gateway" "igw" {     
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_eip" "nat_eip" {         
  domain = "vpc"

  tags = {
    Name = "nat-gw"
  }
}

resource "aws_nat_gateway" "nat_gw" {       
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]  
}

resource "aws_route_table" "publicroute_table" {      

  vpc_id = aws_vpc.main.id

  route{
  cidr_block = "0.0.0.0/0" 
  gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "publicrt1" {        
  subnet_id = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroute_table.id
}

resource "aws_route_table" "privateroute_table" {         
  
  vpc_id = aws_vpc.main.id

  route{
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "prtroute1" {
  subnet_id = aws_subnet.private1.id
  route_table_id = aws_route_table.privateroute_table.id
}

resource "aws_security_group" "alb_sg" {

  vpc_id = aws_vpc.main.id

  ingress {                                                

    description = "HTTP from internet"                                                       
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "alb-security-group"
  }

}

resource "aws_security_group" "ec2_sg" {

  vpc_id = aws_vpc.main.id

  ingress{
    description = "Packets from the ALB"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress{
    description = "Network packets from our SSH bastion host"           
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.bastion_host.id]
  }

  egress{
    description = "Packets to the internet"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "ec2-security-group"
  }
}

resource "aws_security_group" "bastion_host"{

  vpc_id = aws_vpc.main.id

  ingress{
    description = "Network packets from our laptop"        
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["92.21.22.174/32"]
  }

  
  tags = {
    Name = "bastion-host-security-groups"
  }
}

resource "aws_security_group" "database_sg"{                 

  vpc_id = aws_vpc.main.id

  ingress{
    description = "Network packets from our web tier"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  tags = {
    Name = "database-security-groups"
  }
}

resource "aws_security_group_rule" "alb_egress_to_ec2" {          
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "bastion_egress_to_ec2" {
  type                     = "egress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion_host.id
  source_security_group_id = aws_security_group.ec2_sg.id
}

resource "aws_security_group_rule" "ec2_egress_to_db" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.ec2_sg.id
  source_security_group_id = aws_security_group.database_sg.id
}

resource "aws_launch_template" "ec2_initialization" {

image_id = var.ami_id
instance_type = var.instance_type
}






