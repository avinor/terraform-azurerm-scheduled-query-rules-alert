variable "resource_group_name" {
  description = "Name of resource group to deploy resources in."
}

variable "location" {
  description = "The Azure Region in which to create resource."
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = map(string)
  default     = {}
}

variable "scheduled_query_alert_rules" {
  description = "" # TODO
  type = map(object({
    description = string
    target      = string
    severity    = number
    criteria = object({
      frequency   = number
      time_window = number
      query       = string
      operator    = string
      threshold   = number
    })
    action = object({
      webhook = object({
        key_vault_id     = string
        key_vault_secret = string
        request_body     = string
      })
    })
  }))
  default = null
}
