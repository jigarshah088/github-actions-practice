terraform {
  #############################################################
  ## AFTER RUNNING TERRAFORM APPLY (WITH LOCAL BACKEND)
  ## YOU WILL UNCOMMENT THIS CODE THEN RERUN TERRAFORM INIT
  ## TO SWITCH FROM LOCAL BACKEND TO REMOTE AWS BACKEND
  #############################################################
  required_version = "=1.6.5"




  required_providers {
    azurerm = {
      #source  = "hashicorp/azurerm"
      version = "~>3.0.0"
    }
  }
}



provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = var.azure-subscription
  client_id       = var.azure-client-id
  client_secret   = var.azure-client-secret
  tenant_id       = var.azure-tenant

}

resource "azurerm_resource_group" "azure_backend_example" {
  name     = "azure_backend_example"
  location = var.region
}



# Create public IPs
resource "azurerm_public_ip" "test" {

  name                = "myPublicIP-test"
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_storage_account" "azurermstorageaccount" {
  name                     = "azurermstjpg"
  resource_group_name      = azurerm_resource_group.azure_backend_example.name
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


resource "azurerm_storage_container" "azurerm_storage_container_backend_example" {
  name                  = "vhds"
  storage_account_name  = azurerm_storage_account.azurermstorageaccount.name
  container_access_type = "private"

}


resource "azurerm_storage_blob" "azure_backend_example_blob" {
  name = "azure_backend_example_blob"
  type = "Block"

  storage_account_name   = azurerm_storage_account.azurermstorageaccount.name
  storage_container_name = azurerm_storage_container.azurerm_storage_container_backend_example.name
}


resource "azurerm_storage_encryption_scope" "example" {
  name               = "microsoftmanaged"
  storage_account_id = azurerm_storage_account.azurermstorageaccount.id
  source             = "Microsoft.Storage"

}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.azure_backend_example.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

}

resource "azurerm_network_security_group" "example" {
  name                = "example-nsg"
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name

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

  security_rule {
    name                       = "http"
    description                = "Allow HTTP access"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "http" {
  for_each = var.vm_names

  network_interface_id      = azurerm_network_interface.main[each.key].id
  network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_lb" "http" {

  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name
  sku                 = "Standard"
  frontend_ip_configuration {
    name = "PublicIPAddress"
    #subnet_id                     = azurerm_subnet.internal.id
    public_ip_address_id = azurerm_public_ip.test.id
  }
}

#####
resource "azurerm_lb_backend_address_pool" "http" {
  name            = "my-lb-backend-pool"
  loadbalancer_id = azurerm_lb.http.id
}

resource "azurerm_lb_probe" "http" {

  #loadbalancer_id = "${element(azurerm_lb.http.*.id, count.index)}"
  loadbalancer_id = azurerm_lb.http.id
  name            = "my-lb"
  port            = 80
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "http" {

  loadbalancer_id                = azurerm_lb.http.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.http.id]
  frontend_ip_configuration_name = azurerm_lb.http.frontend_ip_configuration[0].name
  name                           = "HTTP"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.http.id
}

resource "azurerm_network_interface_backend_address_pool_association" "http" {
  for_each = var.vm_names

  network_interface_id    = azurerm_network_interface.main[each.key].id
  ip_configuration_name   = azurerm_network_interface.main[each.key].ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.http.id
}
#####
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_network_interface" "main" {
  for_each            = var.vm_names
  name                = "nic-${each.value}"
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name

  ip_configuration {

    name                          = "testconfiguration1-${each.value}"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"

    #public_ip_address_id          = "${azurerm_public_ip.test.id}"
    #public_ip_address_id          = "${element(azurerm_public_ip.test.*.id, count.index)}"

  }
}

resource "azurerm_virtual_machine" "main" {
  for_each            = var.vm_names
  name                = each.value
  location            = azurerm_resource_group.azure_backend_example.location
  resource_group_name = azurerm_resource_group.azure_backend_example.name
  #network_interface_ids = [element(azurerm_network_interface.main.*.id, count.index)] 
  network_interface_ids = [azurerm_network_interface.main[each.key].id]
  vm_size               = "Standard_DS1_v2"


  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  storage_os_disk {

    #name              = "${azurerm_virtual_machine.main[count.index]}-disk"
    name              = "myosdisk-${each.value}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
    custom_data    = file("scripts/first-boot.sh")
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

}
