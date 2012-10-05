require 'snifter_wrapper'

class SnifterCollection
  def initialize redis
    @redis = redis
  end

  attr_reader :redis

  SNIFTER_IDS = 'snifter-server-list'

  def add snifter_id, opts = {}
    SnifterWrapper.new(redis, snifter_id).tap do |snifter|
      snifter.upstream = opts[:upstream]
      snifter.port = opts[:port]
      redis.sadd(SNIFTER_IDS, snifter_id)
    end
  end

  def remove snifter_id
    SnifterWrapper.new(redis, snifter_id).destroy!
    redis.srem(SNIFTER_IDS, snifter_id)
  end

  include Enumerable
  def each
    redis.smembers(SNIFTER_IDS).each do |snifter_id|
      yield SnifterWrapper.new redis, snifter_id
    end
  end

  def [](snifter_id)
    find { |snifter| snifter.id == snifter_id }
  end

  def stopped pid
    SnifterWrapper.for_pid(redis, pid).stopped
  end
end
