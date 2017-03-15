require 'rubygems'
require 'watir'
require 'cgi'
require 'time'
require 'date'


def scrape()
    # Initiate the crawl
    browser = Watir::Browser.new :chrome 

    #(70000000..71500000).each do |biznum|
    (70028321..70028321).each do |biznum|

        begin
            # Load search form
            browser.goto 'arbk.rks-gov.net'

            # Search for business number
            browser.text_field(id: 'MainContent_ctl00_txtNumriBiznesit').set biznum
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
                    section_title = table_section_span.inner_html

                    if CGI.unescapeHTML(section_title) == biz_name
                        # Business info
                        biz_hash['raw']['info'].push({
                            'key' => 'Emri',
                            'value' => biz_name
                        })

                        rows = table_section_span.parent.parent.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(rows, biz_hash, 'info')

                    elsif section_title == 'Personat e Autorizuar'
                        # Authorized persons.
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(rows, biz_hash, 'authorized')

                    elsif section_title == 'Pronarë'
                        # Owners
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(rows, biz_hash, 'owners')

                    elsif section_title == 'Aktivitet/et'
                        # Activities
                        rows = table_section_span.parent.parent.parent.parent.tbody.trs
                        fetch_row_data(rows, biz_hash, 'activities')

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

                # TODO: persist business info JSON in database
                puts biz_hash
            end
        rescue => error
            # TODO: log error
            puts 'An error has occured.'
            puts error
        end
    end

    browser.quit
end

def save_error(registrationNum)
    # Save the registration number that triggered the error.
    'hello'
end

def save_business_data(biz_hash)
    # Save the business data in database.
    'hello'
end

def fetch_row_data(rows, biz_hash, parent_key)
    # Fetch data from HTML table row
    rows.each do |row|
        if row.tds()[0].exists? and row.tds()[1].exists?
            biz_hash['raw'][parent_key].push({
                'key' => row.tds()[0].text.strip,
                'value' => row.tds()[1].text.strip
            })

            format_data(biz_hash['formatted'], parent_key, row.tds()[0].text.strip, row.tds()[1].text.strip)
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

scrape()
