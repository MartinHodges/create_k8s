
output "instance_id" {
    description = "ID of the created server"
    value = restapi_object.bl_vps
}

locals {
    v4networks  = jsondecode(restapi_object.bl_vps.api_response).server.networks.v4
    v4_private_ip = local.v4networks[index(local.v4networks.*.type, "private")].ip_address
}

output "v4_ips" {
    description = "IP V4 addresses of VPS"
    value = {
        private = local.v4_private_ip
    }
}
