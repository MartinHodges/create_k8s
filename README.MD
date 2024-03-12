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

Note that the worker nodes must be a min of 4GB and 2 CPUs to allow Istio to be installed.
The master node must have 2 cpus and has been made 4GB to match the workers.

It creates the client configuration for the openVPN service. It also installs the gateway service as an egress point to the Internet for all private servers to allow them to access the repositories they need to update.

## Create the VPC and VPSs

To create the infrastructure, execute these from the project's root folder.

    cd terraform
    terraform init
    terraform plan
    terraform apply

This will create an etc-hosts file that you can append to your /etc/hosts file for convenience.

## Configure the VPC

As Terraform does not allow any resource to be touched multiple times and as the VPC depends on the gw VPS, which depends on the VPC, this step has to be done manually.

Add a static route to the VPC to allow private VPSs to acess the Internet. The route should be defined as:
0.0.0.0/0 -> {eg-gw private ip address} Private VPS Egress

## Configure egress through the gw server

Another manual step involves setting up the interfaces on the gw server.  By default these will use a
single network connection. In the Binary Lane console, go to the gw server and find the VPC advanced
setting. This should allow you to set dedicated interfaces for public network traffic. Select this
option.

Also, as we are using this as an egress point, untick the option to perform Source/Destination checks.

Save and apply these. You will need to save and apply each of the two options separately.

## Setting up known hosts

To allow Ansible to access your servers, you need to add your new servers to the known_hosts file. The
easiest way to do this is to log in using SSH. This also ensures your personal SSH keys were added
correctly. Now use the following with the public IP addresses of the servers (do not your hosts entries
as Ansible uses IP addresses):

    ssh root@{GW PUBLIC IP ADDRESS}
    ssh root@{OPENVPN PUBLIC IP ADDRESS}

Currently you only have public access to these two and so the others will have to wait until you have
the OpenVPN up and running.

## Configure access to the VPC

Once you have created the set of virtual servers, you can now configure them with ansible. This is done in a number of interdependent steps. First is to set up the openVPN and gateway servers, which first need bootstrapping.

    cd ../ansible/bootstrap
    ansible-playbook bootstrap.yml --limit open_vpn,gw

Once bootstrapped, the servers can be setup. First do the openvpn. Part way through this step you will be asked to sign a server request (~/openvpn-server.req on your local computer) with a CA. You will need to provide the signed certificate (openvpn-server.crt) and the CA certificate (ca.crt) in your home folder before continuing.

    cd ../openvpn-server
    ansible-playbook openvpn-server.yml

After starting the openVPN sever, you will need to create a client configuration. Part way through this step you will be asked to sign a client request (~/openvpn-client.req) with a CA. You will need to provide the signed certificate (openvpn-client.crt) in your home folder before continuing.

    cd ../openvpn-client
    ansible-playbook openvpn-client.yml

This produces a client configuration in your home folder on your local machine (openvpn-client.ovpn). Yuo will need to install this into your local VPN client software and connect to the open VPN server. You cannot continue until you do this as you cannot access your private k8s servers.

Each private VPS needs to be able to access the Internet in order to access upgrades and packages. The gateway provides a Network Address Translation (NAT) gateway and nginx proxy. We bootstrapped it earlier so now it just needs to be set up. Note the need to replace { } field with your own custom domain for which you shoud  have a wildcard certificate and CA certificate:

    cd ../gateway
    ansible-playbook gateway.yml --extra-vars "custom_domain={DOMAIN NAME}"

Once you have this up and running and and can SSH into each of the k8s nodes, you can then bootstrap them:

    cd ../bootstrap
    ansible-playbook bootstrap.yml --limit k8s_master,k8s_node,nfs_server

You can now create your nfs server:

    cd ../nfs
    ansible-playbook nfs.yml

Now everything is set up, Kubernetes can now be installed:

    cd ../k8s
    ansible-playbook k8s.yml  --limit k8s_master --extra-vars "custom_domain={DOMAIN NAME}"
    ansible-playbook k8s.yml  --limit k8s_node

With Kubernetes installed, the basic Kubernetes infrastructure can be installed.
The following will install:
- k8s_your_domain - certificates and coreDNS update for custom domain
- k8s_storage - setups a auto-provisioner for your NFS service
- k8s_gateway - installs and configures a APISIX API Gateway
- k8s_test_service - deploys an instance of a simple test service

    cd ../k8s-config
    ansible-playbook k8s-config.yml --extra-var "custom_domain={DOMAIN NAME}"
