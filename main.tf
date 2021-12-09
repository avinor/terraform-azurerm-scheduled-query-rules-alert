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
  resource_group_name = azurerm_resource_group.main.name
  short_name          = substr(each.key, 0, 12)
  tags                = var.tags

  webhook_receiver {
    name        = "${each.key}-webhook"
    service_uri = data.azurerm_key_vault_secret.kvs[each.key].value
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "main" {
  for_each = var.scheduled_query_alert_rules
  authorized_resource_ids = []
  name                    = "${each.key}-queryrule"
  description             = each.value.description
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  tags                    = var.tags
  enabled                 = true

  trigger {
    operator  = each.value.criteria.operator
    threshold = each.value.criteria.threshold
  }

  data_source_id = each.value.target
  severity       = each.value.severity
  query          = each.value.criteria.query
  frequency      = each.value.criteria.frequency
  time_window    = each.value.criteria.time_window

  action {
    action_group           = [azurerm_monitor_action_group.action[each.key].id]
    custom_webhook_payload = each.value.action.webhook.request_body # See: https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-log-webhook#log-alert-with-a-custom-json-payload-up-to-api-version-2018-04-16
  }
}
