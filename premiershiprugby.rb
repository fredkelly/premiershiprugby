#!/usr/bin/env ruby

require 'bundler'
Bundler.require


class XmlParserIncluded < HTTParty::Parser
  SupportedFormats.merge!('text/html' => :html, 'text/xml' => :xml)

  def html
    Nokogiri::HTML(body)
  end

  def xml
    Nokogiri::XML(body)
  end
end

module PremiershipRugby
  BASE_URI = "http://www.premiershiprugby.tv/"
  SITE_ID = 13118

  class Client
    include ::HTTParty
    parser ::XmlParserIncluded

    base_uri BASE_URI

    def self.replays(limit = -1)
      self.get('/').css('.videoItem')[0..limit].map { |r| Replay.new(r) }
    end


    def self.replay_video_files(options = {})
      options[:limit] ||= 25
      options[:formats] ||= %w(.flv .m4a)
      options[:quality] ||= :high

      self.replays(options[:limit]).reduce([]) do |all, r|
        all + r.video_files(options[:quality], options[:formats]).map { |f| [r.title, f] }
      end
    end
  end

  class Replay
    include ::HTTParty
    parser ::XmlParserIncluded

    base_uri BASE_URI

    attr_accessor :id, :title, :image

    def initialize(videoItem)
      @id = videoItem.css('.img > a')
            .attr('onclick').value
            .match(/playVideo\((\d+)\)/).captures.first
      @title = videoItem.css('h2').text.strip
      @image = videoItem.css('.img img').attr('src').value
    end

    def type
      title =~ /(\w+):.*/
      case title
      when /^(Match)/
        :match
      when /^(Highlights)/
        :highlights
      else
        :unknown
      end
    end

    def video_files(quality = nil, formats = nil)
      quality = quality.to_sym
      formats ||= %w(.flv .m4v)

      @video_files ||= manifest.xpath('//videofiles//file').map { |f| f.attr('externalPath').strip }
      video_files = @video_files.select { |f| formats.include?(File.extname(f)) }

      case quality
      when :iphone
        video_files.select! { |f| f[/\/iphone\//] }
      when :high
        video_files.select! { |f| f[/\/hi\//] }
      when :low
        video_files.select! { |f| f[/\/lo\//] }
      else
        # no filtering
      end

      video_files.compact
    end

    private

    def manifest
      self.class.get(manifest_uri)
    end

    def manifest_uri
      params = URI.encode_www_form(
        'videoType' => 5,
        'type' => 18,
        'sites' => SITE_ID,
        'clipId' => self.id
      )
      "/page/sva/xmlHttpRequest/0,,#{SITE_ID},00.xml?#{params}"
    end
  end
end

class PremiershipRugbyCLI < Thor
  option :preview, :type => :boolean, :default => true, :desc => 'preview without downloading'
  option :target, :type => :string, :required => true, :desc => 'destination directory'
  option :quality, :type => :string, :enum => ['high', 'low', 'iphone'], :desc => 'file quality'
  option :formats, :type => :array, :enum => ['.flv', '.m4a'], :desc => 'file formats'
  option :limit, :type => :numeric, :desc => 'number of results returned'

  desc 'download', 'lists all replay files'

  def download
    files = PremiershipRugby::Client.replay_video_files(options.dup)
    commands = []
    
    commands = files.inject([]) do |commands, (title, file)|
      target = File.join options[:target], sanitize_filename(title) + File.extname(file)
      commands + ["[ ! -f #{target} ] && rtmpdump -r #{file} -o #{target}"]
    end

    if options[:preview]
      puts commands.join("\n")
    else
      commands.each_slice(5) do |batch|
        batch.map do |command|
          Thread.new { puts(command); system(command) }
        end.map(&:join)
      end
    end
  end

  private

  # http://stackoverflow.com/a/10823131
  def sanitize_filename(filename)
    # Split the name when finding a period which is preceded by some
    # character, and is followed by some character other than a period,
    # if there is no following period that is followed by something
    # other than a period (yeah, confusing, I know)
    fn = filename.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m

    # We now have one or two parts (depending on whether we could find
    # a suitable period). For each of these parts, replace any unwanted
    # sequence of characters with an underscore
    fn.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }

    # Finally, join the parts with a period and return the result
    return fn.join '.'
  end
end

PremiershipRugbyCLI.start(ARGV)
