#!/usr/bin/env ruby
# encoding: utf-8

require 'rugged'
require 'json'
require 'thor'
require 'fileutils'
require 'mongo'
require 'singleton'

module GritCli

	GRITRC = '.gritrc'
	GRITLOG = '.gritlog'

	module GritCliUtils

		def config
			return GritInfo.instance.config
		end

		def log
			return GritInfo.instance.log
		end

		def grit_info
			return GritInfo.instance
		end

		def class_exist?(class_name)
			obj = Object::const_get(class_name)
			return obj.is_a?(Class)
		rescue NameError
			return false
		end

	end

	class GritInfo
		include Singleton

		attr_accessor :config, :log

		def initialize(*args)
			super
			@config = load_config
			@log = load_log
		end

		def load_log
			if File.exist?(GRITLOG) then
				return JSON.parse(File.read(GRITLOG))
			else
				return {}
			end
		end

		def save_log
			File.write(GRITLOG, JSON.pretty_generate(@log))
		end

		def load_config
			if File.exist?(GRITRC) then
				return JSON.parse(File.read(GRITRC))
			else
				return {}
			end
		end

		def save_config
			File.write(GRITRC, JSON.pretty_generate(@config))
		end

	end
	
	class GritAddons < Thor
		include Thor::Actions
		include GritCliUtils
		
		desc 'list', "List all addons"
		def list
			config['addons'].each{ |addon|
				say_status('[info]', addon, :blue)
			}
			say_status("[done]", "listed #{config['addons'].size} addons")
		end

		desc "add [ANALYSIS*]", "Add addon"
		def add(*addons)
			addons.each{ |addon|
				if class_exist?(addon) then
					if !config['addons'].include?(addon) then
						config['addons'] << addon
						say_status('[done]', "added addon #{addon}")
					else
						say_status('[warning]', "addon #{addon} already included", :red)
					end
				else
					say_status('[error]', "addon #{analysis} not found", :red)
				end
			}
			grit_info.save_config
		end

		desc "rem [ANALYSIS*]", "Delete analyses"
		def rem(*addons)
			init_size = config['addons'].size
			config['addons'].delete_if{ |addon| addons.include?(addon) }
			diff_size = init_size - config['addons'].size
			if diff_size != analyses.size
				say_status('[warning]', "removed #{diff_size} addons, #{analyses.size - diff_size} errors", :red)
			else
				say_status('[done]', "removed #{init_size - config['addon'].size} addons")
			end

			grit_info.save_config
		end
	end

	class GritAnalyses < Thor
		include Thor::Actions
		include GritCliUtils


		desc 'list', "List all analyses"
		def list
			config['analyses'].each{ |analysis|
				say_status('[info]', analysis, :blue)
			}
			say_status("[done]", "listed #{config['analyses'].size} analyses")
		end

		desc "add [ANALYSIS*]", "Add analyses"
		def add(*analyses)
			analyses.each{ |analysis|
				if class_exist?(analysis) then
					if !config['analyses'].include?(analysis) then
						config['analyses'] << analysis
						say_status('[done]', "added analysis #{analysis}")
					else
						say_status('[warning]', "analysis #{analysis} already included", :red)
					end
				else
					say_status('[error]', "analysis #{analysis} not found", :red)
				end
			}
			grit_info.save_config
		end

		desc "rem [ANALYSIS*]", "Delete analyses"
		def rem(*analyses)
			init_size = config['analyses'].size
			config['analyses'].delete_if{ |analysis| analyses.include?(analysis) }
			diff_size = init_size - config['analyses'].size
			if diff_size != analyses.size
				say_status('[warning]', "removed #{diff_size} analyses, #{analyses.size - diff_size} errors", :red)
			else
				say_status('[done]', "removed #{init_size - config['analyses'].size} analyses")
			end

			grit_info.save_config
		end

	end

	class Grit < Thor
		include Thor::Actions
		include GritCliUtils

		def initialize(*args)
			super
			cmd = args[2][:current_command].name
			if !('init'.eql?(cmd) || 'help'.eql?(cmd)) then
				if !File.exist?(GRITRC) then
					say_status('[error]', "this is not a grit directory", :red)
					exit
				end
			end
		end
		
				desc "init [FILE?]", "Init grit folder"
		def init(urls_file = nil)
			config = Hash.new
			if urls_file == nil || !File.exist?(urls_file) then
				config['sources'] = []
				say_status('[warning]', "no urls found", :red)
			else
				config['sources'] = IO.readlines(urls_file).collect{ |line| line.strip }
				say_status('[info]', "imported #{config['sources'].size} sources", :blue)
			end
			config['analyses'] = []
			config['addons'] = []
			config['options'] = {}
			grit_info.config = config
			grit_info.save_config
			say_status('[done]', "folder initialized")
		end

		desc 'process', "Process sources"
		def process
			addons = {}
			config['addons'].each{ |addon|
				begin	
					obj = Object::const_get(addon).new(config['options'])
					addons[obj.name] = obj
				rescue => e
					say_status('[error]', "error loading addon #{addon}: #{e.to_s}, #{e.backtrace}", :red)
					exit
					raise
				end
			}
			say_status('[info]', "loaded addons", :blue)
			config['sources'].each{ |source|
				source_folder = url_to_folder(source)
				say_status('[pending]', "processing #{source}", :yellow)

				if 'new'.eql?(state(source)) then
					log[source] = {} if log[source] == nil
					log[source]['state'] = 'new'
					error = false
					begin
						Rugged::Repository::clone_at(source, source_folder)
					rescue => e
						error = true
						message = "Error when cloning source. Exception: #{e.class.name}. Message: #{e.to_s}"
						log[source]['error'] = message
						say_status('[error]', "error cloning source", :red)
					end
					if !error then
						log[source]['state'] = 'cloned'
						say_status('[info]', "source cloned", :blue)
					end
					grit_info.save_log
				end

				if 'cloned'.eql?(state(source)) then
					globs = {}
					error = false
					config['analyses'].each{ |analysis|
						repo = Rugged::Repository.new(source_folder)
						begin
							obj = Object::const_get(analysis).new(source, source_folder, repo, config['options'], addons, globs)
							obj.run
						rescue => e
							message = "Error running #{analysis}. Exception: #{e.class.name}. Message: #{e.to_s}"
							log[source]['error'] = message
							error = true
							say_status('[error]', "error running #{analysis}", :red)
						end
					}
					if !error then
						log[source]['state'] = 'finished'
						log[source].delete('error')
					end
					grit_info.save_log
					say_status('[info]', "analyses performed", :blue)
				end

				if 'finished'.eql?(state(source)) then
					say_status('[done]', "source processed")
				end
			}
		end

		desc 'sources', "List all sources"
		def sources
			config['sources'].each{ |source|
				color = (error?(source) && :red) || :blue
				say_status("[#{state(source)}]", source, color)
			}
			say_status("[done]", "listed #{config['sources'].size} sources including #{config['sources'].select{ |source| error?(source) }.size} errors")
		end

		desc 'reset [SOURCES*]', "Reset sources"
		def reset(*sources)
			config['sources'].each{ |source|
				if sources.length == 0 || sources.include?(source) then
					FileUtils.rm_rf(url_to_folder(source))
					log.delete(source)
					say_status('[info]', "resetted #{source}", :blue)
				end
			}
			grit_info.save_log
			say_status('[done]', "resetted sources")
		end

		desc 'clear [SOURCES*]', "Clear finished sources"
		def clear(*sources)
			config['sources'].each{ |source|
				if 'finished'.eql?(state(source)) && (sources.length == 0 || sources.include?(source)) then
					log[source]['state'] = 'cloned'
					log[source].delete('error')
					say_status('[info]', "cleared #{source}", :blue)
				end
			}
			grit_info.save_log
			say_status('[done]', "cleared finished sources")
		end
		
		desc "analyses SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "analyses", GritAnalyses
		
		desc "addons SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "addons", GritAddons

		no_commands do

			def state(source)
				state = (log[source] == nil && 'new') || log[source]['state']
				return state
			end

			def error?(source)
				if log[source] == nil then
					return false
				else
					if log[source]['error'] != nil
						return true
					else
						return false
					end
				end
			end

			def url_to_folder(url)
				source_folder =  'source_' << url.gsub('://','_').gsub('/','_').gsub('?','_').gsub('&','_').gsub('.','_')
				return source_folder
			end

		end

	end

end

class Addon

	def initialize(options)
		@options = options
	end

	def name
	end

end

class Analysis

	def initialize(source, folder, repo, options, addons, globs)
		@source = source
		@folder = folder
		@repo = repo
		@options = options
		@addons = addons
		@globs = globs
	end

	def run
	end

end

script = File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__
folder = File.dirname(script)
Dir.glob("#{folder}/../includes/*.rb").each{ |script| load(script) }

GritCli::Grit.start(ARGV)
