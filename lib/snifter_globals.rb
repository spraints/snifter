require 'redis'
ENV['REDIS_URL'] ||= 'redis://localhost:16379'
$redis = Redis.new

require 'snifter_collection'
$snifters = SnifterCollection.new $redis
