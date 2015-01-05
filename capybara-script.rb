require "google/api_client"
require "google_drive"

require 'capybara'
require 'capybara/poltergeist'
require 'selenium-webdriver'

require "pry"

# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

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

def write_list_entry_to_spreadsheet(session, new_entry)
  doc_id = '1t6-1WtYW9AeFf1P3LbgO9-mqO5UpH8tDSNNwoBtyCL0'
  if session.nil?
    puts "Google Docs connection failed.."
    puts "Entry data will not be written.."
    puts new_entry.inspect
    false
  else
    worksheet = session.spreadsheet_by_key(doc_id).worksheets[0]
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
  select("400", from: "ctl00_ContentPlaceHolder1_gvResults_ctl13_ddlPageSize")
  puts "Got Results.."
rescue Net::ReadTimeout
  puts "Timed out"
end

tr_array = all("table.gvResults tr")


tr_array.each_with_index do |tr, i|
  unless i == 0 || i == tr_array.count-1
    new_entry = create_new_entry(tr, "Dade", "FL")
    # session = GoogleDrive.login_with_oauth(access_token)
    session = nil
    write_list_entry_to_spreadsheet(session, new_entry)
  end
end
