require 'nokogiri'
require 'open-uri'
require 'sqlite3'
require 'logger'
require 'uri'

# Initialize the logger
logger = Logger.new(STDOUT)

# Define the URL of the page
url = 'https://georgetown.tas.gov.au/development-applications/'

# Step 1: Fetch the page content using open-uri
begin
  logger.info("Fetching page content from: #{url}")
  page_html = open(url).read
  logger.info("Successfully fetched page content.")
rescue => e
  logger.error("Failed to fetch page content: #{e}")
  exit
end

# Step 2: Parse the page content using Nokogiri
doc = Nokogiri::HTML(page_html)

# Step 3: Inspect the HTML structure of a specific application card for debugging
#applications = doc.css('div.row.py-4.map-address .card-body')

# Print out the raw HTML of the first application block for debugging purposes
#logger.info("First application HTML block: #{applications.first.to_html}")

# Print out a snippet of the HTML for debugging
# logger.info("HTML Content snippet: #{doc.to_html[0..500]}")

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create the table if it doesn't exist
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS georgetown (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_received TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    title_reference TEXT,
    closing_date TEXT,
    document_description TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
date_received = ''
closing_date = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = ''

# Step 4: Iterate through each application block and extract the data
doc.css('div.row.py-4.map-address .card-body').each do |application|
  # Extract the application details from the rows
  application_details = {}
  
  application.css('table tbody tr').each do |row|
    # Extract the label and value for each row
    label = row.at_css('td:nth-child(1)').text.strip
    value = row.at_css('td:nth-child(2)').text.strip

    # Log the extracted label and value for debugging
    logger.info("Row Label: #{label}, Value: #{value}")

    # Store the extracted data in the hash with the label as the key
    application_details[label] = value
  end

  # Log the full extracted application details
  logger.info("Full Application Details: #{application_details}")

  # Extract specific fields
  description = application_details['Proposal']
  address = application_details['Location']
  council_reference = application_details['Application ID']
  applicant = application_details['Applicant Name']
  title_reference = application_details['Title reference']
  date_received = application_details['Opening Date']
  closing_date = application_details['Closing Date']
  document_description = application_details['Documents']

  # Log the extracted data for clarity
  logger.info("Extracted Data: #{description}, #{address}, #{council_reference}, #{applicant}, #{title_reference}, #{date_received}, #{closing_date}, #{document_description}")


  # Step 6: Ensure the entry does not already exist before inserting
  existing_entry = db.execute("SELECT * FROM georgetown WHERE council_reference = ?", [council_reference])

  if existing_entry.empty? # Only insert if the entry doesn't already exist
  # Insert the data into the database
  db.execute("INSERT INTO georgetown (description, address, council_reference, applicant, title_reference, date_received, closing_date, document_description) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
             [description, address, council_reference, applicant, title_reference, date_received, closing_date, document_url])

  logger.info("Data for #{description} at #{address} saved to database.")
  else
    logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
  end
end

puts "Data has been successfully inserted into the database."
