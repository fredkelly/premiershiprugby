#!/usr/bin/env ruby

require 'date'
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

    def self.replays(limit = 0)
      self.get('/').css('.videoItem')[0..limit-1].map { |r| Replay.new(r) }
    end


    def self.replay_video_files(options = {})
      options[:limit] ||= 25
      options[:formats] ||= %w(.flv .m4a)
      options[:quality] ||= nil


      if search = options[:search]
        fz = FuzzyMatch.new(self.replays, :read => :title)
        replays = [fz.find(search)] #.first(options[:limit])
      else
        replays = self.replays(options[:limit])     
      end

      replays.reduce([]) do |all, r|
        all + r.video_files(options[:quality], options[:formats]).map { |f| [r.filename, f] }
      end
    end
  end

  class Replay
    include ::HTTParty
    parser ::XmlParserIncluded

    base_uri BASE_URI

    attr_accessor :id, :title, :image, :created_at

    def initialize(videoItem)
      @id = videoItem.css('.img > a')
            .attr('onclick').value
            .match(/playVideo\((\d+)\)/).captures.first

      # Fix 2015-04-06
      return unless manifest.at_xpath('//clip')

      @title = videoItem.css('h2').text.strip
      @image = videoItem.css('.img img').attr('src').value
      @created_at = DateTime.rfc2822(manifest.xpath('//clip').attr('videoCreationRFC822Date').value)
    end

    def filename
      created_at.strftime("%Y-%m-%d") + '_' + sanitized_title
    end

    def type
      case title
      when /(Match)/
        :match
      when /(Highlights)/
        :highlights
      else
        :unknown
      end
    end

    def video_files(quality = nil, formats = nil)
      quality = quality.to_sym if quality
      formats ||= %w(.flv .m4v)

      # hack, full match replays don't have a /hi/ in URI
      quality = nil if type == :match


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

    # http://stackoverflow.com/a/10823131
    def sanitized_title(separator = '_')
      title = @title.split /(?<=.)\.(?=[^.])(?!.*\.[^.])/m
      title.map! { |s| s.gsub /[^a-z0-9\-]+/i, '_' }
      title.join(separator)
    end
  end
end

class PremiershipRugbyCLI < Thor
  option :preview, :type => :boolean, :default => true, :desc => 'preview without downloading'
  option :target, :type => :string, :required => true, :desc => 'destination directory'
  option :quality, :type => :string, :enum => ['high', 'low', 'iphone'], :desc => 'file quality'
  option :search, :type => :string, :desc => 'search query'
  option :formats, :type => :array, :enum => ['.flv', '.m4a'], :desc => 'file formats'
  option :limit, :type => :numeric, :desc => 'number of results returned'
  option :skip, :type => :numeric, :desc => '(rtmpdump) skip N keyframes when resuming', :default => 0

  desc 'download', 'lists all replay files'

  def download
    files = PremiershipRugby::Client.replay_video_files(options.dup)
    commands = []
    
    commands = files.inject([]) do |commands, (filename, file)|
      target = File.join options[:target], filename + File.extname(file)
      commands + ["[ ! -f #{target} ] && rtmpdump --skip #{options[:skip]} -r #{file} -o #{target}"]
    end

    if options[:preview]
      puts commands.join("\n")
    else
      commands.each { |c| `#{c}` }
    end
  end
end

PremiershipRugbyCLI.start(ARGV)
