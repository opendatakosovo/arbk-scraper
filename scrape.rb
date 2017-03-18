require 'rubygems'
require 'watir'
require 'cgi'
require 'time'
require 'date'
require 'mongo'
require 'nokogiri'

Mongo::Logger.logger.level = ::Logger::FATAL

# Get bussiness registration number range to scrape
begin
    $registration_num_start = Integer(ARGV[0]) # 70000000
    $registration_num_end = Integer(ARGV[1]) # 71500000

rescue => error
    puts 'Error inputting bussiness registration number range to scrape: using default [70000000, 71500000].'
    $registration_num_start = 70000000
    $registration_num_end = 71500000
end

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')
$collection_businesses = client[:businesses]
$collection_errors = client[:errors]

# Start scraping
scrape()

def get_registration_num_of_last_scraped_business
    # Get the registrationa number of the last scraped business.
    # So that we can start off around where we left off if we previously stopped the scraping script.
    doc = $collection_businesses.find({
                'formatted.registrationNum' => {'$exists' => true}
            }).sort({
                'formatted.registrationNum' => -1
            }).limit(1).first()

    latest_registration_num = doc == nil ? $registration_num_start : doc['formatted']['registrationNum']

    latest_registration_num

end

def scrape()
    # Get registration num start, i.e. where the scraping will begin.
    reg_num_start = get_registration_num_of_last_scraped_business


    # Initiate the crawl
    browser = Watir::Browser.new :chrome

    # Load ARBK business registration search page
    browser.goto 'arbk.rks-gov.net'

    # Start searching for businesses
    (reg_num_start..$registration_num_end).each do |biznum|

        begin

            # Search for a business based on registration number
            # Sometimes the set doesn't set the whole value so we make sure we try again if that happens.
            browser.text_field(id: 'MainContent_ctl00_txtNumriBiznesit').set ''
            while browser.text_field(id: 'MainContent_ctl00_txtNumriBiznesit').value.length != '70000000'.length
                browser.text_field(id: 'MainContent_ctl00_txtNumriBiznesit').set biznum
            end

            browser.button(id: 'MainContent_ctl00_Submit1').click

            # If there is a result, there will be result table with a single row and a link
            anchor = browser.a(:xpath => "//table[@class='views-table cols-4']/tbody//td/a")

            # If the lin does exist, the load the business page
            if anchor.exists?

                # Prepare the business data container (hashmap)
                biz_hash = {
                    'raw' => {
                        'info' => [],
                        'authorized' => [],
                        'owners' => [],
                        'activities' => []
                    },
                    'formatted' => {
                        'owners' => [],
                        'authorized' => [],
                        'activities' => []
                    } 
                }

                # Get some data already
                biz_name = CGI.unescapeHTML(anchor.text.strip)
                biz_status = browser.tds(:xpath => "//table[@class='views-table cols-4']/tbody//td")[5].text
                biz_arbk_url = anchor.href

                # Indicate in console that we found a business
                puts 'Business found: ' + biz_name + ' (' + biz_status + '): ' + biz_arbk_url

                # Click on the lin to load busines info page on arbk's website.
                anchor.click

                # Navigate all the table, row by row, and extract the data all while building a json document that will be stored in the databse.
                table_section_spans = browser.spans(:xpath => "//div[@id='MainContent_ctl00_pnlBizneset']//table[@class='views-table cols-4']//thead//span")

                table_section_spans.each do |table_section_span|
                    section_title = table_section_span.text.strip

                    if CGI.unescapeHTML(section_title) == biz_name
                        # Business info
                        biz_hash['raw']['info'].push({
                            'key' => 'Emri',
                            'value' => biz_name
                        })

                        rows = table_section_span.parent.parent.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(biznum, rows, biz_hash, 'info')

                    elsif section_title == 'Personat e Autorizuar'
                        # Authorized persons.
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(biznum, rows, biz_hash, 'authorized')

                    elsif section_title == 'Pronarë'
                        # Owners
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(biznum, rows, biz_hash, 'owners')

                    elsif section_title == 'Aktivitet/et'
                        # Activities
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(biznum, rows, biz_hash, 'activities')

                    else
                        # do nothing
                    end 
                end

                # We now have a business registration document.
                # let's add some extra formatted data in order to simplify queries.
                biz_hash['formatted']['timestamp'] = Time.now.getutc
                biz_hash['formatted']['name'] = biz_name
                biz_hash['formatted']['status'] = biz_status
                biz_hash['formatted']['arbkUrl'] = biz_arbk_url

                save_business_data(biz_hash)

                # Return to the search page for the next search.
                browser.goto 'arbk.rks-gov.net'
            end
        rescue => error

            # Display and save error
            puts error.to_s
            save_error(biznum, error.to_s)

            # Return to the search page to continue with the next search after an error.
            browser.goto 'arbk.rks-gov.net'
        end
    end

    browser.quit
