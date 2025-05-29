class GitlabHookController < ApplicationController
  skip_before_action :verify_authenticity_token, :check_if_login_required

  def index
    request_payload = JSON.parse(request.body.read)

    if request_payload['object_kind'] == 'push'
      process_commits(request_payload['commits'], request_payload['repository'])
    elsif request_payload['object_kind'] == 'merge_request'
      process_merge_request(request_payload)
    end

    render json: { success: true }, status: :ok
  rescue => e
    Rails.logger.error "GitLab Hook Error: #{e.message}\n#{e.backtrace.join('\n')}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def process_merge_request(payload)
    mr = payload['object_attributes']
    return unless mr.present?

    action = mr['action']
    Rails.logger.info "Processing merge request: !#{mr['iid']} - #{mr['title']} - Action: #{action}"

    return if ['approved', 'approval', 'unapproved', 'merge'].include?(action)

    title_issue_ids = extract_issue_ids(mr['title'])
    desc_issue_ids = extract_issue_ids(mr['description'].to_s)

    last_commit_issue_ids = []
    if payload['object_attributes']['last_commit'].present?
      last_commit_issue_ids = extract_issue_ids(payload['object_attributes']['last_commit']['message'].to_s)
    end

    issue_ids = (title_issue_ids + desc_issue_ids + last_commit_issue_ids).uniq

    if issue_ids.empty?
      Rails.logger.info "No issue references found in merge request !#{mr['iid']}"
      return
    end

    Rails.logger.info "Found issue references in merge request !#{mr['iid']}: #{issue_ids.join(', ')}"

    issue_ids.each do |issue_id|
      add_merge_request_reference_to_issue(issue_id, payload)
    end
  end

  def process_commits(commits, repository)
    return unless commits.present?

    Rails.logger.info "Processing #{commits.size} commits from repository: #{repository['name']}"

    commits.each do |commit|
      Rails.logger.info "Processing commit: #{commit['id'][0..7]} - #{commit['message'].strip.split('\n').first}"
      issue_ids = extract_issue_ids(commit['message'])

      if issue_ids.empty?
        Rails.logger.info "No issue references found in commit #{commit['id'][0..7]}"
        next
      end

      Rails.logger.info "Found issue references in commit #{commit['id'][0..7]}: #{issue_ids.join(', ')}"
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

    commit_short_id = commit['id'][0..7]
    return if Journal.where(journalized: issue)
                    .where("notes LIKE ?", "%[#{commit_short_id}]%")
                    .exists?

                   note_text = "Referenced by commit [#{commit_short_id}](#{commit['url']}?target=_blank) " \
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

      def add_merge_request_reference_to_issue(issue_id, payload)
    issue = Issue.find_by(id: issue_id)
    return unless issue

    mr = payload['object_attributes']
    project = payload['project']
    author = payload['user']
    action = mr['action']

    mr_id = "!#{mr['iid']}"
    return if Journal.where(journalized: issue)
                    .where("notes LIKE ?", "%Merge request #{mr_id}% #{action}%")
                    .exists?

    action_message = case action
                     when 'open'
                       "Opened by #{author['name']} on #{format_date(mr['created_at'])}"
                     when 'merge'
                       "Merged by #{author['name']} on #{format_date(mr['updated_at'])}"
                     when 'close'
                       "Closed by #{author['name']} on #{format_date(mr['updated_at'])}"
                     when 'update'
                       "Updated by #{author['name']} on #{format_date(mr['updated_at'])}"
                     else
                       "#{action.capitalize} by #{author['name']} on #{format_date(mr['updated_at'])}"
                     end

                   note_text = "Referenced by Merge request [#{mr_id}](#{mr['url']}?target=_blank) " \
               "in #{project['name']}:\n\n" \
               "_#{mr['title'].strip}_\n\n" \
               "#{action_message}"

    journal = Journal.new(
      journalized: issue,
      user: get_system_user,
      notes: note_text
    )

    journal.save
  end

  def format_date(timestamp)
    Time.parse(timestamp).localtime.strftime("%Y-%m-%d %H:%M:%S")
  end

  def get_system_user
    user = User.find_by(login: 'gitlab')

    unless user
      Rails.logger.warn "GitLab Hook: 'gitlab' user not found, please run the gitlab_hook:create_user rake task"
      user = User.new(login: 'gitlab', firstname: 'GitLab', lastname: 'Integration')
    end

    user
  end
end
