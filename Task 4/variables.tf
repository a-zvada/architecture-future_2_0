variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Folder ID"
  type        = string
}

variable "ssh_public_key" {
  description = "Публичный SSH ключ"
  type        = string
}

variable "vm_user" {
  default = "ubuntu"
}

variable "domains" {
  default = ["clinical", "financial", "ai", "crm", "event_bus"]
}