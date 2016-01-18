require 'builder'
require 'yaml'
require 'net/http'
require 'uri'

def symbolify_keys(dict)
  Hash[*(dict.map{ |k,v| [k.to_sym, v] }).flatten]
end

def grab_vars(dict)
  vars = symbolify_keys(dict.delete('vars'){ {} })
end

def grab_defaults(dict)
  symbolify_keys(dict.delete('defaults'){ {} })
end

def interpolate_string(str, vars)
  while str =~ /%{.*}/ do
    str = str % vars
  end
  str
end

def get_headers(urlstring)
  url = URI.parse(urlstring)
  req = Net::HTTP::Head.new url.path
  res = Net::HTTP.start(url.host, url.port) { |http|
    http.request(req)
  }
  v = res.to_hash
  # STDERR.puts "got headers: #{v.inspect}"
  v
end

# gets file size, in bytes by doing a head request to the url
def get_file_size(urlstring)
  length = get_headers(urlstring)["content-length"]
  length.nil? ? nil : length.first
end

# gets the content duration using a head request to the URL and looking
# for a custom header
def get_duration(urlstring)
  duration = get_headers(urlstring)['x-amz-meta-duration']
  duration.nil? ? nil : duration.first
end

# this is where we hack some custom stuff
# in the feed.
def massage_params(params, current_dict)
  if 'enclosure' == params[-2]
    url = params.pop
    props = {url: url}
    props[:type] = case File.extname(url).split('.')[1]
                   when 'mp3'
                         'audio/mpeg'
                   when 'mp4'
                         'video/mp4'
                   end
    props[:length] = get_file_size(url)
    params.push(props)
  elsif :duration == params[-2]
    duration = get_duration(current_dict['enclosure'][1][:url]).to_i
    params[-1] = duration.nil? ? params[-1].to_i : duration
  elsif params.last =~ /^http/ && !['link', 'guid'].include?(params[-2])
    link = params.pop
    params.push({href: link})
  elsif :category == params[-2] && !params.last.is_a?(Hash)
    category = params.pop
    params.push({text: category})
  end
  params
end

def build(xml, dict, vars, defaults)
  new_vars = grab_vars(dict)
  local_vars = vars.merge(new_vars)
  current_dict = {}
  dict.each do |k,v|
    params = [k]
    if k =~ /itunes\./
      params = [:itunes]
      params.push(k.split('.')[1].to_sym)
    end
    if (v.is_a? Array)
      v.each do |vv|
        build(xml, { k => vv }, local_vars, defaults)
      end
    elsif (v.is_a? Hash)
      # add in defaults
      if defaults.has_key?(k.to_sym)
        v = defaults[k.to_sym].merge(v)
      end
      xml.__send__(*params) { build(xml, v, local_vars, defaults) }
    else
      params.push(interpolate_string(v, local_vars))
      params = massage_params(params, current_dict)
      current_dict[k] = params
      if( params[-1] =~ /<.*>/ && :summary == params[1])
        xml.__send__(*(params[0..-2])) { xml.cdata! params[-1] }
      else
        xml.__send__(*params)
      end
    end
  end
end

i = YAML.load_file('podcast.yml')
vars = grab_vars(i)
defaults = grab_defaults(i)

# A little extra here: build the same feed twice;
# once for audio, once for video

{video: 'mp4',
 audio: 'mp3'}.each do |type, ext|
  output = ""
  vars_for_media = vars.merge(:mediaType => type.to_s.capitalize, :mediaExt => ext)
  xml = Builder::XmlMarkup.new(target: output, indent: 2)
  xml.instruct! :xml, :version => "1.0" 
  xml.rss "xmlns:itunes" => "http://www.itunes.com/dtds/podcast-1.0.dtd", :version => "2.0" do
    build(xml, i, vars_for_media, defaults)
  end
  filename = "#{type}.rss"
  File.open(filename, 'w') {|f| f.write output }
  STDERR.puts "wrote to #{filename}"
end
