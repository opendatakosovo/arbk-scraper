require 'mongo'

Mongo::Logger.logger.level = ::Logger::FATAL

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')
#$collection_businesses = client[:businesses]
#$collection_errors = client[:errors]
$collection_businesses = client[:businesses]
$collection_errors = client[:errors]

error_types_to_skip = ['browser window was closed']


all_error_reg_nums = $collection_errors.distinct('registrationNum')

# Get different error types:
error_types = $collection_errors.aggregate([{
    '$group' => {
        '_id' => '$errorMsg',
        'count' => {'$sum' => 1} }
    }])


for error_type in error_types
    if not error_types_to_skip.include?(error_type['_id'])
        puts
        puts
        puts 'Checking for following error:'
        puts '-----------------------------'
        puts error_type['_id']
        puts

        error_reg_nums = $collection_errors.distinct('registrationNum', {
            'errorMsg' => error_type['_id'],
            'registrationNum' => {'$gt' => 0}})

        scraped_reg_nums = $collection_businesses.distinct('formatted.registrationNum', {
            'formatted.registrationNum' => {
                '$in' => error_reg_nums
            }
        })

        puts 'Number of errors triggered: ' + error_reg_nums.length.to_s
        puts 'Number of errors recovered: ' + scraped_reg_nums.length.to_s
        puts 'Number of errors requiring checking: ' + (error_reg_nums.length - scraped_reg_nums.length).to_s
        puts
        puts
    end
end