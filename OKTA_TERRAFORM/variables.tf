# Provider / org
variable "okta_org_name" {
  description = "Okta org subdomain (e.g., my-org for my-org.okta.com)"
  type        = string
}
variable "okta_api_token" {
  description = "Okta API token with rights to manage apps/policies"
  type        = string
  sensitive   = true
}
variable "okta_base_url" {
  description = "Okta base domain (okta.com, okta-emea.com, etc.)"
  type        = string
  default     = "okta.com"
}

# Groups
variable "everyone_group_name" {
  description = "Name of the built-in Everyone group"
  type        = string
  default     = "Everyone"
}
variable "restricted_group_name" {
  description = "Name for the high-security cohort group"
  type        = string
  default     = "Restricted Users"
}

# App
variable "app_label" {
  description = "Display label for the OAuth web app"
  type        = string
  default     = "Test App For Sessions"
}
variable "app_redirect_uris" {
  description = "Allowed redirect URIs"
  type        = list(string)
  default     = ["https://my.app/callback"]
}

# MFA behavior (ISO-8601 durations)
# Examples: PT30M (30 minutes), PT1H (1 hour), PT2H (2 hours), PT12H (12 hours)
variable "restricted_reauth_frequency" {
  description = "Re-auth (MFA) frequency for restricted users"
  type        = string
  default     = "PT2H"
}
variable "restricted_inactivity_period" {
  description = "Idle timeout for restricted users"
  type        = string
  default     = "PT30M"
}
variable "everyone_reauth_frequency" {
  description = "Re-auth (MFA) frequency for everyone else"
  type        = string
  default     = "PT12H"
}
variable "everyone_inactivity_period" {
  description = "Idle timeout for everyone else"
  type        = string
  default     = "PT1H"
}