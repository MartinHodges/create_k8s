# Creating Kubernetes cluster on Binary Lane

This repo is designed for use with my [Medium article](https://medium.com/@martin.hodges/creating-a-kubernetes-cluster-from-scratch-in-1-hour-using-automation-a25e387be547) on how to build a Kubernetes (k8s) cluster on the Australian [Binary Lane](binarylane.com.au) cloud services.

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

## Secret Dependencies

If you are creating the k8s_keycloak role, you need to supply the postgres and keycloak user passwords
for the database. These must be suppplied as an Ansible vault file.  Create the file (the file extension should be .enc as this will prevent it being stored in the git repository):

    postgres_pw: {your postgres user database password}
    keycloak_pw: {your keycloak user database password}
    client_secret: {"" or the Keycloak client secret for the apisix API Gateway}
    custom_domain: {the domain you are going to use with your cluster}

Then encrypt this file with:

    ansible-vault encrypt {filename}

Supply a secure password and rememebr it for later use.

## Create the VPC and VPSs

To create the infrastructure, execute these from the project's root folder.

    cd terraform
    terraform init
    terraform plan
    terraform apply

This will create an etc-hosts file that you can cut and paste into your /etc/hosts file for convenience.

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

This produces a client configuration in your home folder on your local machine (openvpn-client.ovpn). You will need to install this into your local VPN client software and connect to the open VPN server. You cannot continue until you do this as you cannot access your private k8s servers.

Each private VPS needs to be able to access the Internet in order to access upgrades and packages. The gateway provides a Network Address Translation (NAT) gateway and nginx proxy. We bootstrapped it earlier so now it just needs to be set up. Note the need to replace { } field with your own custom domain for which you shoud have a wildcard certificate and CA certificate. Note that this config assumes you will install the APISIX API gateway and that apisix.{DOMAIN NAME} and iam.{DOMAIN NAME} are proxied through to the gateway:

    cd ../gateway
    ansible-playbook gateway.yml --extra-vars "custom_domain={DOMAIN NAME}"

Once you have this up and running and and can SSH into each of the k8s nodes, you can then bootstrap them:

    cd ../bootstrap
    ansible-playbook bootstrap.yml --limit k8s_master,k8s_node,nfs_server

You can now create your nfs and minIO servers. This playbook expects to find a signed certificate and
an associated key file in your ansible host machine to secure the TLS connections. These are expected
to be called ~/{DOMAIN NAME}.crt and ~/{DOMAIN NAME}.key.

    cd ../nfs
    ansible-playbook nfs.yml --extra-vars "custom_domain={DOMAIN NAME}"

Note that this playbook creates a random, initial admin password for minIO which can be found in 
/etc/default/minio. You should change this password through the user interface after it is successfully
installed.

Now everything is set up, Kubernetes can now be installed:

    cd ../k8s
    ansible-playbook k8s.yml  --limit k8s_master --extra-vars "custom_domain={DOMAIN NAME}"
    ansible-playbook k8s.yml  --limit k8s_node

With Kubernetes installed, the basic Kubernetes infrastructure can be installed.
The following will install:
- k8s_service_mesh (istio)
- k8s_your_domain - certificates and coreDNS update for custom domain
- k8s_storage - setups a auto-provisioner for your NFS service (nfs-subdir-external-provisioner)
- k8s_gateway - installs and configures an API Gateway (APISIX)
- k8s_test_service - deploys an instance of a simple test service (nginx)
- k8s_vault - deploys Hashicorp Vault instance - 2 nodes
- k8s_postgres - installs a postgres operator
- k8s_keycloak - deploys the Keycloak IAM backed by postgres

These commands will run the playbook. It will prompt you for the unlock password you defined at the start:

    cd ../k8s-config
    ansible-playbook k8s-config.yml -e @{your encoded password file} --ask-vault-pass

Note that vault will need to be initialised and unsealed. This requires a set of manual commands.
The commands you require are shown below. They need to be executed on teh k8s-master node:

    kubectl exec -it vault-0 -n vault -- sh
    vault status
    vault operator init -n 1 -t 1
    vault operator unseal {unseal key from previous command}
    exit
    kubectl exec -it vault-1 -n vault -- sh
    vault status
    vault operator raft join http://vault-active:8200
    vault operator unseal {unseal key from earlier command}
    exit

Note that the -n 1 -t 1 creates a shamir key with 1 key and only needing 1 key to unseal.
You may wish to use larger numbers, eg: -n 5 -t 3.

After running the playbook, you should have access to Keycloak. After setting up a realm
called apisix and adding a client, you should have a secret for the client. Add this into your 
ansible secret file and then run the playbook again.

With everything set up, you should be able to access the following user interfaces:

    APISIX      ... http://k8s.{CUSTOM_DOMAIN}:30190
    Grafana     ... http://k8s.{CUSTOM_DOMAIN}:31300
    Keycloak    ... http://iam.{CUSTOM_DOMAIN}
    Hello World ... https://apisix.{CUSTOM_DOMAIN}/worlds (unsecured)
    Hello World ... https://secure.{CUSTOM_DOMAIN}/worlds (secured)
    MinIO       ... https://nfs.{CUSTOM_DOMAIN}:9001/browser
    Vault       ... http://k8s.{CUSTOM_DOMAIN}:30802
