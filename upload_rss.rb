# coding: utf-8
require 'aws-sdk'


s3 = Aws::S3::Resource.new(
  credentials: Aws::Credentials.new(ENV['AWS_AKID'], ENV['AWS_SECRET']),
  region: 'us-east-1'
)
bucket = s3.bucket('media.scienceknocks.com')
%w(audio video).each do |file|
  obj = bucket.object("#{file}.rss")
  obj.upload_file("#{file}.rss", acl:'public-read',
                  content_type: 'application/rss+xml')
  STDERR.puts "uploaded #{file} to #{obj.public_url}"
end
