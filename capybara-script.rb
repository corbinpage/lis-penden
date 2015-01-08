require "google/api_client"
require "google_drive"

require 'capybara'
require 'capybara/poltergeist'
require 'selenium-webdriver'

require "pry"

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

begin

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

  session = GoogleDrive.login_with_oauth(access_token)

rescue
  puts "Failed to connect to Google Docs."
end

def create_new_entry(tr, county, state)
  new_entry = {}

  new_entry["Clerk File Number"] = tr.find("td:nth-child(2) a").text
  new_entry["Link"] = tr.find("td:nth-child(2) a")[:href]
  new_entry["Date Posted"] = tr.find("td:nth-child(4)").text
  new_entry["First Party"] = tr.find("td:nth-child(10) span:nth-child(1)").text
  new_entry["Date Added"] = Time.now 
  new_entry["County"] = county
  new_entry["State"] = state

  new_entry
end

def get_lis_pendens_worksheet(session)
  doc_id = '1t6-1WtYW9AeFf1P3LbgO9-mqO5UpH8tDSNNwoBtyCL0'
  session.nil? ? nil : session.spreadsheet_by_key(doc_id).worksheets[0]
end

def write_list_entry_to_worksheet(worksheet, new_entry)
  if worksheet.nil?
    puts new_entry.inspect
    false
  else
    worksheet.list.push(new_entry)
    worksheet.save
  end
end

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------


include Capybara::DSL
Capybara.default_driver = :selenium

# Tom's Code
# Capybara.register_driver :poltergeist do |app|
#   Capybara::Poltergeist::Driver.new(app, phantomjs_logger: WarningSuppressor, phantomjs_options: ['--ssl-protocol=any'])
# end
# Capybara.default_driver = :poltergeist
# Capybara.javascript_driver = :poltergeist 

visit "https://www2.miami-dadeclerk.com/officialrecords/Search.aspx"

fill_in("ctl00_ContentPlaceHolder1_tcStandar_tpNameSearch_pfirst_partySTD", with: "Bank")
fill_in("ctl00_ContentPlaceHolder1_tcStandar_tpNameSearch_prec_date_fromSTD", with: "12/1/2014")
select("LIS PENDENS - LIS", from: "ctl00_ContentPlaceHolder1_tcStandar_tpNameSearch_pdoc_typeSTD")

begin
  click_button("ctl00_ContentPlaceHolder1_tcStandar_tpNameSearch_btnNameSearch")
  # select("400", from: "ctl00_ContentPlaceHolder1_gvResults_ctl13_ddlPageSize")
  puts "Got to the Results Page.."

  tr_array = all("table.gvResults tr")

  unless tr_array.nil?
    worksheet = get_lis_pendens_worksheet(session)

    tr_array.each_with_index do |tr, i|
      unless i == 0 || i == tr_array.count-1
        new_entry = create_new_entry(tr, "Dade", "FL")
        write_list_entry_to_worksheet(worksheet, new_entry)
      end
    end

  else
    puts "No results found.."
  end

rescue Net::ReadTimeout
  puts "Connection Timed out"
end
