variable "vpc_name" {
    description = "Name of the VPC to be created"
    type = string
    default = "my_vpc"
}

variable "vpc_ip_range" {
    description = "Subnet definition for the VPC"
    type = string
    default = "10.240.0.0/16"
}
