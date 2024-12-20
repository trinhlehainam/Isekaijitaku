# Keycloak SSO Integration with Nextcloud

This document describes how to integrate Keycloak SSO with Nextcloud, particularly focusing on scenarios with multiple SSO providers.

## Prerequisites

1. A running Nextcloud instance
2. One or more Keycloak servers (e.g., private and public instances)
3. The [Social Login](https://apps.nextcloud.com/apps/sociallogin) app installed in Nextcloud

## Configuration Steps

### Nextcloud Configuration

#### Configure Social Login

1. Go to Nextcloud Admin Settings → Social Login
2. For each Keycloak instance, configure the following settings:

##### Private Keycloak Configuration

| Setting | Value |
|---------|-------|
| Name | Private Keycloak |
| Title | Login with Private Keycloak |
| Authorize URL | `https://private-keycloak/realms/your-realm/protocol/openid-connect/auth` |
| Token URL | `https://private-keycloak/realms/your-realm/protocol/openid-connect/token` |
| User Info URL | `https://private-keycloak/realms/your-realm/protocol/openid-connect/userinfo` |
| Client ID | your-client-id |
| Client Secret | your-client-secret |
| Scope | openid email profile |
| Groups Claim | groups |
| Style | keycloak |
| Default Group | (leave empty) |
| Prevent Create User | true |

##### Public Keycloak Configuration

| Setting | Value |
|---------|-------|
| Name | Public Keycloak |
| Title | Login with Public Keycloak |
| Authorize URL | `https://public-keycloak/realms/your-realm/protocol/openid-connect/auth` |
| Token URL | `https://public-keycloak/realms/your-realm/protocol/openid-connect/token` |
| User Info URL | `https://public-keycloak/realms/your-realm/protocol/openid-connect/userinfo` |
| Client ID | your-client-id |
| Client Secret | your-client-secret |
| Scope | openid email profile |
| Groups Claim | groups |
| Style | keycloak |
| Default Group | (leave empty) |
| Prevent Create User | true |

##### Checkbox Settings

| Setting | Status | Description |
|---------|--------|-------------|
| [X] Disable auto create new users | Checked | Prevents automatic creation of new user accounts when users log in via SSO |
| [ ] Create users with disabled account | Checked | New users are created with disabled accounts requiring admin approval |
| [X] Allow users to connect social logins with their account | Checked | Allows existing users to link multiple SSO providers to their account |
| [ ] Prevent creating an account if the email address exists | Checked | Blocks creation of new accounts with duplicate email addresses |
| [X] Update user profile every login | Checked | Updates user information from SSO provider upon each login |
| [ ] Do not prune not available user groups on login | Unchecked | Keeps user groups even if they are no longer available in SSO provider |
| [ ] Automatically create groups if they do not exists | Unchecked | Creates new groups in Nextcloud if they exist in SSO provider |
| [X] Restrict login for users without mapped groups | Checked | Only allows login for users who have groups mapped from Keycloak |
| [X] Restrict login for users without assigned groups | Checked | Only allows login for users who have been assigned to Nextcloud groups |
| [ ] Disable notify admins about new users | Checked | Turns off admin notifications when new users are created |
| [X] Hide default login | Checked | Hides the standard Nextcloud login form |
| [ ] Button text without prefix | Checked | Removes "Login with" prefix from SSO button text |

Note: These settings can be found in the Nextcloud Admin Settings → Social Login → Additional Settings section.

### Account Linking Process

1. Users must first have an existing Nextcloud account
2. Users can link additional SSO providers to their account by:
   - Going to Personal Settings → Security
   - Under "Connected Accounts", they can connect additional SSO providers

### Security Considerations

1. Always use HTTPS for all endpoints
2. Regularly rotate client secrets
3. Limit redirect URIs to specific Nextcloud instances
4. Consider implementing additional security measures like:
   - IP filtering
   - Multi-factor authentication
   - Group-based access control

### Troubleshooting

1. If SSO login fails:
   - Check Nextcloud logs: `docker exec nextcloud tail -f /var/www/html/data/nextcloud.log`
   - Verify Keycloak endpoints are accessible from Nextcloud
   - Ensure client credentials are correct

2. If account linking fails:
   - Ensure `allow_login_connect` is enabled
   - Check if the email addresses match between accounts
   - Verify user session is active

### References

- [Keycloak SSO User Mapping Discussion](https://help.nextcloud.com/t/keycloak-sso-how-to-map-only-existing-keycloak-users-to-nextcloud-users-without-creating-new/85981)
- [Nextcloud Social Login Documentation](https://github.com/zorn-v/nextcloud-social-login/blob/master/docs/sso/keycloak.md)
