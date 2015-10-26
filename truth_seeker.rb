require "open-uri"
require "json"
require "fileutils"

def page_content(url)
  JSON.parse(open(url).read)
end

def sleep_if_rate_limit(type: "search")
  puts "Forced sleep"
  sleep 5
  puts "Checking rate limit for #{type}"
  content = page_content("https://api.github.com/rate_limit")
  current = content["resources"][type]
  if current["remaining"] == 0
    delay = (current["reset"].to_i - Time.now.to_i) + 1
    puts "Rate limit reached: sleeping for #{delay}"
    sleep delay
    sleep_if_rate_limit(type: type)
  end
end

def api_results(url:)
  more_results = true
  page_index = 0
  results = []
  while more_results
    sleep_if_rate_limit(type: "search")
    puts "Fetching page #{page_index}"
    content = page_content(url)
    more_results = content.keys.include?("total_count")
    results += content["items"].map do |item|
      yield item
    end
    page_index += 1
  end
  results
end

def data_step(filename:)
  if File.exists?(filename)
    JSON.parse(File.read(filename))
  else
    results = yield
    File.write(filename, results.to_json)
    results
  end
end

repositories = data_step(filename: "repositories.json") do
  puts "Fetching repositories"
  repo_search_url = "https://api.github.com/search/repositories?q=language:javascript&sort=stars&order=desc"
  api_results(url: repo_search_url) do |item|
    item["full_name"]
  end
end

file_urls = data_step(filename: "file_urls.json") do
  puts "Fetching file urls"
  repositories.map do |repository|
    sleep_if_rate_limit(type: "search")
    puts "Searching file for repository #{repository}"
    file_search_url = "https://api.github.com/search/code?q=language:js+extension:js+repo:#{repository}"
    content = page_content(file_search_url)
    content["items"][0]["url"]
  end
end

download_urls = data_step(filename: "download_urls.json") do
  puts "Fetching download urls"
  file_urls.map do |file_url|
    sleep_if_rate_limit(type: "core")
    puts "Fetching file data #{file_url}"
    page_content(file_url)["download_url"]
  end
end

FileUtils.mkdir_p "files"
puts "Downloading source file"
download_urls.map do |download_url|
  sleep_if_rate_limit(type: "core")
  puts "Downloading file #{download_url}"
  File.write("files/#{File.basename(download_url)}", open(download_url).read)
end
