# encoding: utf-8

class PomAnalysis < Analysis

	def run
		pom_files = Dir['**/pom.xml']
		pom_files.each{ |file|
			puts file
			git = `git --no-pager log --pretty=%H --name-status #{file}`.lines
			history = []
			git.each_slice(3) { |slice| history << [slice[0].strip, slice[2].split("\t")[0].strip] }
			puts history.inspect
		}
	end

end
