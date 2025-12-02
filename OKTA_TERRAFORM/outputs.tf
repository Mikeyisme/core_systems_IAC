output "restricted_group_id" {
  description = "ID of the Restricted Users group"
  value       = okta_group.restricted_users.id
}

output "policy_id" {
  description = "ID of the app-level authentication policy"
  value       = okta_app_signon_policy.app_auth_policy.id
}

output "app_id" {
  description = "ID of the OAuth application using the policy"
  value       = okta_app_oauth.my_web_app.id
}