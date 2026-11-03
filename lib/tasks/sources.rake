namespace :sources do
  desc "Add a Source and fetch it immediately: bin/rails 'sources:add[URL,NAME]' (NAME optional)"
  task :add, [ :url, :name ] => :environment do |_task, args|
    source = Source.new(url: args[:url], name: args[:name])
    abort "Could not add Source: #{source.errors.full_messages.to_sentence}" unless source.save

    begin
      count = source.fetch
      puts "Added #{source.display_name}: #{count} #{'Entry'.pluralize(count)} stored"
    rescue StandardError => e
      abort "Added #{source.display_name}, but the first fetch failed: #{e.message}"
    end
  end
end
