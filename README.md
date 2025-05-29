# Redmine GitLab Hook Plugin

This plugin integrates Redmine with GitLab by processing webhook events from GitLab and updating Redmine issues when they are referenced in commit messages.

## Features

- Processes GitLab webhook push events and merge request events
- Parses commit messages and merge request titles/descriptions for issue references (e.g., "fixes #123")
- Adds commit and merge request information as notes to referenced issues
- Supports multiple issue references per commit or merge request
- Prevents duplicate references from being added

## Requirements

- Redmine 6.0.0 or higher
- Ruby 3.0 or higher

## Installation

1. Clone this repository into your Redmine plugins directory:
   ```
   cd /path/to/redmine/plugins
   git clone https://github.com/avxkim/redmine-gitlab-hook
   ```

2. Create the GitLab system user for posting commit references:
   ```
   # For development environment
   bundle exec rake "redmine-gitlab-hook:create_user" RAILS_ENV=development

   # For production environment
   # If you encounter a 'Missing secret_key_base' error, try:
   RAILS_ENV=production SECRET_KEY_BASE=temporary_key bundle exec rake "redmine-gitlab-hook:create_user"
   ```

3. Restart your Redmine instance:
   ```
   touch tmp/restart.txt
   ```

## Configuration

### Redmine Configuration

No additional configuration is needed in Redmine. The plugin automatically creates the webhook endpoint at:

```
https://your-redmine-instance.com/gitlab-hook
```

### GitLab Configuration

1. Go to your GitLab project or group
2. Navigate to Settings > Webhooks
3. Add a new webhook with the following settings:
   - URL: `https://your-redmine-instance.com/gitlab-hook`
   - Trigger: Select both "Push events" and "Merge request events"
   - SSL verification: Enable if your Redmine uses HTTPS with a valid certificate
4. Click "Add webhook"

## Usage

Once the webhook is set up, whenever a commit is pushed to GitLab with a message containing a reference to a Redmine issue (e.g., "fixes #123"), the plugin will automatically add a note to that issue with information about the commit.

The plugin recognizes the following reference formats in commit messages:
- `#123`
- `fixes #123`
- `fixed #123`
- `closes #123`
- `closed #123`
- `resolves #123`
- `resolved #123`

## Troubleshooting

If the plugin is not working as expected:

1. Check the Redmine logs at `log/production.log` for any error messages related to "GitLab Hook"
2. **Always restart Redmine after updating the plugin** by touching the restart file: `touch tmp/restart.txt`
3. Make sure the webhook in GitLab is configured for both Push events and Merge request events

## License

This plugin is licensed under the MIT License.
