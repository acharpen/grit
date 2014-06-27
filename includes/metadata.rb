# encoding: utf-8
require 'mongo'

class MetadataAnalysis < GritAnalysis

	def initialize(*args)
		super
		client = Mongo::MongoClient.new
		db = client[@options['mongo']['database']]
		@col = db['commits']
	end

	def run
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
			@col.insert(commit)
		}
	end

end
