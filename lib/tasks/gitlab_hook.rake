namespace :"redmine-gitlab-hook" do
  desc 'Display current timezone settings'
  task timezone_info: :environment do
    puts "Current Rails timezone: #{Time.zone.name}"
    puts "Current system time: #{Time.now}"
    puts "Current timezone time: #{Time.zone.now}"
    puts "UTC time: #{Time.now.utc}"
    puts "GMT+5 (Asia/Almaty) time: #{Time.now.in_time_zone('Asia/Almaty')}"
  end

  desc 'Create GitLab system user for commit reference notes'
  task create_user: :environment do
    if User.find_by(login: 'gitlab').present?
      puts 'GitLab user already exists.'
      next
    end

    password = SecureRandom.hex(16)

    user = User.new(
      login: 'gitlab',
      firstname: 'GitLab',
      lastname: 'Integration',
      mail: 'gitlab@example.com',
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
