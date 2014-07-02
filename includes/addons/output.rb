# encoding: utf-8

class Output < Addon

	attr_reader :folder

	def initialize(*args)
		super
		@folder = File.absolute_path(@options[:output])
		FileUtils.mkdir_p(@folder) unless File.exist?(@folder)
	end

	def name
		:output
	end

end
