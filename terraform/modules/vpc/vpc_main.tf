terraform {
    required_providers {
        restapi = { source = "Mastercard/restapi" }
    }
}

resource "restapi_object" "bl_vpc" {
  path = "/vpcs"
  id_attribute = "vpc/id"
  data = <<EOJ
        {
            "name": "${var.vpc_name}",
            "ip_range": "${var.vpc_ip_range}"
        }
    EOJ
}
