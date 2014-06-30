# encoding: utf-8

require 'yaml'

class ClocAnalysis < Analysis

	def run
		cloc = `cloc . --progress-rate=0 --quiet --yaml`
		if !"".eql?(cloc)
			yaml = YAML.load(cloc.lines[2..-1].join)
			yaml.delete('header')
			output = { :source => @source, :cloc => yaml }
			col = @addons['db'].db['cloc']
			col.insert(output)
		end
	end

end
