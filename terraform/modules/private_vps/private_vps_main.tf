
terraform {
    required_providers {
        restapi = { source = "Mastercard/restapi" }
    }
}

resource "restapi_object" "bl_vps" {
  path = "/servers"
  id_attribute = "server/id"
  force_new = ["vps_flavour"]
  data = <<EOJ
        {
            "name": "${var.vps_name}",
            "backups": true,
            "ipv6": false,
            "size": "${var.vps_flavour}",
            "image": "ubuntu-20.04.6",
            "region": "syd",
            "vpc_id": "${var.vpc_id}",
            "options": {
                "ipv4_addresses": 0
            }
        }
    EOJ
}
