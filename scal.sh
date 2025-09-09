#!/bin/bash
mkdir -p /c/130/.github/workflows

# provider.tf
cat <<EOF > /c/130/provider.tf
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret
}
EOF

# variables.tf
cat <<EOF > /c/130/variables.tf
variable "subscription_id" {}
variable "tenant_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "location" {
  default = "East US 2"
}
variable "vm_count" {
  default = 6
}
variable "admin_username" {
  default = "azureuser"
}
variable "admin_password" {
  default = "0091Matrimonio..."
}
EOF

# terraform.tfvars (excluded from Git)
cat <<EOF > /c/130/terraform.tfvars
# Values injected via GitHub Actions at runtime
EOF

# main.tf
cat <<EOF > /c/130/main.tf
resource "azurerm_resource_group" "rg" {
  name     = "rg-130"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-130"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-130"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "nic-\${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  count               = var.vm_count
  name                = "winvm-\${count.index}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "Windows-10"
    sku       = "win10-22h2-pro"
    version   = "latest"
  }
}
EOF

# outputs.tf
cat <<EOF > /c/130/outputs.tf
output "vm_names" {
  value = [for vm in azurerm_windows_virtual_machine.vm : vm.name]
}
EOF

# .gitignore
cat <<EOF > /c/130/.gitignore
terraform.tfvars
infra.plan
terraform.tfstate
terraform.tfstate.*
.terraform/
EOF

# GitHub Actions workflow
cat <<EOF > /c/130/.github/workflows/terraform.yml
name: Terraform CI

on:
  push:
    branches:
      - main

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      ARM_SUBSCRIPTION_ID: \${{ secrets.ARM_SUBSCRIPTION_ID }}
      ARM_TENANT_ID: \${{ secrets.ARM_TENANT_ID }}
      ARM_CLIENT_ID: \${{ secrets.ARM_CLIENT_ID }}
      ARM_CLIENT_SECRET: \${{ secrets.ARM_CLIENT_SECRET }}

    steps:
    - name: Checkout
      uses: actions/checkout@v3

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2

    - name: Inject tfvars from secrets
      run: |
        echo 'subscription_id = "\${{ secrets.ARM_SUBSCRIPTION_ID }}"' > terraform.tfvars
        echo 'tenant_id       = "\${{ secrets.ARM_TENANT_ID }}"' >> terraform.tfvars
        echo 'client_id       = "\${{ secrets.ARM_CLIENT_ID }}"' >> terraform.tfvars
        echo 'client_secret   = "\${{ secrets.ARM_CLIENT_SECRET }}"' >> terraform.tfvars

    - name: Terraform Init
      run: terraform init

    - name: Terraform Plan
      run: terraform plan -out=infra.plan

    - name: Terraform Apply
      run: terraform apply -auto-approve infra.plan
EOF
