# Generate an RSS feed using a YML file.
# The idea is to make the YML file as DRY as possible
# so you can do interpolation using %{name} in any value.
# - Variables are defined in a special "vars" section, in any
# level of heirarchy.
# - A special "defaults" key exists at the top level, which
#   lets you specify default key/value pairs for any 1st level key (kludge)
#
# There's some additional massaging that happens in the massage_params function :)
#
# Finally, I wanted to be able to generate pretty much the same feed twice:
# - with a video enclosure
# - with an audio enclosre
# so there's a little bit of support for that at the end.
$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'builder'
require 'yaml'
require 'net/http'
require 'uri'
require 'podcastr'

feedGenerator = Podcastr::FeedGenerator.new(YAML.load_file('podcast.yml'))
{video: 'mp4',
 audio: 'mp3'}.each do |type, ext|
  output = ""
  vars_for_media = {:mediaType => type.to_s.capitalize,
                    :mediaExt => ext}
  feedGenerator.generate_to_file("#{type}.rss", vars_for_media)
end
