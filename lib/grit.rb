#!/usr/bin/env ruby
# encoding: utf-8

require 'rugged'
require 'json'
require 'thor'
require 'fileutils'
require 'singleton'

module GritCli
	GRITRC = '.gritrc'
	GRITLOG = '.gritlog'

	DONE = '[done]'
	PENDING = '[pending]'
	WARNING = '[warning]'
	ERROR = '[error]'
	INFO = '[info]'

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
			(File.exist?(GRITLOG) && JSON.parse(File.read(GRITLOG))) || {}
		end

		def save_log
			File.write(GRITLOG, JSON.pretty_generate(@log))
		end

		def load_config
			(File.exist?(GRITRC) && JSON.parse(File.read(GRITRC), {symbolize_names: true})) || {}
		end

		def save_config
			File.write(GRITRC, JSON.pretty_generate(@config))
		end

		def state(source)
			(log[source].nil? && :new) || log[source]['state'].to_sym
		end

		def error?(source)
			log[source].nil? || !log[source]['error'].nil?
		end

		def add_error(source, e)
			log[source]['error'] = { error: e.class.name, message: e.to_s, backtrace: e.backtrace }
		end

		def source_folder(source)
			'source_' << source.gsub('://','_').gsub('/','_').gsub('?','_').gsub('&','_').gsub('.','_')
		end

	end

	class GritSources < Thor
		include Thor::Actions
		include GritCliUtils

		desc 'list', "List sources"
		def list
			config[:sources].each{ |source|
				color = (grit_info.error?(source) && :red) || :blue
				say_status("[#{grit_info.state(source)}]", source, color)
			}
			status = (config[:sources].select{ |source| grit_info.error?(source) }.size == 0 && DONE) || ERROR
			color = (status == DONE && :green) || :red
			say_status(status, "listed #{config[:sources].size} sources including #{config[:sources].select{ |source| grit_info.error?(source) }.size} errors", color)
		end

		desc 'import [FILE]', "Import sources from a file"
		def import(urls_file)
			config[:sources] = IO.readlines(urls_file).collect{ |line| line.strip }
			say_status(INFO, "imported #{config['sources'].size} sources", :blue)
			grit_info.save_config
		end

		desc "add [SOURCE*]", "Add sources"
		def add(*sources)
			sources.each{ |source|
				unless config[:sources].include?(source)
						config[:sources] << source
						say_status(DONE, "added source #{source}")
				else
						say_status(WARNING, "source #{source} already included", :red)
				end
			}
			grit_info.save_config
		end

		desc "rem [SOURCE*]", "Remove sources"
		def rem(*sources)
			deleted = config[:sources].select{ |source| sources.include?(source) }
			config[:sources].delete_if{ |source| sources.include?(source) }
			deleted.each { |source|
				FileUtils.rm_rf(grit_info.source_folder(source))
				say_status(INFO, "removed #{source}", :blue)
			}
			say_status(DONE, "removed #{deleted.size} sources, #{sources.size - deleted.size} errors")
			grit_info.save_config
		end
	end

	class GritAddons < Thor
		include Thor::Actions
		include GritCliUtils

		desc 'list', "List addons"
		def list
			config[:addons].each{ |addon|
				say_status(INFO, addon, :blue)
			}
			say_status(DONE, "listed #{config['addons'].size} addons")
		end

		desc "add [ADDON*]", "Add addons"
		def add(*addons)
			addons.each{ |addon|
				if class_exist?(addon)
					unless config[:addons].include?(addon)
						config[:addons] << addon
						say_status(DONE, "added addon #{addon}")
					else
						say_status(WARNING, "addon #{addon} already included", :red)
					end
				else
					say_status(ERROR, "addon #{addon} not found", :red)
				end
			}
			grit_info.save_config
		end

		desc "rem [ADDON*]", "Remove addons"
		def rem(*addons)
			deleted = config[:addons].select{ |addon| addons.include?(addon) }
			config[:addons].delete_if{ |addon| addons.include?(addon) }
			deleted.each { |addon| say_status(INFO, "removed #{addon}", :blue) }
			say_status(DONE, "removed #{deleted.size} addons, #{addons.size - deleted.size} errors")
			grit_info.save_config
		end

	end

	class GritAnalyses < Thor
		include Thor::Actions
		include GritCliUtils

		desc 'list', "List analyses"
		def list
			config[:analyses].each{ |analysis| say_status(INFO, analysis, :blue) }
			say_status(DONE, "listed #{config[:analyses].size} analyses")
		end

		desc "add [ANALYSIS*]", "Add analyses"
		def add(*analyses)
			analyses.each{ |analysis|
				if class_exist?(analysis)
					unless config[:analyses].include?(analysis)
						config[:analyses] << analysis
						say_status(DONE, "added analysis #{analysis}")
					else
						say_status(WARNING, "analysis #{analysis} already included", :red)
					end
				else
					say_status(ERROR, "analysis #{analysis} not found", :red)
				end
			}
			grit_info.save_config
		end

		desc "rem [ANALYSIS*]", "Remove analyses"
		def rem(*analyses)
			deleted = config[:analyses].select{ |analysis| analyses.include?(analysis) }
			config[:analyses].delete_if{ |analysis| analyses.include?(analysis) }
			deleted.each { |analysis|	say_status(INFO, "removed #{analysis}", :blue) }
			say_status(DONE, "removed #{deleted.size} analyses, #{analyses.size - deleted.size} errors")
			grit_info.save_config
		end

	end

	class Grit < Thor
		include Thor::Actions
		include GritCliUtils

		def initialize(*args)
			super
			cmd = args[2][:current_command].name
			unless 'init'.eql?(cmd) || 'help'.eql?(cmd) || File.exist?(GRITRC)
				say_status(ERROR, "this is not a grit directory", :red)
				exit
			end
		end

		desc "init", "Init grit folder"
		def init()
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
				color = (grit_info.error?(source) && :red) || :green
				say_status("[#{grit_info.state(source)}]", "#{source}", color)
				say_status('[folder]', "#{grit_info.source_folder(source)}", :blue)
				if grit_info.error?(source)
					say_status(ERROR, "#{log[source]['error']['error']}", :red)
					say_status('[message]', "#{log[source]['error']['message']}", :red)
					say_status('[backtrace]', "", :red)
					say(log[source]['error']['backtrace'].join("\n"))
				end
			else
				source_color = (config[:sources].select{ |s| grit_info.error?(s) }.size > 0 && :red) || :blue
				say_status('[sources]', "#{config['sources'].size} sources: #{config['sources'].select{ |s| 'new'.eql?(grit_info.state(s)) }.size} new (#{config[:sources].select{ |s| 'new'.eql?(grit_info.state(s)) && grit_info.error?(s)}.size} errors), #{config[:sources].select{ |s| :cloned == grit_info.state(s) }.size} cloned (#{config[:sources].select{ |s| :cloned == grit_info.state(s) && grit_info.error?(s)}.size} errors), #{config[:sources].select{ |s| :finished == grit_info.state(s) }.size} finished", source_color)
				say_status('[addons]', "#{config[:addons].join(', ')}", :blue)
				say_status('[analyses]', "#{config[:analyses].join(', ')}", :blue)
				say_status('[options]', "#{config[:options]}", :blue)
			end
		end

		desc 'process', "Process grit folder"
		def process
			# Loading addons
			addons = {}
			config[:addons].each{ |addon|
				begin
					obj = Object::const_get(addon).new(config[:options])
					addons[obj.name] = obj
				rescue => e
					say_status(ERROR, "error loading addon #{addon}", :red)
					raise e
				end
			}
			say_status(INFO, "loaded addons", :blue)

			#Processing sources
			config[:sources].each{ |source|
				folder = grit_info.source_folder(source)
				say_status(PENDING, "processing #{source}", :yellow)

				# Process source in state new
				if grit_info.state(source) == :new
					log[source] ||= {}
					log[source]['state'] = :new
					error = false
					begin
						Rugged::Repository::clone_at(source, folder)
					rescue => e
						error = true
						grit_info.add_error(source, e)
						say_status(ERROR, "error cloning source", :red)
					end
					unless error
						log[source]['state'] = :cloned
						say_status(INFO, "source cloned", :blue)
					end
				end

				# Process source in state cloned
				if grit_info.state(source) == :cloned
					FileUtils.cd(folder)
					globs = {}
					error = false
					config[:analyses].each{ |analysis|
						repo = Rugged::Repository.new('.')
						begin
							obj = Object::const_get(analysis).new(source, repo, config[:options], addons, globs)
							obj.run
						rescue => e
							error = true
							grit_info.add_error(source, e)
							say_status(ERROR, "error running #{analysis}", :red)
						end
					}
					unless error
						log[source]['state'] = :finished
						log[source].delete('error')
					end
					say_status(INFO, "analyses performed", :blue)
					FileUtils.cd('..')
				end

				# Process source in state finished
				if grit_info.state(source) == :finished
					say_status(DONE, "source processed")
				end
			}

			grit_info.save_log
		end

		desc 'reset [SOURCES*]', "Reset grit folder"
		def reset(*sources)
			config[:sources].each{ |source|
				if sources.empty? || sources.include?(source)
					FileUtils.rm_rf(grit_info.source_folder(source))
					log.delete(source)
					say_status(INFO, "resetted #{source}", :blue)
				end
			}
			grit_info.save_log
			say_status(DONE, "resetted sources")
		end

		desc 'clear [SOURCES*]', "Clear grit folder"
		def clear(*sources)
			config[:sources].each{ |source|
				if grit_info.state(source) == :finished && (sources.empty? || sources.include?(source))
					log[source]['state'] = :cloned
					log[source].delete('error')
					say_status(INFO, "cleared #{source}", :blue)
				end
			}
			grit_info.save_log
			say_status('[done]', "cleared finished sources")
		end

		desc "sources SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "sources", GritSources

		desc "analyses SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "analyses", GritAnalyses

		desc "addons SUBCOMMAND ...ARGS", "manage the analyses for this grit folder."
		subcommand "addons", GritAddons

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

GritCli::Grit.start(ARGV)
