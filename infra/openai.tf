resource "azurecaf_name" "cog_name" {
  name          = local.resource_token
  resource_type = "azurerm_cognitive_account"
  random_length = 0
  clean_input   = true
}

resource "azapi_resource" "cog" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = azurecaf_name.cog_name.result
  parent_id                 = azurerm_resource_group.rg.id
  location                  = var.location
  schema_validation_enabled = false
  tags                      = azurerm_resource_group.rg.tags

  body = {
    kind = "AIServices"
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      disableLocalAuth        = true
      allowProjectManagement  = true
      customSubDomainName     = azurecaf_name.cog_name.result
    }
  }

  response_export_values = ["properties.endpoint"]
}

# Foundry project for web search and agent capabilities
resource "azapi_resource" "ai_foundry_project" {
  type                      = "Microsoft.CognitiveServices/accounts/projects@2025-06-01"
  name                      = "project-${local.resource_token}"
  parent_id                 = azapi_resource.cog.id
  location                  = var.location
  schema_validation_enabled = false

  body = {
    sku = {
      name = "S0"
    }
    identity = {
      type = "SystemAssigned"
    }
    properties = {
      displayName = "Creative Writer Project"
      description = "Foundry project for creative writing agents"
    }
  }
}

resource "azapi_resource" "deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.openai_model_name
  parent_id = azapi_resource.cog.id

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = var.openai_model_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.openai_model_name
        version = var.openai_model_version
      }
    }
  }
}

resource "azapi_resource" "gpt35_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.openai_35_turbo_model_name
  parent_id = azapi_resource.cog.id
  depends_on = [azapi_resource.deployment]

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = var.openai_35_turbo_model_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.openai_35_turbo_model_name
        version = var.openai_35_turbo_model_version
      }
    }
  }
}

resource "azapi_resource" "gpt4_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.openai_4_eval_deployment_name
  parent_id = azapi_resource.cog.id
  depends_on = [azapi_resource.gpt35_deployment]

  body = {
    sku = {
      name     = "GlobalStandard"
      capacity = var.openai_4_eval_model_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.openai_4_eval_model_name
        version = var.openai_4_eval_model_version
      }
    }
  }
}

resource "azapi_resource" "embedding_deployment" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2023-05-01"
  name      = var.openai_embedding_model_name
  parent_id = azapi_resource.cog.id
  depends_on = [azapi_resource.gpt4_deployment]

  body = {
    sku = {
      name     = "Standard"
      capacity = var.openai_embedding_model_capacity
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = var.openai_embedding_model_name
        version = var.openai_embedding_model_version
      }
    }
  }
}
