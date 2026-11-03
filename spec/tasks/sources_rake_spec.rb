require "rails_helper"
require "rake"

RSpec.describe "sources rake tasks" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.none? { |task| task.name == "sources:add" } }

  let(:url) { "https://blog.example.com/feed.xml" }

  def run_add(*args)
    task = Rake::Task["sources:add"]
    task.reenable
    task.invoke(*args)
  end

  describe "sources:add" do
    it "adds the Source, fetches it immediately and reports how many Entries were stored" do
      stub_request(:get, url).to_return(body: file_fixture("feeds/rss2.xml").read)

      expect { run_add(url, "Example Blog") }.to output("Added Example Blog: 2 Entries stored\n").to_stdout

      expect(Source.find_by!(url: url).entries.count).to eq(2)
    end

    it "rejects a URL that is already registered" do
      Source.create!(url: url)

      expect { run_add(url) }.to raise_error(SystemExit).and output(/Url has already been taken/).to_stderr
      expect(Source.count).to eq(1)
    end
  end
end
