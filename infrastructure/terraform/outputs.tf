output "public_ip_address" {
  description = "Public IP address of the Azure VM"
  value       = azurerm_public_ip.main.ip_address
}

output "vm_name" {
  description = "Name of the Azure VM"
  value       = azurerm_linux_virtual_machine.main.name
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_fqdn" {
  description = "FQDN of the Azure VM"
  value       = azurerm_public_ip.main.fqdn
}

output "storage_account_name" {
  description = "Name of the storage account for backups"
  value       = azurerm_storage_account.backups.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}