end

def save_error(registration_num, error_msg)
    # Save the registration number that triggered the error.
    $collection_errors.insert_one({
        'registrationNum' => intify(registration_num),
        'errorMsg' => error_msg
        })
end

def save_business_data(biz_hash)
    # Save the business data in database.
    $collection_businesses.insert_one(biz_hash)
end

def fetch_row_data(biznum, rows, biz_hash, parent_key)
    # Fetch data from HTML table row
    rows.each do |row|

        # Parsing HTML with Nokogiri enable much more efficient access to data than navigating through Watir elements.
        noko_row = Nokogiri::HTML(row.html)

        # In the 'info' table we have (key, val) = (<b/>, <span/>).
        # In the other tables we have (key, val) = (<span/>), <span/>).
        # Because of this inconsistency, we need to carefully apply xpath and index values.
        key_elem = noko_row.xpath(parent_key == 'info' ? './/b' : './/span')[0]
        val_elem = noko_row.xpath('.//span')[parent_key == 'info' ? 0 : 1]

        if key_elem != nil and val_elem != nil

            key = key_elem.text.strip.gsub(/\s+/, ' ')
            val = val_elem.text.strip.gsub(/\s+/, ' ')

            biz_hash['raw'][parent_key].push({
                'key' => key,
                'value' => val,
            })

            format_data(biz_hash['formatted'], parent_key, key, val)

        else
            error_msg = 'Failed to fetch row data in ' + parent_key + ' section.'
            save_error(biznum, error_msg)

        end
    end
end

def format_data(biz_hash_formatted, parent_key, key, value)
    # format the data to make it easier to query.

    if parent_key == 'info'

        if key == 'Lloji Biznesit' and !value.empty?
            biz_hash_formatted['type'] = value

        elsif key == 'Nr Regjistrimit' and !value.empty?
            biz_hash_formatted['registrationNum'] = intify(value)

        elsif key == 'Nr Fiskal' and !value.empty?
            biz_hash_formatted['fiscalNum'] = intify(value)

        elsif key == 'Nr Cerfitikues KTA' and !value.empty?
            biz_hash_formatted['ktaNum'] = intify(value)

        elsif key == 'Nr Punëtorëve' and !value.empty?
            biz_hash_formatted['employeeCount'] = intify(value)

        elsif key == 'Data e konstituimit' and !value.empty?
            biz_hash_formatted['establishmentDate'] = datefy(value)

        elsif key == 'Data e Aplikimit' and !value.empty?
            biz_hash_formatted['applicationDate'] = datefy(value)

        elsif key == 'Komuna' and !value.empty?
            biz_hash_formatted['municipality'] = value
        
        elsif key == 'Kapitali' and !value.empty?
            biz_hash_formatted['capital'] = foatify(value)

        elsif key == 'Statusi në ATK' and !value.empty?
            biz_hash_formatted['atkStatus'] = value

        else
            # do nothing
        end

    elsif parent_key == 'owners' and !value.empty?
        biz_hash_formatted['owners'].push(value)

    elsif parent_key == 'authorized'
        biz_hash_formatted['authorized'].push(key)

    elsif parent_key == 'activities'
        biz_hash_formatted['activities'].push(intify(key))

    else
        # do nothing
    end

end

def datefy(value)
    # Cast String to Date type
    begin 
        date_array = value.split('.')
        Time.parse(DateTime.new(date_array[0].to_i, date_array[1].to_i, date_array[2].to_i).to_s)
    rescue ArgumentError
        value
    end
end

def foatify(value)
    # Cast String to Float type
    begin
        Float(value)
    rescue ArgumentError
        value
    end
end

def intify(value)
    # Cast String to Integer type
    begin
        Integer(value)
    rescue ArgumentError
        value
    end
end
