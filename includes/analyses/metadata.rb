# encoding: utf-8

class MetadataAnalysis < Analysis

	def run
		# Importing tags
		tags = @addons[:db].db['tags']
		@repo.tags.each{ |t|
			tag = { source: @source, name: t.name, target: t.target.oid }
			tags.insert(tag)
		}

		# Importing branches
		branches = @addons[:db].db['branches']
		@repo.branches.each{ |b|
			branch = { source: @source, name: b.name, target: b.target.oid }
			branches.insert(branch)
		}

		# Importing commits
		commits = @addons[:db].db['commits']
		walker = Rugged::Walker.new(@repo)
		walker.sorting(Rugged::SORT_DATE)
		walker.push(@repo.last_commit)
		walker.each{ |c|
			commit = {
				source: @source, oid: c.oid, message: c.message, author: c.author,
				committer: c.committer, parent_ids: c.parent_ids, time: c.time
			}
			commits.insert(commit)
		}
	end

end
