require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'

require 'pry'

class Gmail

  def initialize(
      app_name: 'Gmail API Ruby QuickStart',
      secrets_path: File.join('config', 'client_secret.json'),
      credentials_path: File.join('config', '.credentials', "gmail-ruby-quickstart.json"),
      scope: 'https://www.googleapis.com/auth/gmail.modify'
    )

    @client = Google::APIClient.new(application_name: app_name)
    @client.authorization = authorize(credentials_path, secrets_path, scope)

    # Initialize the API
    @gmail_api = @client.discovered_api('gmail', 'v1')

  end

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization request via InstalledAppFlow.
  # If authorization is required, the user's default browser will be launched
  # to approve the request.
  def authorize(credentials_path, secrets_path, scope)

    FileUtils.mkdir_p(File.dirname(credentials_path))

    file_store = Google::APIClient::FileStore.new(credentials_path)
    storage = Google::APIClient::Storage.new(file_store)
    auth = storage.authorize

    if auth.nil? || (auth.expired? && auth.refresh_token.nil?)
      app_info = Google::APIClient::ClientSecrets.load(secrets_path)
      flow = Google::APIClient::InstalledAppFlow.new({
        :client_id => app_info.client_id,
        :client_secret => app_info.client_secret,
        :scope => scope})
      auth = flow.authorize(storage)
      puts "Credentials saved to #{credentials_path}" unless auth.nil?
    end
    auth
  end

  def labels

    # Show the user's labels
    results = @client.execute!(
      :api_method => @gmail_api.users.labels.list,
      :parameters => { :userId => 'me' })

    results.data.labels.map do |label|
      { id: label.id, name: label.name }
    end

  end

  def messages(query="in:inbox is:unread", max=3)

    results = @client.execute!(
      api_method: @gmail_api.users.messages.list,
      parameters: { userId: 'me',
                    q: query,
                    maxResults: max,
                  })

    results.data.messages.map do |message|

      response = @client.execute!(
        api_method: @gmail_api.users.messages.get,
        parameters: { userId: 'me', id: message["id"]}
      )

      headers = {}
      response.data.payload.headers.each do |header|
        case header.name
        when "From"
          headers[:from] = header.value
        when "Date"
          headers[:date] = header.value
        when "Subject"
          headers[:subject] = header.value
        end
      end

      # look for html body in the payload
      payload = response.data.payload
      data = if payload.parts.count == 1
               payload.parts.first.parts.find { |part| part.mimeType == "text/html"}
             elsif payload.parts.count == 2
               payload.parts.find { |part| part.mimeType == "text/html"}
             end

      # manually decode message from JSON data, since client uses wrong encoding
      html = if data
               json = JSON.parse(data.to_json)["body"]["data"]
               Base64.urlsafe_decode64(json)
             end

      # return basic headers, body and labels
      {
        id: message["id"],
        headers: headers,
        snippet: response.data.snippet,
        body: response.data.payload.body.data,
        html_body: html,
        label_ids: response.data.labelIds
      }

    end

  end

  def add_label(msg_id, label)

    label_id = get_label_id(label)

    @client.execute!(
      api_method: @gmail_api.users.messages.modify,
      parameters: { userId: 'me', id: msg_id },
      body_object: { addLabelIds: [label_id] }
    )

  end

  def remove_label(msg_id, label)

    label_id = get_label_id(label)

    @client.execute!(
      api_method: @gmail_api.users.messages.modify,
      parameters: { userId: 'me', id: msg_id },
      body_object: { removeLabelIds: [label_id] }
    )

  end

  def get_label_id(label)
    result = labels.find { |l| l[:name] == label }
    if result
      return result[:id]
    else
      raise "Label not found"
    end
  end

end


mail = Gmail.new

#puts mail.labels
#mail.remove_label(mail.messages.first[:id], "UNREAD")
puts mail.messages
