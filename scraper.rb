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
title_reference = ''

# Step 4: Iterate through each application block and extract the data
doc.css('div.card-body').each_with_index do |application, index|
  logger.info("Extracting data for application ##{index + 1}")

  # Find the table inside the card-body
  table = application.at_css('table.table')
  if table
    # Extract the rows from the table
    rows = table.css('tr')
    logger.info("Rows found: #{rows.size}")

    # Log each row for debugging
    rows.each_with_index do |row, row_index|
      logger.info("Row ##{row_index + 1}: #{row.to_html}")
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
    application_details['Opening Date'] = rows[6].css('td:nth-child(2)').text.strip rescue nil
    application_details['Closing Date'] = rows[7].css('td:nth-child(2)').text.strip rescue nil
    application_details['Documents'] = rows[8].css('td:nth-child(2) a').map { |link| link['href'] }.join(', ') rescue nil

    # Log the extracted data for debugging purposes
    logger.info("Extracted Data: #{application_details}")
    
    # Step 6: Ensure the entry does not already exist before inserting
    existing_entry = db.execute("SELECT * FROM georgetown WHERE council_reference = ?", ['Application ID'])
  
    if existing_entry.empty? # Only insert if the entry doesn't already exist
    # Insert the data into the database
    db.execute("INSERT INTO georgetown (description, address, council_reference, applicant, title_reference, date_received, closing_date) VALUES (?, ?, ?, ?, ?, ?, ?)",
               ['Proposal', 'Location', 'Application ID', 'Applicant Name', 'Title reference', 'Opening Date', 'Closing Date'] )
  
    logger.info("Data for #{description} at #{address} saved to database.")
    else
      logger.info("Duplicate entry for application #{council_reference} found. Skipping insertion.")
    end
  else
    logger.warn("No table found in card body for application ##{index + 1}.")
  end
end

puts "Data has been successfully inserted into the database."
