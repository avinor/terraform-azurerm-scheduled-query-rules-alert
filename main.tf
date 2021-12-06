terraform {
  required_version = ">= 0.13"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.87.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

data "azurerm_key_vault_secret" "kvs" {
  for_each = var.scheduled_query_alert_rules

  key_vault_id = each.value.action.webhook.key_vault_id
  name         = each.value.action.webhook.key_vault_secret
}

resource "azurerm_monitor_action_group" "action" {
  for_each = var.scheduled_query_alert_rules

  name                = "${each.key}-ag"
  resource_group_name = azurerm_resource_group.main.name # (Required) The name of the resource group in which to create the Action Group instance.
  short_name          = substr(each.key, 0, 12)          # (Required) The short name of the action group. This will be used in SMS messages.
  tags                = var.tags

  webhook_receiver {
    name        = "${each.key}-webhook"                             # (Required) The name of the webhook receiver. Names must be unique (case-insensitive) across all receivers within an action group.
    service_uri = data.azurerm_key_vault_secret.kvs[each.key].value # (Required) The URI where webhooks should be sent.
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "main" {
  for_each = var.scheduled_query_alert_rules

  name                = "${each.key}-queryrule" # (Required) The name of the scheduled query rule. Changing this forces a new resource to be created.
  description         = each.value.description
  resource_group_name = azurerm_resource_group.main.name # (Required) The name of the resource group in which to create the scheduled query rule instance.
  location            = var.location
  tags                = var.tags
  enabled             = true

  trigger {
    operator  = each.value.criteria.operator
    threshold = each.value.criteria.threshold
  }

  data_source_id = each.value.target
  severity       = each.value.severity # (Optional) Severity of the alert. Possible values include: 0, 1, 2, 3, or 4.
  query          = each.value.criteria.query
  frequency      = each.value.criteria.frequency   # (Required) Frequency (in minutes) at which rule condition should be evaluated. Values must be between 5 and 1440 (inclusive).
  time_window    = each.value.criteria.time_window # (Required) Time window for which data needs to be fetched for query (must be greater than or equal to frequency). Values must be between 5 and 2880 (inclusive).

  action {
    action_group           = [azurerm_monitor_action_group.action[each.key].id]
    custom_webhook_payload = each.value.action.webhook.request_body # https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-log-webhook#log-alert-with-a-custom-json-payload-up-to-api-version-2018-04-16
  }
}
