# encoding: utf-8
require 'mongo'

class Db < Addon

	attr_reader :db

	def initialize(*args)
		super
		client = Mongo::MongoClient.new
		@db = client[@options[:mongo][:database]]
	end

	def name
		:db
	end

end
