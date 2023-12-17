# Set in this file your deployment variables
# Specify the Azure values


variable "azure-client-id" {

  type    = string
  default = "72d3ef6a-7f4e-4b54-bcc7-552b8e11dda6"
}
variable "azure-client-secret" {

  type    = string
  default = "UZl8Q~BlaEUyQV5x3GMuW32dCKgRlLeMd.TjmaEs"
}

variable "vm_names" {
  type    = set(string)
  default = ["Dec13-0-vm", "Dec13-1-vm"]
}


variable "azure-subscription" {

  type    = string
  default = "869ae145-2392-4de3-8329-ca304df71588"
}
variable "azure-tenant" {

  type    = string
  default = "5105276e-ccfc-4bd1-a8ea-5ca3bf947a0e"
}

variable "region" {

  type    = string
  default = "eastus"
}

variable "prefix" {
  default = "Dec13"
}