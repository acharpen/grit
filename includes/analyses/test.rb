# encoding: utf-8

class TestAnalysis < Analysis

	def run
		puts @repo.tags.each_name.to_a.inspect
		
		walker = Rugged::Walker.new(@repo)
		walker.sorting(Rugged::SORT_DATE)
		walker.push(@repo.last_commit)
		walker.each{ |c|
			#puts c.inspect
		}
	end

end
