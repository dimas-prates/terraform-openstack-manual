# Terraform for OpenStack

## Request resumed:
- 3 VMs for controller instances
- 2 VMs for compute instances
- 2 VMs for storage instances
- 1 VM for access, in this case, VPN instance
- One keypair to acess all VMs
- One floating IP for VPN instance
- Two security groups, for SSH access (TCP 22) and VPN connection (UDP 1194)
- One Object Storage
- Storage intances needs one additional blank volume (each one)
- Two netowrks, internal and external, for the VPN instance, controller instances and compute instances
- One IP reserved in internal network
- Two networks, main and replica, for the storage intances
- One router for all networks
- Compute instances and VPN instance needs access to the Storage's main network
- Controller instances needs access to the Storage's main network and replica network

## Terraform commands to execute:
*OBS: the flag **"-var-file"** it's for the stored variables in a file*
* Set the variable **"external_remote_ip"** with your public IP
```bash
/usr/bin/sed -i "s/external_remote_ip\s*=.*/external_remote_ip = \"$(curl -s ifconfig.io)\/32\"/" openstack_variables-sample.tfvars && terraform fmt
```
* Initiate directory for Terraform:
```bash
terraform init -var-file=openstack_variables.auto.tfvars
```
* Format/Linting 
```bash
terraform fmt
```
* Validate configurations files (*.tf) in the current directory:
```bash
terraform validate
```
* Plan the code to execute:
```bash
terraform plan -var-file=openstack_variables.auto.tfvars
```
* Execute the code:
```bash
terraform apply -auto-approve -var-file=openstack_variables.auto.tfvars
```
* Undo everything you did in the command "apply"
```bash
terraform destroy -auto-approve -var-file=openstack_variables.auto.tfvars
```

## Openstack Command line
- Loading credentials/Exporting to the terminal environment
```bash
source ./app-cred-cli-project-name-terraform-openrc.sh
```
- Add new public IP to security group to allow ssh access
```bash
openstack security group rule create openstack-security-group-access --ingress --protocol tcp --dst-port 22 --remote-ip $(curl -s ifconfig.io)
```
- Login/SSH
```bash
openstack server ssh -i openstack.key -l rocky <vm-name>
```

- Attaching floating IP
```bash
openstack floating ip list
openstack server add floating ip <server-name-or-id> <floating-ip>
```
## Structure
```bash
$ tree
.
├── ansible.key
├── ansible.key.pub
├── app-cred-cli-project-name-terraform-openrc.sh
├── cloud-config.yaml
├── LICENSE
├── main.tf
├── openstack.key
├── openstack.key.pub
├── openstack_variables.auto.tfvars
├── openstack_variables-sample.tfvars
├── README.md
├── terraform.tfstate
└── terraform.tfstate.backup
```
