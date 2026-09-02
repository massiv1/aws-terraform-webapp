variable "instance_type" {
    type = string
    description = "EC2 instance for our compute tier"
    default = "t3.micro"
}

variable "subnet_ids" {
    type = list(string)
    description = "Subnet ID for our compute tier"
}

variable "ami_id" {
    type = string 
    description = "AMI ID for our EC2 instance, region specific"
}

variable "security_group_id" {
    type = string
    description = "firewall id associated with compute tier"
}

variable "key_pair_name" {
    type = string
    description = "name for our keys(private and public) to ssh"
}

variable "user_data" {
    type = string 
    description = "placeholder for our bootstrap script"
}

variable "min_size" {
    type = number
    description = "minimum value for our auto scaling group"
    default = 1
}

variable "max_size" {
    type = number 
    description = "maximum value for our auto scaling group"
    default = 3
}

variable "desired_capacity" {
    type = number
    description = "suggested value for our auto scaling group"
    default = 1
}


