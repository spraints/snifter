class SnifterWrapper
  SNIFTER_PIDS = 'snifter-server-pids'

  def initialize redis, id
    @redis = redis
    @id = id
  end

  attr_reader :redis, :id

  def upstream     ; read 'upstream'     ; end
  def upstream=(s) ; write 'upstream', s ; end
  def port         ; read 'port'         ; end
  def port=(p)     ; write 'port', p     ; end

  def pid
    if pid = read('pid')
      return pid.to_i unless pid.empty?
    end
    nil
  end

  def pid=(p)
    write 'pid', p
    redis.hset SNIFTER_PIDS, p, id
  end

  def start!
    return if running?
    id, upstream, port = self.id, self.upstream, self.port
    self.pid = fork do
      @command =  ['./script/snifter', id, port, upstream]
      puts @command.join(' ')
      exec(*@command)
    end
    puts "Snifter #{id}[#{pid}] started."
  end

  def stop!
    return unless running?
    pid, self.pid = self.pid, nil
    Process.kill 'INT', pid
  rescue => e
    puts "Unable to kill #{pid}: #{e}"
  end

  def destroy!
    stop!
    # todo -- wipe other data
  end

  def self.for_pid redis, pid
    new(redis, redis.hget(SNIFTER_PIDS, pid))
  end

  def stopped
    redis.hdel SNIFTER_PIDS, pid
    self.pid = nil
  end

  def running?
    !pid.nil?
  end

  private
  def read key
    redis.get redis_key(key)
  end

  def write key, value
    redis.set redis_key(key), value
  end

  def redis_key key
    "snifter:::#{id}:::#{key}"
  end
end
