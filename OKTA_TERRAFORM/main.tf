terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 6.0"
    }
  }
}

provider "okta" {
  org_name  = var.okta_org_name
  api_token = var.okta_api_token
  base_url  = var.okta_base_url
}

# ------------------------------------------------------
# Groups
# ------------------------------------------------------

# Built-in Everyone group
data "okta_group" "everyone" {
  name = var.everyone_group_name
}

# High-security cohort (gets stricter MFA)
resource "okta_group" "restricted_users" {
  name        = var.restricted_group_name
  description = "Users who require stricter MFA for ${var.app_label}"
}

# ------------------------------------------------------
# App-level Authentication Policy (attached to app below)
# ------------------------------------------------------
resource "okta_app_signon_policy" "app_auth_policy" {
  name        = "${var.app_label} Auth Policy"
  description = "App sign-on policy for ${var.app_label}"
  priority    = 1
  catch_all   = true
}

# Rule 1 (priority 1): Restricted users → STRICT MFA (short re-auth)
resource "okta_app_signon_policy_rule" "restricted_rule" {
  policy_id       = okta_app_signon_policy.app_auth_policy.id
  name            = "Restricted Users - Step-up MFA"
  priority        = 1
  status          = "ACTIVE"
  access          = "ALLOW"

  # MFA always
  factor_mode     = "2FA"

  # Scope: only the high-security group
  groups_included = [okta_group.restricted_users.id]

  # Tighter security posture for this cohort
  re_authentication_frequency = var.restricted_reauth_frequency  # e.g., PT2H
  inactivity_period           = var.restricted_inactivity_period # e.g., PT30M

  # Common conditions
  network_connection = "ANYWHERE"
  type               = "ASSURANCE"
}

# Rule 2 (priority 2): Everyone → MFA required (longer re-auth)
resource "okta_app_signon_policy_rule" "everyone_rule" {
  policy_id       = okta_app_signon_policy.app_auth_policy.id
  name            = "Everyone - MFA Required"
  priority        = 2
  status          = "ACTIVE"
  access          = "ALLOW"

  # MFA as the org-wide baseline
  factor_mode     = "2FA"

  # Scope: Everyone (acts as default)
  groups_included = [data.okta_group.everyone.id]

  # Slightly less strict than restricted users
  re_authentication_frequency = var.everyone_reauth_frequency     # e.g., PT12H
  inactivity_period           = var.everyone_inactivity_period    # e.g., PT1H

  network_connection = "ANYWHERE"
  type               = "ASSURANCE"
}

# ------------------------------------------------------
# OAuth app bound to the policy above
# ------------------------------------------------------
resource "okta_app_oauth" "my_web_app" {
  label                  = var.app_label
  type                   = "web"
  grant_types            = ["authorization_code"]
  redirect_uris          = var.app_redirect_uris

  # Bind app to policy
  authentication_policy  = okta_app_signon_policy.app_auth_policy.id

  token_endpoint_auth_method = "client_secret_basic"
  issuer_mode                = "ORG_URL"
  user_name_template_type    = "BUILT_IN"
  user_name_template         = "$${source.login}"
}