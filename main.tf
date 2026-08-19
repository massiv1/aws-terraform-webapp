terraform {
  required_providers {
    aws = { /* this segment of our code emphasizes the pluggins that would be useful for terraform 
                                                to understand our code so it can be translated back to AWS resources */
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" { /* this segment would be useful to indicate what region of deployment for our web application */
  region = "eu-central-1"
}

resource "aws_vpc" "main" { /* this segment would be useful for our initial vpc configuration
                                            it would be allocated with the subnet of /16*/
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public1" { /*this segment is our initial configuration of our public subnets with a cidr_block of /24 which fits within
                                            the capacity of our vpc cloud space, we also assigned an automated IP address assigner which is useful for inbound data
                                            for the outside world to communicate with our public server. (public ip address mapping is only for public subnets) */
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

resource "aws_internet_gateway" "igw" {     /*this segment of our code emphasizes our internet gateway creation this is the front-door of our vpc to be able 
                                             to connect to the internet with the aide of routing tables */
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "internet-gateway"
  }
}

resource "aws_eip" "nat_eip" {          /*our elastic ip address is used for the temporary conversion of our private ip address to this ip address assigned
                                            by aws which is used to connect our private subent to the internet via the nat gateway. */
  domain = "vpc"

  tags = {
    Name = "nat-gw"
  }
}

resource "aws_nat_gateway" "nat_gw" {       /*assignment of our nat gateway onto our public subnet that takes up the elastic ip address which our private
                                                subnet will convert to */
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "nat-gateway"
  }

  depends_on = [aws_internet_gateway.igw]  /* install the igw, before the eip and lastly the nat gateway */
}

resource "aws_route_table" "publicroute_table" {      /*traffic egress, configuring routing tables for network packets to be sent back 
                                                      to users via an internet gateway regular users everywhere/anywhere this is illustrated
                                                      by the cidr block 0.0.0.0/0 */

  vpc_id = aws_vpc.main.id

  route{
  cidr_block = "0.0.0.0/0" 
  gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "publicrt1" {        /* tie the subnet to the route table association so that we understand the scope the routing
                                                                table applies to */
  subnet_id = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroute_table.id
}

resource "aws_route_table" "privateroute_table" {         /* initiating a routing table for our private subnet where we configure 
                                                            the route in such a way that it communicates with the internet via the 
                                                            NAT gateway (for the sake of downloads, patches etc) */
  
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

  ingress {                                                 /*as for initiating the inbound rules for we need to specify the 
                                                            start to end port for web traffic the start and end port are identical,
                                                            we also need to specify the protocol and lastly the cidr_blocks which 
                                                            references where the data is incoming from into our alb */

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
    description = "Network packets from our SSH bastion host"           /* when configuring our network packets incoming from our basation host to securely login to
                                                                          our ec2 platforms we use port 22 which is used for secure shell solely */
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
    description = "Network packets from our laptop"         /* indicate where the traffic is coming from the identifier would be our laptop's IP address */
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






