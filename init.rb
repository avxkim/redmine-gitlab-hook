require 'redmine'

Redmine::Plugin.register :redmine_gitlab_hook do
  name 'Redmine GitLab Hook plugin'
  author 'Noname'
  description 'This plugin adds GitLab webhook integration to Redmine'
  version '0.0.1'
  url 'https://github.com/avxkim/redmine-gitlab-hook'
  author_url 'https://github.com/avxkim'

  # Add permission for the webhook endpoint
  permission :gitlab_webhook, { gitlab_hook: [:index] }, public: true
end

# Register routes
Rails.application.config.after_initialize do
  unless Rails.application.routes.routes.detect { |route| route.name == 'gitlab_hook' }
    Rails.application.routes.prepend do
      post 'gitlab-hook', to: 'gitlab_hook#index', as: 'gitlab_hook'
    end
  end
end
