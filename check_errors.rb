require 'mongo'
require 'FileUtils'

Mongo::Logger.logger.level = ::Logger::FATAL

# name of file listing all the business registration numbers we should recheck.
error_filename = 'retry.txt'

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')
$collection_businesses = client[:businesses]
$collection_errors = client[:errors]

error_types_to_skip = ['browser window was closed']


all_error_reg_nums = $collection_errors.distinct('registrationNum')

# Get different error types.
error_types = $collection_errors.aggregate([{
    '$group' => {
        '_id' => '$errorMsg',
        'count' => {'$sum' => 1} }
    }])

# Display summary/stats of error types.
for error_type in error_types
    if not error_types_to_skip.include?(error_type['_id'])
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


