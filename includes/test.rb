# encoding: utf-8
require 'mongo'

class TestAnalysis < GritAnalysis

	def run
		walker = Rugged::Walker.new(@repo)
		walker.sorting(Rugged::SORT_DATE)
		walker.push(@repo.last_commit)
		walker.each{ |c|
			puts c.inspect
		}
	end

end
