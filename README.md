# Scheduled custom Query Rules with webhook receivers 

This module is built on top of `azurerm_monitor_scheduled_query_rules_alert` and `azurerm_monitor_action_group` and enables triggering webhooks based on custom log searches.  

## Prerequisites

* An Azure resource that logs to [Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview)
* A [Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/general/overview) secret containing a webhook url

## Example use cases

Send a slack message if volume ingested by Log Analytics exceeds 600MB/hour
```terraform
module "example" {
  source = "github.com/avinor/terraform-azurerm-scheduled-query-rules-alert"

  resource_group_name = "alerting-rule-resourcegroup"
  location = "westeurope"

  scheduled_query_alert_rules = {
    "log-analytics-volume" = {
      description = "Trigger slack alert when hourly ingestion volume exceeds 600MB"
      target   = "/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/resourceGroups/my-resourcegroup/providers/Microsoft.OperationalInsights/workspaces/my-log-analytics-workspace"
      severity = 2 # 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose 
      criteria = {
        frequency   = 30 # Evaluate rule once every 30 min 
        time_window = 120 # Run query against data from the last 120 min
        query       = <<-QUERY
        // Find hourly data usage over 600MB
        Usage
        | summarize IngestionVolPerHourMB = sum(Quantity) by bin(TimeGenerated, 1h)
        | where IngestionVolPerHourMB > 600
        QUERY
        operator    = "GreaterThan"
        threshold   = 0
      }
      action = {
        webhook = {
          key_vault_id     = "/subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/resourceGroups/some-resourcegroup/providers/Microsoft.KeyVault/vaults/my-keyvault"
          key_vault_secret = "my-slack-webhook" // A secret that contains the actual webhook url
          // See: https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-log-webhook#log-alert-with-a-custom-json-payload-up-to-api-version-2018-04-16 for available variables in custom json payload 
          request_body     = <<-BODY
          {
              "blocks": [
                  {
                      "type": "section",
                      "text": {
                          "type": "mrkdwn",
                          "text": ":warning: *LogAnalytics Data Volume Warning*\nVolume of ingested data has surpassed 600MB/hour\nRule: #alertrulename\n#linktosearchresults"
                      }
                  }
              ]
          }
          BODY
        }
      }
    }
  }
}
```

## Argument reference
The following arguments are supported:
* `resource_group_name` - (Required) Name of resource group to deploy resources in.
* `location` - (Required) The Azure Region in which to create resource.
* `tags` - (Optional) Tags to apply to all resources created.
* `scheduled_query_alert_rules` - (Required) A [scheduled_query_alert_rules]() block as defined below

### `scheduled_query_alert_rules` supports the following:
* `description` - (Required) The description of the scheduled query rule.
* `target` - (Required) The resource URI over which log search query is to be run. 
* `severity`- (Required) Severity of the alert. Possible values include: 0, 1, 2, 3, or 4 (critical, error, warning, info or verbose).
* `criteria.frequency` - (Required) Frequency (in minutes) at which rule condition should be evaluated. Values must be between 5 and 1440 (inclusive).
* `criteria.time_window` - (Required) Time window for which data needs to be fetched for query (must be greater than or equal to `criteria.frequency`). Values must be between 5 and 2880 (inclusive).
* `criteria.query` - (Required) Kusto log search query.
* `criteria.operator` - (Required) Evaluation operation for rule - 'Equal', 'GreaterThan', GreaterThanOrEqual', 'LessThan', or 'LessThanOrEqual'.
* `criteria.threshold` - (Required) The threshold of the metric trigger. Values must be between 0 and 10000 inclusive.
* `action.webhook.key_vault_id` - (Required) Resource URI of Key Vault that contains webhook.
* `action.webhook.key_vault_secret` - (Required) Secret within `action.webhook.key_vault_id` that contains the actual webhook url.  
* `action.webhook.request_body` - (Required) Custom payload to be sent for all webhook payloads in alerting action.

## References
* [Trigger alerts from custom log queries](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-log)
* [Kusto log queries](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
* [Custom webhook JSON payload](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-log-webhook#log-alert-with-a-custom-json-payload-up-to-api-version-2018-04-16)
