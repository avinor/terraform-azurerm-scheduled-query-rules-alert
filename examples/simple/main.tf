module "simple" {
  source = "../.."

  location            = "westeurope"
  resource_group_name = "simple-alerting-rg"

  scheduled_query_alert_rules = {
    "log-analytics-hourly-ingestion-volume" = {
      description = "Trigger alert when hourly ingestion volume exceeds threshold value"
      target   = "/subscriptions/8c2235a1-14f2-4f16-a615-03f1702426fb/resourcegroups/my-rg/providers/microsoft.operationalinsights/workspaces/my-workspace"
      severity = 2
      criteria = {
        frequency   = 30
        time_window = 120
        query       = <<-QUERY
        Usage
        | summarize IngestionVolPerHourMB = sum(Quantity) by bin(TimeGenerated, 1h)
        | where IngestionVolPerHourMB > 200
        QUERY
        operator    = "GreaterThan"
        threshold   = 0
      }
      action = {
        webhook = {
          key_vault_id     = "/subscriptions/a51078ff-541e-40be-b679-a0760cda72a4/resourceGroups/my-rg/providers/Microsoft.KeyVault/vaults/my-keyvault"
          key_vault_secret = "slack-webhook-ipt-alerts"
          request_body     = <<-BODY
          {
              "blocks": [
                  {
                      "type": "section",
                      "text": {
                          "type": "mrkdwn",
                          "text": ":warning: *LogAnalytics Data Volume Warning*\nVolume of ingested data has surpassed threshold value\nRule: #alertrulename\n#linktosearchresults"
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
