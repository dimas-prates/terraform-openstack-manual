# Terraform commands to execute:
*OBS: the flag **"-var-file"** it's for the stored variables in a file*
* Set the variable **"external_remote_ip"** with your public IP
```bash
/usr/bin/sed -i "s/^external_remote_ip\s*=\s*\"\s*\"/external_remote_ip = \"$(curl -s ifconfig.io | cut -d' ' -f1)\/32\"/" openstack_variables-sample.tfvars
```
* Initiate directory for Terraform:
```bash
terraform init -var-file=openstack_variables.auto.tfvars
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
openstack server ssh -i openstack.key  -l rocky vpn-1
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