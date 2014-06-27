# encoding: utf-8

require 'yaml'

class ClocAnalysis < Analysis

	def run
		cloc = `cloc #{@folder} --quiet --yaml`
		if !"".eql?(cloc) then 
			yaml = YAML.load(cloc.lines[3..-1].join)
			yaml.delete('header')
			output = { :source => @source, :cloc => yaml }
		
			col = @addons['db'].db['cloc']
			col.insert(output)
		end
	end

end
