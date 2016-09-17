# Use podcastr to generate rss files for both
# the audio and video versions of the podcast
$:.unshift File.join(File.dirname(__FILE__), 'lib')
require 'podcastr'
require 'highline/import'

feedGenerator = Podcastr::FeedGenerator.new(YAML.load_file('podcast.yml'))
s3 = Aws::S3::Resource.new(
  region: 'us-east-1',
  credentials: Aws::SharedCredentials.new(:profile_name => 'ScienceKnocks')
)
bucket = 'media.scienceknocks.com'
{video: 'mp4',
 audio: 'mp3'}.each do |type, ext|
  vars_for_media = {:mediaType => type.to_s.capitalize,
                    :mediaExt => ext}
  file = "#{type}.rss"
  feedGenerator.generate_to_file(file, vars_for_media)
  if agree("Upload #{file} to s3? ")
    Podcastr::FeedUploader.upload(file, bucket, s3)
  else
    STDERR.puts "\tskipping upload of #{file}"
  end
end
