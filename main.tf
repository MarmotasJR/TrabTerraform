# DELIMITANDO A VERSÃO DO TERRAFORM + A VERSÃO E O RECURSO DA NUVEM
# MATHEUS - 04/04/2022
terraform {

    required_version = ">= 0.13"

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = ">= 2.26"
        }
    }

}

provider "azurerm" {

    features {}

}

# CRIANDO O RESOURCE GROUP 
# MATHEUS - 04/04/2022
resource "azurerm_resource_group" "rg-trab-terra" {
  name     = "trab_infra_terra"
  location = "brazilsouth"
}

# CRIANDO A VIRTUAL NETWORK
# MATHEUS - 04/04/2022
resource "azurerm_virtual_network" "vnet-trab-terra" {
  name                = "vnet-trab-terra"
  location            = azurerm_resource_group.rg-trab-terra.location
  resource_group_name = azurerm_resource_group.rg-trab-terra.name
  address_space       = ["10.0.0.0/16"]

}

# CRIANDO A SUBNET
# MATHEUS - 04/04/2022
resource "azurerm_subnet" "sub-trab-terra" {
  name                 = "sub-trab-terra"
  resource_group_name  = azurerm_resource_group.rg-trab-terra.name
  virtual_network_name = azurerm_virtual_network.vnet-trab-terra.name
  address_prefixes     = ["10.0.1.0/24"]
}

# CRIANDO O IP PÚBLICO
# MATHEUS - 04/04/2022
resource "azurerm_public_ip" "ip-trab-terra" {
  name                    = "ip-trab-terra"
  location                = azurerm_resource_group.rg-trab-terra.location
  resource_group_name     = azurerm_resource_group.rg-trab-terra.name
  allocation_method       = "Static"
}

# CRIANDO O FIREWALL
# MATHEUS - 04/04/2022
resource "azurerm_network_security_group" "firewall-trab-terra" {
  name                = "firewall-trab-terra"
  location            = azurerm_resource_group.rg-trab-terra.location
  resource_group_name = azurerm_resource_group.rg-trab-terra.name

  # CONFIGURANDO O SSH
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  #CONFIGURANDO A PORTA 80
  security_rule {
    name                       = "Web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

# CRIANDO UMA PLACA DE REDE
# MATHEUS - 04/04/2022
resource "azurerm_network_interface" "nic-trab-terra" {
  name                = "nic-trab-terra"
  location            = azurerm_resource_group.rg-trab-terra.location
  resource_group_name = azurerm_resource_group.rg-trab-terra.name

  ip_configuration {
    name                          = "nic-ip"
    subnet_id                     = azurerm_subnet.sub-trab-terra.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip-trab-terra.id
  }
}

# ATRELANDO A PLACA DE REDE COM O FIREWALL
# MATHEUS - 04/04/2022
resource "azurerm_network_interface_security_group_association" "nic-firewall-trab-terra" {
  network_interface_id      = azurerm_network_interface.nic-trab-terra.id
  network_security_group_id = azurerm_network_security_group.firewall-trab-terra.id
}

# CRIAÇÃO DO DISCO PARA A MÁQUINA VIRTUAL
# MATHEUS - 04/04/2022
resource "azurerm_storage_account" "sa-trab-terra" {
  name                     = "satrabterra"
  resource_group_name      = azurerm_resource_group.rg-trab-terra.name
  location                 = azurerm_resource_group.rg-trab-terra.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# CRIAÇÃO DAS VARIÁVEIS DE USUÁRIO E SENHA
# MATHEUS - 04/04/2022

variable "user" {
  type        = string
  description = "Descricao do usuario"
}

variable "password" {
  type        = string
  description = "Senha do usuario"
}

# CRIAÇÃO DA MÁQUINA VIRTUAL
# MATHEUS - 04/04/2022
resource "azurerm_linux_virtual_machine" "vm-trab-terra" {
  name                  = "VM"
  location              = "brazilsouth"
  resource_group_name   = azurerm_resource_group.rg-trab-terra.name
  network_interface_ids = [azurerm_network_interface.nic-trab-terra.id]
  size                  = "Standard_E2bs_v5"

  os_disk {
      name              = "myOsDisk"
      caching           = "ReadWrite"
      storage_account_type = "Premium_LRS"
  }

  source_image_reference {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
  }

  admin_username = var.user
  admin_password = var.password
  disable_password_authentication = false

  boot_diagnostics {
      storage_account_uri = azurerm_storage_account.sa-trab-terra.primary_blob_endpoint
  }

  depends_on = [ azurerm_resource_group.rg-trab-terra ]
}

# CRIAÇÃO DA VARIÁVEL PARA ACESSO AO IP PÚBLICO
# MATHEUS - 04/04/2022
data "azurerm_public_ip" "var-ip-public-trab-terra"{
  name = azurerm_public_ip.ip-trab-terra.name
  resource_group_name = azurerm_resource_group.rg-trab-terra.name
}

# CONFIGURANDO O NULL RESOURCE (INSTALAÇÃO DO SERVIDOR)
# MATHEUS - 04/04/2022
resource "null_resource" "install-webserver" {

  connection {
    type = "ssh"
    host = data.azurerm_public_ip.var-ip-public-trab-terra.ip_address
    user = var.user
    password = var.password
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y apache2",
    ]
  }

  # SÓ SUBIR ESTE COMANDO QUANDO A MÁQUINA VIRTUAL ESTIVER PRONTA
  # MATHEUS - 04/04/2022

  depends_on = [ azurerm_linux_virtual_machine.vm-trab-terra ]

}

# AS SENHAS JÁ ESTÃO NO PROGRAMA - "TERRAFORM.TFVARS"
# USER: adminUsername
# PASSWORD: Thi@110585