require 'rubygems'
require 'watir'
require 'cgi'
require 'time'
require 'date'
require 'mongo'
require 'nokogiri'
require 'pathname'

'''
Example commands to execute script.

Scrape from business registration number 70000000 to 71500000:
> ruby scrape.rb -r 70000000 71500000

Scrape based on business registration numbers listed in a file:
> ruby scrape.rb -f biznumz.txt
'''

Mongo::Logger.logger.level = ::Logger::FATAL

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')

#$collection_businesses = client[:businesses]
#$collection_errors = client[:errors]

$collection_businesses = client[:businesses]
$collection_errors = client[:errors]

# If the error threshold has been met, we terminate the script.
$error_threshold = 10
$sleep_before_retry = 15

def get_registration_num_of_last_scraped_business(num_start, num_end)
    # Get the registration number of the last scraped business.
    # So that we can start off around where we left off if we previously stopped the scraping script.
    doc = $collection_businesses.find({
                'formatted.registrationNum' => {
                    '$exists' => true,
                    '$gte' => num_start,
                    '$lte' => num_end},
            }).sort({
                'formatted.registrationNum' => -1
            }).limit(1).first()

    latest_registration_num = doc == nil ? $registration_num_start : doc['formatted']['registrationNum'] + 1

    latest_registration_num

end

begin
    # Give list of business registrations:
    if ARGV[0] == '-f' or ARGV[0] == '--file'
        $registration_num_array = File.readlines(ARGV[1])

    # Define range of businesses registration to scrape:
    elsif ARGV[0] == '-r' or ARGV[0] == '--range' 
        $registration_num_start = Integer(ARGV[1]) # 70000000
        $registration_num_end = Integer(ARGV[2]) # 71500000

        # Get registration num start, i.e. where the scraping will begin.
        # This is in case we previously strated this range, had to stop, and now are resuming.
        reg_num_start = get_registration_num_of_last_scraped_business($registration_num_start, $registration_num_end)
        $registration_num_array = (reg_num_start..$registration_num_end)
    end

    # Initiate the browser
    $browser = Watir::Browser.new :chrome

rescue => error
    puts error
    puts
    puts 'Usage Error. Try one of the following options:'
    puts 
    puts 'Scrape from business registration number 70000000 to 71500000:'
    puts '> ruby scrape.rb -r 70000000 71500000'
    puts
    puts 'Scrape based on business registration numbers listed in a file:'
    puts '> ruby scrape.rb -f biznumz.txt'
    puts
    
    abort('Program terminated.')
end


def load_arbk_search_page(registration_num)
    error_counter = 0
    browser_goto_has_timeout = true

    while browser_goto_has_timeout

        begin
            $browser.goto 'arbk.rks-gov.net'
            browser_goto_has_timeout = false

        rescue => error
            error_counter += 1

            if error_counter > $error_threshold
                abort_error_message = "Too many failed attempts to load search page: " + error.to_s
                puts abort_error_message
                save_error(registration_num, abort_error_message)

                # Exit program.
                abort("I'm givin' it all she's got, Captain! If I push it any farther, the whole thing'll blow!")

            else

                browser_goto_has_timeout = true

                # Display and save error
                puts error.to_s
                save_error(registration_num, error.to_s)

                # Wait before trying again
                sleep $sleep_before_retry
            end
        end
    end 
end

def load_page_via_anchor_click(registration_num, anchor)
    error_counter = 0
    click_has_timeout = true

    while click_has_timeout

        begin
            anchor.click
            click_has_timeout = false

        rescue => error 
            error_counter += 1

            if error_counter > $error_threshold
                abort_error_message = "Too many failed attempts to load page via anchor click: " + error.to_s
                puts abort_error_message
                save_error(registration_num, abort_error_message)

                # Exit program.
                abort("I'm givin' it all she's got, Captain! If I push it any farther, the whole thing'll blow!")

            else
                click_has_timeout = true

                # Display and save error
                puts error.to_s
                save_error(registration_num, error.to_s)

                # Wait before trying again
                sleep $sleep_before_retry
            end
        end
    end
end 

def scrape()

    # Load ARBK business registration search page
    load_arbk_search_page(-1)

    # Start searching for businesses
    $registration_num_array.each do |biznum|

        begin
            # UI updates as of '18/06/2017'
            # MainContent_ctl00_txtNumriBiznesit --> txtNumriBiznesit
            # MainContent_ctl00_Submit1 --> class: kerko

            # Search for a business based on registration number
            # Sometimes the set doesn't set the whole value so we make sure we try again if that happens.
            $browser.text_field(id: 'txtNumriBiznesit').set ''
            while $browser.text_field(id: 'txtNumriBiznesit').value.length != '70000000'.length
                $browser.text_field(id: 'txtNumriBiznesit').set biznum
            end

            $browser.button(class: 'kerko').click

            # If there is a result, there will be result table with a single row and a link
            anchor = $browser.a(:xpath => "//table[@class='views-table cols-4']/tbody//td/a")

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
                biz_status = $browser.tds(:xpath => "//table[@class='views-table cols-4']/tbody//td")[5].text
                biz_arbk_url = anchor.href

                # Indicate in console that we found a business
                puts 'Business found: ' + biz_name + ' (' + biz_status + '): ' + biz_arbk_url

                # Click on the link to load busines info page on arbk's website.
                load_page_via_anchor_click(biznum, anchor)

                # Navigate all the table, row by row, and extract the data all while building a json document that will be stored in the databse.
                table_section_spans = $browser.spans(:xpath => "//div[@id='MainContent_ctl00_pnlBizneset']//table[@class='views-table cols-4']//thead//span")

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
                load_arbk_search_page(biznum)
            end
        rescue => error

            # Display and save error
            puts error.to_s
            save_error(biznum, error.to_s)

            # Return to the search page to continue with the next search after an error.
            load_arbk_search_page(biznum)
        end
    end

    $browser.quit
end

def save_error(registration_num, error_msg)
    # Save the registration number that triggered the error.
    $collection_errors.insert_one({
        'registrationNum' => registration_num.to_i,
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
            biz_hash_formatted['registrationNum'] = value.to_i

        elsif key == 'Nr Fiskal' and !value.empty?
            biz_hash_formatted['fiscalNum'] = value.to_i

        elsif key == 'Nr Cerfitikues KTA' and !value.empty?
            biz_hash_formatted['ktaNum'] = value.to_i

        elsif key == 'Nr Punëtorëve' and !value.empty?
            biz_hash_formatted['employeeCount'] = value.to_i

        elsif key == 'Data e konstituimit' and !value.empty?
            biz_hash_formatted['establishmentDate'] = datefy(value)

        elsif key == 'Data e Aplikimit' and !value.empty?
            biz_hash_formatted['applicationDate'] = datefy(value)

        elsif key == 'Komuna' and !value.empty?
            biz_hash_formatted['municipality'] = value
        
        elsif key == 'Kapitali' and !value.empty?
            biz_hash_formatted['capital'] = value.to_f

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
        biz_hash_formatted['activities'].push(key.to_i)

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

# Start scraping
scrape()
