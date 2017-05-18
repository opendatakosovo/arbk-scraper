require 'mongo'

# Establish connection to database
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'arbk')
$collection_businesses = client[:businesses]


def fix()
    fix_count = 0
    businesses = $collection_businesses.find().each { |business|
        catch :problematic do
            id = business['_id']
            regnum = business['formatted']['registrationNum'].to_s
            activities = business['raw']['activities'] 
            activities.each { |activity|
                if activity['key'].start_with?('0')
                    fix_formatted_activities(id, regnum, activities)
                    fix_count += 1
                    throw :problematic
                end
            }
        end
    }

    puts 'Fixed ' + fix_count.to_s + ' documents.'
end

def fix_formatted_activities(id, regnum, activities)
    activity_codes = []

    activities.each { |activity|
        if !activity['key'].empty?
            activity_codes.push(activity['key'].to_i)
        else
            puts 'WARNING: Something\'s up with ' + regnum
        end
    }

    # Update/fix document
    $collection_businesses.update_one(
        {'_id' => id},
        {'$set' => {'formatted.activities' => activity_codes}})
end

fix()