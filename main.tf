provider "azurerm" {
  features {}
  subscription_id = "f918a166-81fd-4e2f-a6d9-fd253d0823e7"
}

resource "azurerm_resource_group" "B193" {
  name     = "B193-resources"
  location = "East US"
}

resource "azurerm_virtual_network" "B193_vnet" {
  name                = "B193-vnet"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "B193_subnet" {
  name                 = "B193-subnet"  // Public Subnet
  resource_group_name  = azurerm_resource_group.B193.name
  virtual_network_name = azurerm_virtual_network.B193_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "B193_private_subnet" {
  name                 = "B193-private-subnet"  // Private Subnet
  resource_group_name  = azurerm_resource_group.B193.name
  virtual_network_name = azurerm_virtual_network.B193_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "B193_pip" {
  name                = "B193-pip"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  allocation_method   = "Static"
  domain_name_label   = "b193-dns-label"
}

resource "azurerm_public_ip" "B193_nat_pip" {
  name                = "B193-nat-pip"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "B193_nsg" {
  name                = "B193-nsg"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "B193_nic" {
  name                = "B193-nic"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  depends_on = [
    azurerm_subnet.B193_private_subnet
  ]
  ip_configuration {
    name                          = "B193-ip-config"
    subnet_id                     = azurerm_subnet.B193_private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "B193_public_nic" {
  name                = "B193-public-nic"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  depends_on = [
    azurerm_subnet.B193_subnet
  ]
  ip_configuration {
    name                          = "B193-public-ip-config"
    subnet_id                     = azurerm_subnet.B193_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.B193_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "B193_nic_nsg" {
  network_interface_id      = azurerm_network_interface.B193_nic.id
  network_security_group_id = azurerm_network_security_group.B193_nsg.id
}

resource "azurerm_network_interface_security_group_association" "B193_public_nic_nsg" {
  network_interface_id      = azurerm_network_interface.B193_public_nic.id
  network_security_group_id = azurerm_network_security_group.B193_nsg.id
}

resource "azurerm_linux_virtual_machine" "B193_vm" {
  name                = "B193-vm"
  resource_group_name = azurerm_resource_group.B193.name
  location            = azurerm_resource_group.B193.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "YourSecurePassword123!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.B193_nic.id,
  ]
  os_disk {
    name                = "B193-os-disk-${random_string.suffix.result}"
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = base64encode("#!/bin/bash\napt-get update\napt-get install -y nginx\nsystemctl enable nginx\nsystemctl start nginx")
}

resource "azurerm_linux_virtual_machine" "B193_public_vm" {
  name                = "B193-public-vm"
  resource_group_name = azurerm_resource_group.B193.name
  location            = azurerm_resource_group.B193.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "YourSecurePassword123!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.B193_public_nic.id,
  ]
  os_disk {
    name                = "B193-public-os-disk-${random_string.suffix.result}"
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = base64encode("#!/bin/bash\napt-get update\napt-get install -y nginx\nsystemctl enable nginx\nsystemctl start nginx")
}

resource "azurerm_network_interface" "B193_private_nic" {
  name                = "B193-private-nic"
  location            = azurerm_resource_group.B193.location
  resource_group_name = azurerm_resource_group.B193.name
  depends_on = [
    azurerm_subnet.B193_private_subnet
  ]
  ip_configuration {
    name                          = "B193-private-ip-config"
    subnet_id                     = azurerm_subnet.B193_private_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "B193_private_vm" {
  name                = "B193-private-vm"
  resource_group_name = azurerm_resource_group.B193.name
  location            = azurerm_resource_group.B193.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "YourSecurePassword123!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.B193_private_nic.id,
  ]
  os_disk {
    name                = "B193-private-os-disk-${random_string.suffix.result}"
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = base64encode("#!/bin/bash\napt-get update\napt-get install -y nginx\nsystemctl enable nginx\nsystemctl start nginx")
}

resource "azurerm_linux_virtual_machine" "B193_bastion_vm" {
  name                = "B193-bastion-vm"
  resource_group_name = azurerm_resource_group.B193.name
  location            = azurerm_resource_group.B193.location
  size                = "Standard_B1s"
  admin_username      = "adminuser"
  admin_password      = "YourSecurePassword123!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.B193_public_nic.id,
  ]
  os_disk {
    name                = "B193-bastion-os-disk-${random_string.suffix.result}"
    caching             = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data = base64encode("#!/bin/bash\napt-get update\napt-get install -y nginx\nsystemctl enable nginx\nsystemctl start nginx")
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_private_dns_zone" "B193_dns_zone" {
  name                = "unique-B193.com"
  resource_group_name = azurerm_resource_group.B193.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "B193_dns_link" {
  name                  = "B193-dns-link"
  resource_group_name   = azurerm_resource_group.B193.name
  private_dns_zone_name = azurerm_private_dns_zone.B193_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.B193_vnet.id
}

resource "azurerm_private_dns_a_record" "B193_dns_record" {
  name                = "b193-vm"
  zone_name           = azurerm_private_dns_zone.B193_dns_zone.name
  resource_group_name = azurerm_resource_group.B193.name
  ttl                 = 300
  records             = [azurerm_network_interface.B193_nic.private_ip_address]
}

resource "azurerm_dns_zone" "B193_dns_zone" {
  name                = "unique-B193.com"
  resource_group_name = azurerm_resource_group.B193.name
}

resource "azurerm_dns_a_record" "B193_dns_record" {
  name                = "www"
  zone_name           = azurerm_dns_zone.B193_dns_zone.name
  resource_group_name = azurerm_resource_group.B193.name
  ttl                 = 300
  records             = [azurerm_public_ip.B193_pip.ip_address]
}

output "public_ip" {
  value = azurerm_public_ip.B193_pip.ip_address
}

output "dns_name" {
  value = azurerm_public_ip.B193_pip.fqdn
}

output "website_url" {
  value = "http://${azurerm_dns_a_record.B193_dns_record.fqdn}"
}