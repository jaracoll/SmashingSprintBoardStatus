# Displays the status of the current open sprint

require 'net/http'
require 'json'
require 'time'

JIRA_URI = URI.parse("jira_url")
STORY_POINTS_CUSTOMFIELD_CODE = 'customfield_XXXXX'

JIRA_AUTH = {
  'name' => 'username',
  'password' => 'password'
}

# the key of this mapping must be a unique identifier for your board, the according value must be the view id that is used in Jira
view_mapping = {
  'boardStatus' => { :view_id => XXXX },
}

# gets the view for a given view id
def get_view_for_viewid(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/rapidviews/list")
  response = http.request(request)
  views = JSON.parse(response.body)['views']
  views.each do |view|
    if view['id'] == view_id
      return view
    end
  end
end

# gets the active sprint for the view
def get_active_sprint_for_view(view_id)
  http = create_http
  request = create_request("/rest/greenhopper/1.0/sprintquery/#{view_id}")
  response = http.request(request)
  sprints = JSON.parse(response.body)['sprints']
  sprints.each do |sprint|
    if sprint['state'] == 'ACTIVE'
      return sprint
    end
  end
end

# gets issues in each status
def get_issues_per_status(view_id, sprint_id, issue_count_array, issue_sp_count_array)
  current_start_at = 0

  begin
    response = get_response("/rest/agile/1.0/board/#{view_id}/sprint/#{sprint_id}/issue?startAt=#{current_start_at}")
    page_result = JSON.parse(response.body)
    issue_array = page_result['issues']

    issue_array.each do |issue|
      accumulate_issue_information(issue, issue_count_array, issue_sp_count_array)
    end

    current_start_at = current_start_at + page_result['maxResults']
  end while current_start_at < page_result['total']
end

# accumulate issue information
def accumulate_issue_information(issue, issue_count_array, issue_sp_count_array)
  case issue['fields']['status']['id']
  when "1"
    if !issue['fields']['issuetype']['subtask']
      issue_count_array[0] = issue_count_array[0] + 1
    end
    if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
      issue_sp_count_array[0] = issue_sp_count_array[0] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
    end
  when "2"
    if !issue['fields']['issuetype']['subtask']
      issue_count_array[1] = issue_count_array[1] + 1
    end
    if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
      issue_sp_count_array[1] = issue_sp_count_array[1] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
    end
  when "3"
    if !issue['fields']['issuetype']['subtask']
      issue_count_array[2] = issue_count_array[2] + 1
    end
    if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
      issue_sp_count_array[2] = issue_sp_count_array[2] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
    end
  when "4"
    if !issue['fields']['issuetype']['subtask']
      issue_count_array[3] = issue_count_array[3] + 1
    end
    if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
      issue_sp_count_array[3] = issue_sp_count_array[3] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
    end
  when "5"
    if !issue['fields']['issuetype']['subtask']
      issue_count_array[4] = issue_count_array[4] + 1
    end
    if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
      issue_sp_count_array[4] = issue_sp_count_array[4] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
    end
  else
    puts "ERROR: wrong issue status"
  end

  issue_count_array[5] = issue_count_array[5] + 1
  if !issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE].nil?
    issue_sp_count_array[5] = issue_sp_count_array[5] + issue['fields'][STORY_POINTS_CUSTOMFIELD_CODE]
  end
end

# create HTTP
def create_http
  http = Net::HTTP.new(JIRA_URI.host, JIRA_URI.port)
  if ('https' == JIRA_URI.scheme)
    http.use_ssl     = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  return http
end

# create HTTP request for given path
def create_request(path)
  request = Net::HTTP::Get.new(JIRA_URI.path + path)
  if JIRA_AUTH['name']
    request.basic_auth(JIRA_AUTH['name'], JIRA_AUTH['password'])
  end
  return request
end

# gets the response after a request
def get_response(path)
  http = create_http
  request = create_request(path)
  response = http.request(request)

  return response
end

view_mapping.each do |view, view_id|
  SCHEDULER.every '1h', :first_in => 0 do |id|
    issue_count_array = Array.new(6, 0)
    issue_sp_count_array = Array.new(6, 0)

    view_json = get_view_for_viewid(view_id[:view_id])
    if (view_json)
      sprint_json = get_active_sprint_for_view(view_json['id'])
      if (sprint_json)
        get_issues_per_status(view_json['id'], sprint_json['id'], issue_count_array, issue_sp_count_array)
      end
    end

    send_event(view, {
      toDoCount: issue_count_array[0],
      inProgressCount: issue_count_array[1],
      inReviewCount: issue_count_array[2],
      inTestCount: issue_count_array[3],
      doneCount: issue_count_array[4],

      toDoPercent: issue_sp_count_array[0],
      inProgressPercent: issue_sp_count_array[1],
      inReviewPercent: issue_sp_count_array[2],
      inTestPercent: issue_sp_count_array[3],
      donePercent: issue_sp_count_array[4],
    })
  end
end

