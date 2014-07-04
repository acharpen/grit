#!/usr/bin/env ruby
# encoding: utf-8

require 'rugged'
require 'json'
require 'thor'
require 'fileutils'
require 'singleton'

module Grit
	GRITRC = '.gritrc'
	GRITLOG = '.gritlog'

	DONE = '[done]'
	PENDING = '[pending]'
	WARNING = '[warning]'
	ERROR = '[error]'
	INFO = '[info]'

	class GritInfo
		include Singleton

		attr_accessor :config, :log

		def initialize(*args)
			super
			@config = load_config
			@log = load_log
		end

		def load_config
			(File.exist?(GRITRC) && JSON.parse(File.read(GRITRC), {symbolize_names: true})) || {}
		end

		def save_config
			File.write(GRITRC, JSON.pretty_generate(@config))
		end

		def load_log
			(File.exist?(GRITLOG) && JSON.parse(File.read(GRITLOG))) || {}
		end

		def save_log
			File.write(GRITLOG, JSON.pretty_generate(@log))
		end
	end

	module GritUtils
		def grit_info
			return GritInfo.instance
		end

		def config
			return grit_info.config
		end

		def log
			return grit_info.log
		end

		def sources
			return config[:sources]
		end

		def error?(source)
			!(log[source].nil? || log[source]['error'].nil?)
		end

		def state(source)
			(log[source].nil? && :new) || log[source]['state'].to_sym
		end

		def erroneous_sources
			return sources.select { |source| error?(source) }
		end

		def add_error(source, e)
			log[source]['error'] = { error: e.class.name, message: e.to_s, backtrace: e.backtrace }
		end

		def source_folder(source)
			'source_' << source.gsub('://','_').gsub('/','_').gsub('?','_').gsub('&','_').gsub('.','_')
		end

		def addons
			return config[:addons]
		end

		def analyses
			return config[:analyses]
		end

		def class_exist?(class_name)
			obj = Object::const_get(class_name)
			return obj.is_a?(Class)
		rescue NameError
			return false
		end
	end

	class GritSourcesCli < Thor
		include Thor::Actions
		include GritUtils

		desc 'list', "List sources"
		def list
			sources.each do |source|
				color = (error?(source) && :red) || :blue
				say_status("[#{state(source)}]", source, color)
			end
			status = (erroneous_sources.size == 0 && DONE) || ERROR
			color = (status == DONE && :green) || :red
			say_status(status, "listed #{sources.size} sources including #{erroneous_sources.size} errors", color)
		end

		desc 'import [FILE]', "Import sources from a file"
		def import(urls_file)
			sources << IO.readlines(urls_file).collect{ |line| line.strip }
			say_status(INFO, "imported #{config['sources'].size} sources", :blue)
			grit_info.save_config
		end

		desc "add [SOURCE*]", "Add sources"
		def add(*selected_sources)
			selected_sources.each do |source|
				unless sources.include?(source)
						sources << source
						say_status(DONE, "added source #{source}")
				else
						say_status(WARNING, "source #{source} already included", :red)
				end
			end
			grit_info.save_config
		end

		desc "rem [SOURCE*]", "Remove sources"
		def rem(*selected_sources)
			deleted = sources.select{ |source| selected_sources.include?(source) }
			sources.delete_if{ |source| selected_sources.include?(source) }
			deleted.each do |source|
				FileUtils.rm_rf(source_folder(source))
				say_status(INFO, "removed #{source}", :blue)
			end
			say_status(DONE, "removed #{deleted.size} sources, #{selected_sources.size - deleted.size} errors")
			grit_info.save_config
		end
	end

	class GritAddonsCli < Thor
		include Thor::Actions
		include GritUtils

		desc 'list', "List addons"
		def list
			addons.each{ |addon| say_status(INFO, addon, :blue) }
			say_status(DONE, "listed #{config['addons'].size} addons")
		end

		desc "add [ADDON*]", "Add addons"
		def add(*selected_addons)
			selected_addons.each do |addon|
				if class_exist?(addon)
					unless addons.include?(addon)
						addons << addon
						say_status(DONE, "added addon #{addon}")
					else
						say_status(WARNING, "addon #{addon} already included", :red)
					end
				else
					say_status(ERROR, "addon #{addon} not found", :red)
				end
			end
			grit_info.save_config
		end

		desc "rem [ADDON*]", "Remove addons"
		def rem(*selected_addons)
			deleted = addons.select{ |addon| selected_addons.include?(addon) }
			addons.delete_if{ |addon| selected_addons.include?(addon) }
			deleted.each { |addon| say_status(INFO, "removed #{addon}", :blue) }
			say_status(DONE, "removed #{deleted.size} addons, #{selected_addons.size - deleted.size} errors")
			grit_info.save_config
		end

	end

	class GritAnalysesCli < Thor
		include Thor::Actions
		include GritUtils

		desc 'list', "List analyses"
		def list
			analyses.each{ |analysis| say_status(INFO, analysis, :blue) }
			say_status(DONE, "listed #{config[:analyses].size} analyses")
		end

		desc "add [ANALYSIS*]", "Add analyses"
		def add(*selected_analyses)
			selected_analyses.each do |analysis|
				if class_exist?(analysis)
					unless analyses.include?(analysis)
						analyses << analysis
						say_status(DONE, "added analysis #{analysis}")
					else
						say_status(WARNING, "analysis #{analysis} already included", :red)
					end
				else
					say_status(ERROR, "analysis #{analysis} not found", :red)
				end
			end
			grit_info.save_config
		end

		desc "rem [ANALYSIS*]", "Remove analyses"
		def rem(*selected_analyses)
			deleted = analyses.select{ |analysis| selected_analyses.include?(analysis) }
			analyses.delete_if{ |analysis| selected_analyses.include?(analysis) }
			deleted.each { |analysis|	say_status(INFO, "removed #{analysis}", :blue) }
			say_status(DONE, "removed #{deleted.size} analyses, #{selected_analyses.size - deleted.size} errors")
			grit_info.save_config
		end

	end

	class GritCli < Thor
		include Thor::Actions
		include GritUtils

		def initialize(*args)
			super
			cmd = args[2][:current_command].name
			unless 'init'.eql?(cmd) || 'help'.eql?(cmd) || File.exist?(GRITRC)
				say_status(ERROR, "this is not a grit directory", :red)
				exit
			end
		end

		desc "init", "Init grit folder"
		def init
			config = { sources: [], analyses: [], addons: [], options: {} }
			grit_info.config = config
			grit_info.save_config
			say_status(DONE, "folder initialized")
		end

		desc "opts [FILE]", "Set grit folder options"
		def opts(file)
			options = JSON.parse(File.read(file))
			config[:options] = options
			grit_info.save_config
		end

		desc 'info SOURCE', "Gives info on a source"
		def info(source = nil)
			unless source.nil?
				color = (error?(source) && :red) || :green
				say_status("[#{state(source)}]", "#{source}", color)
				say_status('[folder]', "#{source_folder(source)}", :blue)
				if error?(source)
					say_status(ERROR, "#{log[source]['error']['error']}", :red)
					say_status('[message]', "#{log[source]['error']['message']}", :red)
					say_status('[backtrace]', "", :red)
					say(log[source]['error']['backtrace'].join("\n"))
				end
			else
				color = (erroneous_sources.size > 0 && :red) || :blue
				say_status('[sources]', "#{sources.size} sources: #{sources.select{ |s| state(s) == :new}.size} new (#{erroneous_sources.select{ |s| state(s) == :new }.size} errors), #{sources.select{ |s| state(s) == :cloned}.size } cloned (#{ erroneous_sources.select{ |s| state(s) == :cloned }.size} errors), #{sources.select{ |s| state(s) == :finished }.size} finished", color)
				say_status('[addons]', "#{addons.join(', ')}", :blue)
				say_status('[analyses]', "#{analyses.join(', ')}", :blue)
				say_status('[options]', "#{config[:options]}", :blue)
			end
		end

		desc 'process', "Process grit folder"
		def process
			# Loading addons
			loaded_addons = {}
			addons.each do |addon|
				begin
					obj = Object::const_get(addon).new(config[:options])
					loaded_addons[obj.name] = obj
				rescue => e
					say_status(ERROR, "error loading addon #{addon}", :red)
					raise e
				end
			end
			say_status(INFO, "loaded addons", :blue)

			#Processing sources
			sources.each do |source|
				folder = source_folder(source)
				say_status(PENDING, "processing #{source}", :yellow)

				# Process source in state new
				if state(source) == :new
					log[source] ||= {}
					log[source]['state'] = :new
					begin
						Rugged::Repository::clone_at(source, folder)
					rescue => e
						error = true
						add_error(source, e)
						say_status(ERROR, "error cloning source", :red)
					else
						log[source]['state'] = :cloned
						say_status(INFO, "source cloned", :blue)
					end
				end

				# Process source in state cloned
				if state(source) == :cloned
					FileUtils.cd(folder)
					globs = {}
					performed_analyses = []
					begin
						repo = Rugged::Repository.new('.')
						analyses.each do |analysis|
							performed_analyses << analysis
							obj = Object::const_get(analysis).new(source, repo, config[:options], loaded_addons, globs)
							obj.run
						end
					rescue => e
						add_error(source, e)
						log[source]['error']['analyses'] = performed_analyses[1..-2]
						say_status(ERROR, "error running #{performed_analyses.last} analysis", :red)
					else
						log[source]['state'] = :finished
						log[source].delete('error')
					end
					say_status(INFO, "analyses performed", :blue)
					FileUtils.cd('..')
				end

				# Process source in state finished
				if state(source) == :finished
					say_status(DONE, "source processed")
				end
			end

			grit_info.save_log
		end

		desc 'reset [SOURCES*]', "Reset grit folder"
		def reset(*selected_sources)
			sources.each do |source|
				if selected_sources.empty? || selected_sources.include?(source)
					FileUtils.rm_rf(source_folder(source))
					log.delete(source)
					say_status(INFO, "resetted #{source}", :blue)
				end
			end
			grit_info.save_log
			say_status(DONE, "resetted sources")
		end

		desc 'clear [SOURCES*]', "Clear grit folder"
		def clear(*selected_sources)
			sources.each do |source|
				if state(source) == :finished && (selected_sources.empty? || selected_sources.include?(source))
					log[source]['state'] = :cloned
					log[source].delete('error')
					say_status(INFO, "cleared #{source}", :blue)
				end
			end
			grit_info.save_log
			say_status(DONE, "cleared finished sources")
		end

		desc "source SUBCOMMAND ...ARGS", "manage the sources for this grit folder."
		subcommand "source", GritSourcesCli

		desc "analysis SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "analysis", GritAnalysesCli

		desc "addon SUBCOMMAND ...ARGS", "manage the addons for this grit folder."
		subcommand "addon", GritAddonsCli

	end

end

class GritAddon

	def initialize(options)
		@options = options
	end

	def name
	end

end

class GritAnalysis

	def initialize(source, repo, options, addons, globs)
		@source = source
		@repo = repo
		@options = options
		@addons = addons
		@globs = globs
	end

	def run
	end

end

INCLUDES = 'includes'
INCLUDES_FOLDER = File.expand_path(INCLUDES,File.expand_path('..',File.dirname(File.realpath(__FILE__))))

Dir.glob("#{INCLUDES_FOLDER}/**/*.rb").each{ |script| load(script) }

Grit::GritCli.start(ARGV)
