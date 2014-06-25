#!/usr/bin/env ruby
# encoding: utf-8

require 'rugged'
require 'json'
require 'thor'
require 'fileutils'
require 'mongo'

class GritCli < Thor
	include Thor::Actions

	GRITRC = '.gritrc'
	GRITLOG = '.gritlog'

	desc 'process', "Process sources"
	def process
		@config['sources'].each{ |source|
			source_folder = url_to_folder(source)

			say_status('[pending]', "processing #{source}", :yellow)

			if 'new'.eql?(state(source)) then
				Rugged::Repository::clone_at(source, source_folder)
				@log[source] = Hash.new
				@log[source]['state'] = 'cloned'
				save_log
				say_status('[info]', "repository cloned", :blue)
			end

			if 'cloned'.eql?(state(source)) then
				globs = {}
				@config['analyses'].each{ |analysis|
					repo = Rugged::Repository.new(source_folder)
					obj = Object::const_get(analysis).new(source, repo, @config['options'], globs)
					obj.run
				}
				@log[source]['state'] = 'finished'
				save_log
				say_status('[info]', "analyses performed", :blue)
			end

			if 'finished'.eql?(state(source)) then
				say_status('[done]', "source processed")
			end
		}
	end

	desc 'sources', "List all sources"
	def sources
		@config['sources'].each{ |source|
			say_status("[#{state(source)}]", source, :blue)
		}
		say_status("[done]", "listed #{@config['sources'].size} sources")
	end

	desc 'analyses', "List all analyses"
	def analyses
		@config['analyses'].each{ |analysis|
			say_status('[info]', analysis, :blue)
		}
		say_status("[done]", "listed #{@config['analyses'].size} analyses")
	end

	desc 'reset [SOURCES*]', "Reset sources"
	def reset(*sources)
		@config['sources'].each{ |source|
			if sources.length == 0 || sources.include?(source) then
				FileUtils.rm_rf(url_to_folder(source))
				@log.delete(source)
				say_status('[info]', "resetted #{source}", :blue)
			end
		}
		save_log
		say_status('[done]', "resetted sources")
	end

	desc 'clear [SOURCES*]', "Clear finished sources"
	def clear(*sources)
		@config['sources'].each{ |source|
			if 'finished'.eql?(state(source)) && (sources.length == 0 || sources.include?(source)) then
				@log[source]['state'] = 'cloned'
				say_status('[info]', "cleared #{source}", :blue)
			end
		}
		save_log
		say_status('[done]', "cleared finished sources")
	end

	desc "init [FILE]", "Init grit folder"
	def init(urls_file = nil)
		@config = Hash.new
		if urls_file == nil || !File.exist?(urls_file) then
			@config['sources'] = []
			say_status('[warning]', "no urls found", :red)
		else
			@config['sources'] = IO.readlines(urls_file).collect{ |line| line.strip }
			say_status('[info]', "imported #{@config['sources'].size} sources", :blue)
		end
		@config['analyses'] = []
		@config['options'] = {}
		save_config
		say_status('[done]', "folder initialized")
	end

	desc "add_analysis [ANALYSIS*]", "Add analyses"
	def add_analysis(*analyses)
		analyses.each{ |analysis|
			if class_exist?(analysis) then
				if !@config['analyses'].include?(analysis) then
					@config['analyses'] << analysis
					say_status('[done]', "added analysis #{analysis}")
				else
					say_status('[warning]', "analysis #{analysis} already included", :red)
				end
			else
				say_status('[error]', "analysis #{analysis} not found", :red)
			end
		}
		save_config
	end

	desc "del_analysis [ANALYSIS*]", "Delete analyses"
	def del_analysis(*analyses)
		@config['analyses'].delete_if{ |analysis| analyses.include?(analysis) }
		save_config
	end

	def initialize(*args)
		super
		cmd = args[2][:current_command].name
		if !('init'.eql?(cmd) || 'help'.eql?(cmd)) then
			check_grit
			@config = load_config
			@log = load_log
		end
	end

	no_commands do

		def state(source)
			state = (@log[source] == nil && 'new') || @log[source]['state']
			return state
		end

		def error?(source)
			if @log['source'] == nil then
				return false
			else
				if @log['source']['error'] != nil
					return true
				else
					return false
				end
			end
		end

		def load_log
				if File.exist?(GRITLOG) then
					return JSON.parse(File.read(GRITLOG))
				else
					return Hash.new
				end
		end

		def save_log
			File.write(GRITLOG, JSON.pretty_generate(@log))
		end

		def load_config
			return JSON.parse(File.read(GRITRC))
		end

		def save_config
			File.write(GRITRC, JSON.pretty_generate(@config))
		end

		def url_to_folder(url)
			source_folder =  'source_' << url.gsub('://','_').gsub('/','_').gsub('?','_').gsub('&','_').gsub('.','_')
			return source_folder
		end

		def class_exist?(class_name)
			obj = Object::const_get(class_name)
			return obj.is_a?(Class)
		rescue NameError
			return false
		end

		def check_grit
			if !File.exist?(GRITRC) then
				say_status('[error]', "this is not a grit directory", :red)
				exit
			end
		end

	end

end

class GritAnalysis

	def initialize(source, repo, options, globs)
		@source = source
		@repo = repo
		@options = options
		@globs = globs
	end

	def run
	end

end

script = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
folder = File.dirname(script)

Dir.glob("#{folder}/../includes/*.rb").each{ |addon| load(addon) }

GritCli.start(ARGV)
