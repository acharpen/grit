# encoding: utf-8

require 'yaml'

class ClocAnalysis < GritAnalysis

	def run
		cloc = `cloc . --progress-rate=0 --quiet --yaml`
		unless cloc.empty?
			yaml = YAML.load(cloc.lines[2..-1].join)
			yaml.delete('header')
			output = { source: @source, cloc: yaml }
			col = @addons[:db].db['cloc']
			col.insert(output)
		end
	end

end
