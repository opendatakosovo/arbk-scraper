require 'mongo'
require 'FileUtils'

'''
    Sometimes during the scraping process, errors were thrown.
    These errors were saved in the database, with information on the business
    registration number with which the error was triggered.

    This script basically goes through all those documented errors and lists
    their associated business registration numbers in a txt file.

    The txt file can then be loaded in the scraping script in order to re-scrape
    the concerned data thus making sure that not data was omitted due to errors.
'''

Mongo::Logger.logger.level = ::Logger::FATAL

# name of file listing all the business registration numbers we should recheck.
error_filename = 'retry.txt'

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')
$collection_businesses = client[:businesses]
$collection_errors = client[:errors]

error_id_substrings_to_skip = ['browser window was closed','code=404']


all_error_reg_nums = $collection_errors.distinct('registrationNum')

# Get different error types.
error_types = $collection_errors.aggregate([{
    '$group' => {
        '_id' => '$errorMsg',
        'count' => {'$sum' => 1} }
    }])

# Display summary/stats of error types.
for error_type in error_types
    if not (error_type['_id'].include?(error_id_substrings_to_skip[0]) or error_type['_id'].include?(error_id_substrings_to_skip[1]))
        puts
        puts
        puts 'Checking for following error:'
        puts '-----------------------------'
        puts error_type['_id']
        puts

        # These are all the errors recorded.
        error_reg_nums = $collection_errors.distinct('registrationNum', {
            'errorMsg' => error_type['_id'],
            'registrationNum' => {'$gt' => 0}})

        # These are all the errors that have been recovered.
        recovered_error_reg_nums = $collection_businesses.distinct('formatted.registrationNum', {
            'formatted.registrationNum' => {
                '$in' => error_reg_nums
            }
        })

        # There are all the errors that we are not sure have been recovered so we need to try again
        unrecovered_error_reg_nums = $collection_errors.distinct('registrationNum', {
                'errorMsg' => error_type['_id'],
                'registrationNum' => {
                    '$nin' => recovered_error_reg_nums
                }
            })

        # Compilre all reg nums we should retry:
        File.open(error_filename, 'a') do |f|
            f.puts(unrecovered_error_reg_nums)
        end

        puts 'Number of errors triggered: ' + error_reg_nums.length.to_s
        puts 'Number of errors recovered: ' + recovered_error_reg_nums.length.to_s
        puts 'Number of errors requiring checking: ' + unrecovered_error_reg_nums.length.to_s
        puts
        puts
    end
end


