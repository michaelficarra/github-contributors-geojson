require 'geocoder'
require 'octokit'
require 'parallel'
require 'slop'

opts = Slop.parse do |o|
    o.banner = "usage: #{$0} github_org[/repo_name]"
    o.string '-i', '--id', 'GitHub application client ID'
    o.string '-s', '--secret', 'GitHub application client secret'
end

REGEXP = /^([^\/]+)(\/([^\/]+))?$/
github_id = REGEXP.match(opts.arguments.first)

client_id = opts[:id]
client_secret = opts[:secret]
if github_id.nil? || client_id.nil? || client_secret.nil?
    puts opts
    Kernel.exit(1)
end

org_name = github_id[1]
repo_name = github_id[2]
repositories = if repo_name.nil?
    Octokit.repositories(org_name).map(&:full_name)
else
    [github_id]
end

Geocoder.configure(:lookup => :yandex)
Octokit.auto_paginate = true
Octokit.configure do |c|
    c.client_id = client_id
    c.client_secret = client_secret
end

contributors = Parallel.map(repositories) { |repo_name|
    Octokit.contribs(repo_name).map(&:login)
}.flatten.sort.uniq

locations = Parallel.map(contributors) { |login| Octokit.user(login).location }
valid_locations = locations.reject(&:nil?)
STDERR.puts "#{locations.length - valid_locations.length} users have not specified their location"
STDERR.flush

coordinates = Parallel.map(valid_locations) {
    |location| Geocoder.coordinates(location)
}
valid_coordinates = coordinates.reject(&:nil?)
STDERR.puts "#{coordinates.length - valid_coordinates.length} locations could not be geocoded"

puts JSON.pretty_generate({
    :type => "FeatureCollection",
    :features => valid_coordinates.map { |coordinates|
        {
            :type => "Feature",
            :geometry => {
                :type => "Point",
                :coordinates => coordinates.reverse
            }
        }
    }
})
