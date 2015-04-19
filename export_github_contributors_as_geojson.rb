require 'geocoder'
require 'octokit'
require 'parallel'
require 'slop'

opts = Slop.parse do |o|
    o.banner = "usage: #{$0} github_repo_name"
    o.string '-i', '--id', 'GitHub application client ID'
    o.string '-s', '--secret', 'GitHub application client secret'
end

repo_name = opts.arguments.first
client_id = opts[:id]
client_secret = opts[:secret]
if repo_name.nil? || client_id.nil? || client_secret.nil?
    puts opts
    Kernel.exit(1)
end

Geocoder.configure(:lookup => :yandex)
Octokit.auto_paginate = true
Octokit.configure do |c|
    c.client_id = client_id
    c.client_secret = client_secret
end

contributors = Octokit.contribs(repo_name)
logins = contributors.map(&:login)
locations = Parallel.map(logins) {
    |login| Octokit.user(login).location
}.reject(&:nil?)
coordinates = Parallel.map(locations) {
    |location| Geocoder.coordinates(location)
}.reject(&:nil?)
puts JSON.pretty_generate({
    :type => "FeatureCollection",
    :features => coordinates.map { |coordinates|
        {
            :type => "Feature",
            :geometry => {
                :type => "Point",
                :coordinates => coordinates.reverse
            }
        }
    }
})
