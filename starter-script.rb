require "google/api_client"
require "google_drive"

require "mechanize"

require "pry"


# Apps Credentials

secrets = JSON[File.read("./keys.json")]

service_account_email = secrets['service_account_email']
key_file = secrets['key_file']
key_secret = secrets['key_secret']
user_email = 'corbin.page@gmail.com'

# Authorize and get key
key = Google::APIClient::PKCS12.load_key(key_file, key_secret)

# Get the Google API client
client = Google::APIClient.new(:application_name => 'lis-pendens', 
                               :application_version => '0.01')

client.authorization = Signet::OAuth2::Client.new(
                                                  :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
                                                  :audience => 'https://accounts.google.com/o/oauth2/token',
                                                  :scope => "https://www.googleapis.com/auth/drive " +
                                                  "https://docs.google.com/feeds/ " +
                                                  "https://docs.googleusercontent.com/ " +
                                                  "https://spreadsheets.google.com/feeds/",
                                                  :issuer => service_account_email,
                                                  :signing_key => key)
client.authorization.fetch_access_token!
access_token = client.authorization.access_token

# --------------------------------------------------------
# --------------------------------------------------------
# --------------------------------------------------------

##
# Insert a new permission
#
# @param [Google::APIClient] client
#   Authorized client instance
# @param [String] file_id
#   ID of the file to insert permission for.
# @param [String] value
#   User or group e-mail address, domain name or nil for 'default' type
# @param [String] perm_type
#   The value 'user', 'group', 'domain' or 'default'
# @param [String] role
#   The value 'owner', 'writer' or 'reader'
# @return [Google::APIClient::Schema::Drive::V2::Permission]
#   The inserted permission if successful, nil otherwise
def insert_permission(client, file_id, value, perm_type, role)

  drive = client.discovered_api('drive', 'v2')
  new_permission = drive.permissions.insert.request_schema.new({
    'value' => value,
    'type' => perm_type,
    'role' => role
    })
  result = client.execute(
                          :api_method => drive.permissions.insert,
                          :body_object => new_permission,
                          :parameters => { 'fileId' => file_id })
  if result.status == 200
    return result.data
  else
    puts "An error occurred: #{result.data['error']['message']}"
  end
end

##
# Update a permission's role
#
# @param [Google::APIClient] client
#   Authorized client instance
# @param [String] file_id
#   ID of the file to update permission for
# @param [String] permission_id
#   ID of the permission to update
# @param [String] new_role
#   The value 'owner', 'writer' or 'reader'
# @return [Google::APIClient::Schema::Drive::V2::Permission]
#   The updated permission if successful, nil otherwise
def update_permission(client, file_id, permission_id, new_role)

  drive = client.discovered_api('drive', 'v2')# First retrieve the permission from the API.
  result = client.execute(
                          :api_method => drive.permissions.get,
                          :parameters => {
                            'fileId' => file_id,
                            'permissionId' => permission_id
                            })
  if result.status == 200
    permission = result.data
    permission.role = new_role
    result = client.execute(
                            :api_method => drive.permissions.update,
                            :body_object => updated_permission,
                            :parameters => {
                              'fileId' => file_id,
                              'permissionId' => permission_id
                              })
    if result.status == 200
      return result.data
    end
  end
  puts "An error occurred: #{result.data['error']['message']}"
end

##
# Create a new file
#
# @param [Google::APIClient] client
#   Authorized client instance
# @param [String] title
#   Title of file to insert, including the extension.
# @param [String] description
#   Description of file to insert
# @param [String] parent_id
#   Parent folder's ID.
# @param [String] mime_type
#   MIME type of file to insert
# @param [String] file_name
#   Name of file to upload
# @return [Google::APIClient::Schema::Drive::V2::File]
#   File if created, nil otherwise
def insert_file(client, title, description, parent_id, mime_type, file_name)
  drive = client.discovered_api('drive', 'v2')
  file = drive.files.insert.request_schema.new({
    'title' => title,
    'description' => description,
    'mimeType' => mime_type
    })
  # Set the parent folder.
  if parent_id
    file.parents = [{'id' => parent_id}]
  end
  media = Google::APIClient::UploadIO.new(file_name, mime_type)
  result = client.execute(
                          :api_method => drive.files.insert,
                          :body_object => file,
                          :media => media,
                          :parameters => {
                            'uploadType' => 'multipart',
                            'alt' => 'json',
                            'convert' => true})
  if result.status == 200
    return result.data
  else
    puts "An error occurred: #{result.data['error']['message']}"
    return nil
  end
end

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

# Creates a new Google Spreadsheet and permissions corbin.page@gmail.com to see it
# file_result = insert_file(client, 'lis-pendens-output', 'Contains information about Lis Pendens Projects', false, 'text/csv', 'lis-pendens-output.csv')
# permission_result = insert_permission(client, file_result["id"], 'corbin.page@gmail.com', 'user', 'writer')
# puts file_result["id"]

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

# doc_id = '1t6-1WtYW9AeFf1P3LbgO9-mqO5UpH8tDSNNwoBtyCL0'

# session = GoogleDrive.login_with_oauth(access_token)
# ws = session.spreadsheet_by_key(doc_id).worksheets[0]
# # puts ws[1, 1]  #==> "hoge"

# column_names = ws.list.keys

# # puts column_names

# new_data = {}

# column_names.each_with_index do |n,i|
#   new_data[n] = i.to_s
# end

# puts new_data.inspect

# ws.list.push (new_data)
# ws.save

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

a = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
}

a.get('https://www2.miami-dadeclerk.com/officialrecords/Search.aspx') do |page|
  search_result = page.form_with(:name => 'aspnetForm') do |search|
    search["ctl00$ContentPlaceHolder1$tcStandar$tpNameSearch$pfirst_partySTD"] = 'TD Bank'
  end.click_button

  search_result.links.each do |link|
    puts link.text
  end
end







# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

# a = Mechanize.new { |agent|
#   agent.user_agent_alias = 'Mac Safari'
# }

# a.get('http://google.com/') do |page|
#   search_result = page.form_with(:name => 'f') do |search|
#     binding.pry
#     search.q = 'Hello world'
#   end.submit

#   search_result.links.each do |link|
#     puts link.text
#   end
# end

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

















