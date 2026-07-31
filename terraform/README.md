# Azure VNet CI/CD (Terraform + GitHub Actions + OIDC)

Creates 2 virtual networks (customizable via `terraform/variables.tf`) in Azure
through a GitHub Actions pipeline that authenticates with OIDC — no client
secrets stored anywhere.

## What's included
```
terraform/
  providers.tf   # azurerm provider + remote state backend
  variables.tf   # resource group, location, VNet/subnet definitions
  main.tf        # resource group + VNets + subnets
  outputs.tf     # VNet IDs and address spaces
.github/workflows/deploy.yml  # plan on PR, apply on merge to main
```

## One-time setup

### 1. Create the Azure AD App Registration + Federated Credential
Run these with Azure CLI (needs Owner/Contributor + User Access Administrator,
or ask your Azure admin):

```bash
# Create the app registration (this becomes your OIDC "client")
az ad app create --display-name "gh-actions-vnet-cicd"
APP_ID=$(az ad app list --display-name "gh-actions-vnet-cicd" --query "[0].appId" -o tsv)

# Create a service principal for the app
az ad sp create --id $APP_ID

# Assign it Contributor on the subscription (scope this down to a
# resource group if you prefer least privilege)
az role assignment create \
  --role "Contributor" \
  --assignee $APP_ID \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Add a federated credential trusting your GitHub repo's main branch
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-main-branch",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<GITHUB_ORG>/<GITHUB_REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Also add one for pull_request events if you want plan-on-PR to work:
az ad app federated-credential create \
  --id $APP_ID \
  --parameters '{
    "name": "github-pull-requests",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<GITHUB_ORG>/<GITHUB_REPO>:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Note the `appId` (client ID), your tenant ID (`az account show --query tenantId`),
and subscription ID (`az account show --query id`) — you'll need all three.

### 2. Create a storage account for Terraform remote state
```bash
az group create -n rg-tfstate -l eastus
az storage account create -n sttfstatevnetcicd -g rg-tfstate -l eastus --sku Standard_LRS
az storage container create -n tfstate --account-name sttfstatevnetcicd
```

### 3. Add GitHub repo secrets
Settings → Secrets and variables → Actions → New repository secret:

| Secret name | Value |
|---|---|
| `AZURE_CLIENT_ID` | the App Registration's Application (client) ID |
| `AZURE_TENANT_ID` | your Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | your subscription ID |
| `TF_STATE_RG` | `rg-tfstate` |
| `TF_STATE_SA` | `sttfstatevnetcicd` |
| `TF_STATE_CONTAINER` | `tfstate` |

### 4. (Optional) Protect the `production` environment
Settings → Environments → New environment → `production` → add required
reviewers. The workflow references this environment so `apply` will pause
for manual approval if you set that up.

## How it runs
- **Pull request** touching `terraform/**` → `terraform plan` only.
- **Push/merge to `main`** → `terraform plan` then `terraform apply`.
- **Manual run** → Actions tab → "Deploy Azure VNets (Terraform)" → Run workflow.

## Customizing the VNets
Edit the `virtual_networks` map in `terraform/variables.tf` — add, remove, or
resize VNets/subnets there. `main.tf` uses `for_each`, so it scales to any
number of networks without further changes.
