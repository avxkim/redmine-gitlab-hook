namespace :gitlab_hook do
  desc 'Create GitLab system user for commit reference notes'
  task create_user: :environment do
    # Check if the GitLab user already exists
    if User.find_by(login: 'gitlab').present?
      puts 'GitLab user already exists.'
      next
    end

    # Create a random password
    password = SecureRandom.hex(16)

    # Create the GitLab system user
    user = User.new(
      login: 'gitlab',
      firstname: 'GitLab',
      lastname: 'Integration',
      mail: 'gitlab@example.com',  # Change to a valid email if needed
      password: password,
      password_confirmation: password,
      admin: false,
      status: Principal::STATUS_ACTIVE
    )

    if user.save
      puts 'GitLab user created successfully.'
    else
      puts "Failed to create GitLab user: #{user.errors.full_messages.join(', ')}"
    end
  end
end
