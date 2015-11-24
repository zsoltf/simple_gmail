require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/installed_app'
require 'google/api_client/auth/storage'
require 'google/api_client/auth/storages/file_store'
require 'fileutils'

require 'pry'

class Gmail

  def initialize

    options = {
      app_name: 'Gmail API Ruby Quickstart',
      secrets_path: File.join('config', 'client_secret.json'),
      credentials_path: File.join('config', '.credentials', "gmail-ruby-quickstart.json"),
      scope: 'https://www.googleapis.com/auth/gmail.readonly'
    }

    @client = Google::APIClient.new(application_name: options[:app_name])
    @client.authorization = authorize(options)

    # Initialize the API
    @gmail_api = @client.discovered_api('gmail', 'v1')

  end

  ##
  # Ensure valid credentials, either by restoring from the saved credentials
  # files or intitiating an OAuth2 authorization request via InstalledAppFlow.
  # If authorization is required, the user's default browser will be launched
  # to approve the request.
  def authorize(options)
    credentials_path = options[:credentials_path]
    secrets_path = options[:secrets_path]
    scope = options[:scope]

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

    results.data.labels.map(&:name)

  end

  def messages(query="in:inbox is:unread", max=3)

    results = @client.execute!(
      api_method: @gmail_api.users.messages.list,
      parameters: { userId: 'me',
                    q: query,
                    maxResults: max
                  })

    results.data.messages.map do |message|

      response = @client.execute!(
        api_method: @gmail_api.users.messages.get,
        parameters: { userId: 'me', id: message["id"]}
      ).data.payload

      headers = {}
      response.headers.each do |header|
        case header.name
        when "From"
          headers[:from] = header.value
        when "Date"
          headers[:date] = header.value
        when "Subject"
          headers[:subject] = header.value
        end
      end

      { headers: headers, body: response.body.data }

    end

  end

end


mail = Gmail.new

binding.pry
#puts mail.labels
puts mail.messages
