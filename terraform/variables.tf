variable "binarylane_email" {
  description = "Email Address/User used to login to the BinaryLane api."
  type = string
  default = "default email"
}

variable "binarylane_api_key" {
  description = "API key used to login/verify for APIs used at binarylane."
  type = string
  default = "default key"
}

variable "ssh_key" {
  description = "The PUBLIC SSH key you want to use to access your VPSs."
  type = string
  default = "default key"
}

variable "project_prefix" {
  description = "The prefix you want to give to your resources."
  type = string
  default = "eg"
}

variable "custom_domain" {
  description = "The custom domain you will be using."
  type = string
  default = "my_domain.own"
}
