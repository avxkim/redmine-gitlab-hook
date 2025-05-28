class GitlabHookController < ApplicationController
  skip_before_action :verify_authenticity_token, :check_if_login_required

  # The webhook endpoint that receives GitLab push events
  def index
    # Get the request payload
    request_payload = JSON.parse(request.body.read)

    # Process the GitLab webhook data
    if request_payload['object_kind'] == 'push'
      process_commits(request_payload['commits'], request_payload['repository'])
    end

    # Return a success response
    render json: { success: true }, status: :ok
  rescue => e
    Rails.logger.error "GitLab Hook Error: #{e.message}\n#{e.backtrace.join('\n')}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  # Process each commit in the push event
  def process_commits(commits, repository)
    return unless commits.present?

    commits.each do |commit|
      # Check if commit message contains issue references like #123
      issue_ids = extract_issue_ids(commit['message'])

      next if issue_ids.empty?

      # For each referenced issue, add a note with the commit link
      issue_ids.each do |issue_id|
        add_commit_reference_to_issue(issue_id, commit, repository)
      end
    end
  end

  # Extract issue IDs from commit message using regex
  def extract_issue_ids(message)
    # Match patterns like "#123", "fixes #123", "closes #123", etc.
    refs = message.scan(/(fix(es|ed)?|close[sd]?|resolve[sd]?)?(\s*#(\d+))/i)
    refs.map { |ref| ref[3].to_i }.uniq.select { |id| id > 0 }
  end

  # Add a note to the issue with the commit reference
  def add_commit_reference_to_issue(issue_id, commit, repository)
    issue = Issue.find_by(id: issue_id)
    return unless issue

    # Create the note content with the commit information
    note_text = "Referenced by commit [[#{commit['id'][0..7]}|#{commit['url']}]] " \
               "in #{repository['name']}:\n\n" \
               "_#{commit['message'].strip}_\n\n" \
               "Authored by #{commit['author']['name']} on #{format_date(commit['timestamp'])}"

    # Create a journal (note) for the issue
    journal = Journal.new(
      journalized: issue,
      user: get_system_user,
      notes: note_text
    )

    journal.save
  end

  # Format the commit timestamp for display
  def format_date(timestamp)
    Time.parse(timestamp).strftime("%Y-%m-%d %H:%M:%S")
  end

  # Get or create a system user for posting commit references
  def get_system_user
    # Try to find the 'gitlab' user, or use the admin if not found
    user = User.find_by(login: 'gitlab')
    user || User.admin.first
  end
end
