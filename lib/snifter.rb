require 'rubygems'
require 'redis'

class Snifter
  def initialize snifter_id, redis = nil
    @snifter_id = snifter_id
    @redis = redis || Redis.new
  end

  def log_connect(conn)
    add_data(conn, 'time', Time.now.to_i)
    update_list(conn_id(conn))
  end

  def log_data(conn, data)
    add_data(conn, 'request', data)
  end

  def log_response(conn, backend, resp)
    add_data(conn, 'response', resp)
  end

  def log_finish(conn, backend, name)
    p [:on_finish, conn]
  end

  def current
    @redis.lrange list_id, 0, -1;
  end

  def groups
    @redis.lrange(group_list_id, 0, -1).map { |id| id.sub(group_id_prefix, '') }
  end

  def get_group(group_name)
    @redis.lrange group_id(group_name), 0, -1;
  end

  def clear_groups
    @redis.ltrim group_list_id, -1, -1
  end

  def save_group(name, data)
    name = group_id(name)

    @redis.rpush group_list_id, name

    data.each do |sess|
      puts "PUSH #{name} #{sess}"
      @redis.rpush name, sess
    end
  end

  def session(session)
    req = @redis.get session + 'request'
    res = @redis.get session + 'response'
    time = @redis.get session + 'time'
    [req, res, time.to_i]
  end

  def clear_sessions
    current.each do |conn|
      @redis.del conn + 'request'
      @redis.del conn + 'response'
      @redis.del conn + 'time'
    end
    @redis.ltrim list_id, -1, -1
    true
  end

  def show_stats
    current.each do |conn|
      puts conn
      d = @redis.get conn + 'request'
      puts d.size rescue 'none'
      d = @redis.get conn + 'response'
      puts d.size rescue 'none'
      puts
    end
  end

  private

  def conn_id(conn)
    'snifter-conn-' + @snifter_id + '-' + conn.to_s
  end

  def list_id
    'snifter-conn-list-' + @snifter_id
  end

  def group_list_id
    'snifter-conn-group-' + @snifter_id
  end

  def group_id(name)
    group_id_prefix + name
  end

  def group_id_prefix
    'snifter-conn-groups-' + @snifter_id + '-'
  end

  def update_list(id)
    @redis.rpush list_id, id
    @redis.ltrim list_id, -30, -1
  end

  def add_data(conn, type, data)
    cid = conn_id(conn) + type
    if predata = @redis.get(cid)
      data = predata.to_s + data.to_s
    end
    @redis.set cid, data 
  end

end

