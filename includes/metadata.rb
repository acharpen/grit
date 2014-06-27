# encoding: utf-8

class MetadataAnalysis < Analysis

	def run
		col = @addons['db'].db['commits']
	
		walker = Rugged::Walker.new(@repo)
		walker.sorting(Rugged::SORT_DATE)
		walker.push(@repo.last_commit)
		walker.each{ |c|
			commit = Hash.new
			commit['source'] = @source
			commit['oid'] = c.oid
			commit['message'] = c.message
			commit['author'] = c.author
			commit['committer'] = c.committer
			col.insert(commit)
		}
	end

end
