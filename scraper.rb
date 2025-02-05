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

# Step 3: Initialize the SQLite database
db = SQLite3::Database.new "data.sqlite"

# Create the table if it doesn't exist
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS georgetown (
    id INTEGER PRIMARY KEY,
    description TEXT,
    date_scraped TEXT,
    date_received TEXT,
    on_notice_to TEXT,
    address TEXT,
    council_reference TEXT,
    applicant TEXT,
    owner TEXT,
    stage_description TEXT,
    stage_status TEXT,
    document_description TEXT
  );
SQL

# Define variables for storing extracted data for each entry
address = ''  
description = ''
on_notice_to = ''
date_received = ''
council_reference = ''
applicant = ''
owner = ''
stage_description = ''
stage_status = ''
document_description = ''
date_scraped = ''

# Step 4: Iterate through each application block and extract the data
doc.css('div.card-body').each_with_index do |application, index|
  # logger.info("Extracting data for application ##{index + 1}")

  # Find the table inside the card-body
  table = application.at_css('table.table')
  if table
    # Extract the rows from the table
    rows = table.css('tr')
    # logger.info("Rows found: #{rows.size}")

    # Log each row for debugging
    rows.each_with_index do |row, row_index|
      # logger.info("Row ##{row_index + 1}: #{row.to_html}")
    end

    # Skip if no rows were found
    next if rows.empty?

    # Extract the data from the table rows
    application_details = {}

    # Make sure to extract the right text from the rows using correct indices
    application_details['Application ID'] = rows[0].css('td:nth-child(2)').text.strip rescue nil
    application_details['Applicant Name'] = rows[1].css('td:nth-child(2)').text.strip rescue nil
    application_details['Location'] = rows[2].css('td:nth-child(2)').text.strip rescue nil
    application_details['Proposal'] = rows[3].css('td:nth-child(2)').text.strip rescue nil
    application_details['Title reference'] = rows[4].css('td:nth-child(2)').text.strip rescue nil
    application_details['Notes'] = rows[5].css('td:nth-child(2)').text.strip rescue nil
    application_details['Opening Date'] = Date.strptime(rows[6].css('td:nth-child(2)').text.strip, '%d %B %Y').strftime('%Y-%m-%d') rescue nil
    application_details['Closing Date'] = Date.strptime(rows[7].css('td:nth-child(2)').text.strip, '%d %B %Y').strftime('%Y-%m-%d') rescue nil
    application_details['Documents'] = rows[8].css('td:nth-child(2) a').map { |link| link['href'] }.join(', ') rescue nil
    date_scraped = Date.today.to_s

    # Log the extracted data for debugging purposes
    # logger.info("Extracted Data: #{application_details}")
    
    # Step 6: Ensure the entry does not already exist before inserting
    existing_entry = db.execute("SELECT * FROM georgetown WHERE council_reference = ?", application_details['Application ID'] )
  
    if existing_entry.empty? # Only insert if the entry doesn't already exist
    # Insert the data into the database
    db.execute("INSERT INTO georgetown (description, address, council_reference, applicant, title_reference, date_received, closing_date, document_description, date_scraped) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
             [application_details['Proposal'], application_details['Location'], application_details['Application ID'], application_details['Applicant Name'], application_details['Title reference'], application_details['Opening Date'], application_details['Closing Date'], application_details['Documents'], date_scraped])

    logger.info("Data for application #{application_details['Application ID']} saved to database.")
    else
      logger.info("Duplicate entry for application #{application_details['Application ID']} found. Skipping insertion.")
    end
  else
    logger.warn("No table found in card body for application ##{index + 1}.")
  end
end

puts "Data has been successfully inserted into the database."
