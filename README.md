# Commands to execute:
*OBS: the flag **"-var-file"** it's for the stored variables in a file*
* Initiate directory for Terraform:
```bash
terraform init -var-file=openstack_variables.tfvars
```
* Validate configurations files (*.tf) in the current directory:
```bash
terraform validate
```
* Plan the code to execute:
```bash
terraform plan -var-file=openstack_variables.tfvars
```
* Execute the code:
```bash
terraform apply -auto-approve -var-file=openstack_variables.tfvars
```
* Undo everything you did in the command "apply"
```bash
terraform destroy -auto-approve -var-file=openstack_variables.tfvars
```
## Structure
```bash
tree -l
```
```bash
├── ansible.key
├── ansible.key.pub
├── app-cred-cli-projectname-terraform-openrc.sh
├── cloud-config.yaml
├── LICENSE
├── openstack.key
├── openstack.key.pub
├── openstack-manual.tf
├── openstack_variables-sample.tfvars
├── openstack_variables.tfvars
├── README.md
└── terraform.tfstate
```