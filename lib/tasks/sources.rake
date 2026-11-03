# frozen_string_literal: true

namespace :sources do
  desc "Add a Source and fetch it immediately: bin/rails 'sources:add[URL,NAME]' (NAME optional)"
  task :add, [ :url, :name ] => :environment do |_task, args|
    source = Source.new(url: args[:url], name: args[:name])
    abort "Could not add Source: #{source.errors.full_messages.to_sentence}" unless source.save

    fetch = source.fetch
    abort "Added #{source.display_name}, but the first fetch failed: #{fetch.error}" unless fetch.success?

    count = fetch.new_entries_count
    puts "Added #{source.display_name}: #{count} #{'Entry'.pluralize(count)} stored"
  end

  desc "Remove a Source and its Entries: bin/rails 'sources:remove[URL]'"
  task :remove, [ :url ] => :environment do |_task, args|
    source = Source.find_by(url: args[:url])
    abort "No Source with URL #{args[:url].inspect}. See bin/rails sources:list" unless source

    removal = SourceRemover.perform(source)
    deleted = removal.deleted_entries_count
    message = "Removed #{source.display_name}: #{deleted} #{'Entry'.pluralize(deleted)} deleted"
    message += ", #{removal.promoted_count} Duplicate(s) from other Sources promoted to Original" if removal.promoted_count.positive?
    puts message
  end

  desc "List Sources with their last fetch time, last error and Entry count"
  task list: :environment do
    sources = Source.left_joins(:entries).group(:id).select("sources.*, COUNT(entries.id) AS entries_count").order(:name, :url)
    if sources.empty?
      puts "No Sources. Add one with: bin/rails 'sources:add[URL,NAME]'"
      next
    end

    format_time = ->(time) { time ? time.to_fs(:db) : "never" }
    sources.each do |source|
      puts source.display_name
      puts "  URL:          #{source.url}"
      puts "  Last fetched: #{format_time.(source.last_fetched_at)}"
      puts "  Last error:   #{source.last_error ? "#{source.last_error} (#{format_time.(source.last_error_at)})" : 'none'}"
      puts "  Entries:      #{source.entries_count}"
    end
  end
end
