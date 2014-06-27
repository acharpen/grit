# encoding: utf-8

class ClocAnalysis < GritAnalysis

	def run
		puts `cloc #{@folder}`
	end

end
