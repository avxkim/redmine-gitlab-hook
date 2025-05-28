class GitlabHookController < ApplicationController
  skip_before_action :verify_authenticity_token, :check_if_login_required

  def index
    request_payload = JSON.parse(request.body.read)

    if request_payload['object_kind'] == 'push'
      process_commits(request_payload['commits'], request_payload['repository'])
    end

    render json: { success: true }, status: :ok
  rescue => e
    Rails.logger.error "GitLab Hook Error: #{e.message}\n#{e.backtrace.join('\n')}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def process_commits(commits, repository)
    return unless commits.present?

    commits.each do |commit|
      issue_ids = extract_issue_ids(commit['message'])

      next if issue_ids.empty?

      issue_ids.each do |issue_id|
        add_commit_reference_to_issue(issue_id, commit, repository)
      end
    end
  end

  def extract_issue_ids(message)
    refs = message.scan(/(fix(es|ed)?|close[sd]?|resolve[sd]?)?(\s*#(\d+))/i)
    refs.map { |ref| ref[3].to_i }.uniq.select { |id| id > 0 }
  end

  def add_commit_reference_to_issue(issue_id, commit, repository)
    issue = Issue.find_by(id: issue_id)
    return unless issue

    note_text = "Referenced by commit [#{commit['id'][0..7]}](#{commit['url']}) " \
               "in #{repository['name']}:\n\n" \
               "_#{commit['message'].strip}_\n\n" \
               "Authored by #{commit['author']['name']} on #{format_date(commit['timestamp'])}"

    journal = Journal.new(
      journalized: issue,
      user: get_system_user,
      notes: note_text
    )

    journal.save
  end

  def format_date(timestamp)
    Time.parse(timestamp).strftime("%Y-%m-%d %H:%M:%S")
  end

  def get_system_user
    user = User.find_by(login: 'gitlab')
    user || User.admin.first
  end
end
