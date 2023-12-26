variable "vpc_id" {
    description = "ID of the VPC this server is to be created in"
    type = number
    default = 0
}

variable "vps_name" {
    description = "Name of the VPS server to be created"
    type = string
    default = "my_web_svr"
}

variable "vps_flavour" {
    description = "Flavour of the VPS server defining its dimensions"
    type = string
    default = "small"
}

variable "ssh_key" {
    description = "The SSH key to allow access to the VPS"
    type = string
    default = ""
}
