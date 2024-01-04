# Creating Kubernetes cluster on Binary Lane

This repo is designed for use with my [Medium article]() on how to build a Kubernetes (k8s) cluster on the Australian [Binary Lane](binarylane.com.au) cloud services.

It is designed as a way to explore Infrastructure as Code as well as Kubernetes clusters using tools such as Terraform, Ansible and OpenVPN.

It creates:
- A Virtual Private Cloud (VPC)
- An openVPN server to access the VPC
- A gateway server as an ingress point
- 1 k8s master node
- 2 k8s worker nodes
- 1 nfs server

It creates the client configuration for the openVPN service. It also installs the gateway service as an egress point to the Internet for all private servers to allow them to access the repositories they need to update.

## Create the VPC and VPSs

To create the infrastructure, execute these from the project's root folder.

    cd terraform
    terraform init
    terraform plan
    terraform apply

## Configure the VPC

As Terraform does not allow any resource to be touched multiple times and as the VPC depends on the gw VPS, which depends on the VPC, this step has to be done manually.

Add a static route to the VPC to allow private VPSs to acess the Internet. The route should be defined as:
0.0.0.0/0 -> <eg-gw private ip address> Private VPS Egress

## Configure access to the VPC

Once you have created the set of virtual servers, you can now configure them with ansible. This is done in a number of interdependent steps. First is to set up the openVPN and gateway server, which first needs bootstrapping.

    cd ../ansible/bootstrap
    ansible-playbook bootstrap.yml --limit open_vpn,gw

Once bootstrapped, the servers can be setup. First do the openvpn. Part way through this step you will be asked to sign a server request (~/openvpn-server.req on your local computer) with a CA. You will need to provide the signed certificate (openvpn-server.crt) and the CA certificate (ca.crt) in your home folder before continuing.

    cd ../openvpn-server
    ansible-playbook openvpn-server.yml

After starting the openVPN sever, you will need to create a client configuration. Part way through this step you will be asked to sign a client request (~/openvpn-client.req) with a CA. You will need to provide the signed certificate (openvpn-client.crt) in your home folder before continuing.

    cd ../openvpn-client
    ansible-playbook openvpn-client.yml

This produces a client configuration in your home folder on your local machine (openvpn-client.ovpn). Yuo will need to install this into your local VPN client software and connect to the open VPN server. You cannot continue until you do this as you cannot access your private k8s servers.

Each private VPS needs to be able to access the Internet in order to access upgrades and packages. The gateway provides a Network Address Translation (NAT) gateway and nginx proxy. We bootstrapped it earlier so now it just needs to be set up:

    cd ../gateway
    ansible-playbook gateway.yml

Once you have this up and running and and can SSH into each of the k8s nodes, you can then bootstrap them:

    cd ../bootstrap
    ansible-playbook bootstrap.yml --limit k8s_master,k8s_node,nfs_server

You can now create your nfs server:

    cd ../nfs
    ansible-playbook nfs.yml

Now everything is set up, Kubernetes can now be installed:

    cd ../k8s
    ansible-playbook k8s.yml  --limit k8s_master
    ansible-playbook k8s.yml  --limit k8s_node