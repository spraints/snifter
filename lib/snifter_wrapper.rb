require 'snifter'
require 'coderay'
require 'rexml/document'
require 'nokogiri'

class SnifterWrapper
  SNIFTER_PIDS = 'snifter-server-pids'

  def initialize redis, id
    @redis = redis
    @id = id
  end

  attr_reader :redis, :id

  def sessions
    groups = Hash.new { |h,k| h[k] = [] }
    _snifter.groups.each do |group|
      _snifter.get_group(group).each do |sess|
        groups[sess] << group
      end
    end
    _snifter.current.map { |sess|
      req, res, time = _snifter.session(sess)
      req = get_line(req)
      res = get_line(res)
      [sess, req, res, time, groups[sess]]
    }
  end

  def session sess
    _snifter.session(sess).take(2).map { |o| process_http(o) }
  end

  def raw_session sess
    _snifter.session(sess).take(2)
  end

  def clear!
    clear_sessions
    clear_groups
  end

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
    clear!
    stop!
  end

  def self.for_pid redis, pid
    new(redis, redis.hget(SNIFTER_PIDS, pid))
  end

  def stopped
    redis.hdel SNIFTER_PIDS, pid
    self.pid = nil
  end

  def verify_pid!
    running? and Process.getpgid(pid)
  rescue Errno::ESRCH
    self.pid = nil
  end

  def running?
    !pid.nil?
  end

  def method_missing(*a)
    _snifter.send(*a)
  end

  def respond_to?(m)
    super || _snifter.respond_to?(m)
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

  def _snifter
    @_snifter ||= Snifter.new id, redis
  end

  def get_line(data)
    data.split("\n").first.gsub("HTTP/1.1", '')
  rescue
    'fu'
  end

  def process_http(req)
    header, xml = req.split("\r\n\r\n")

    headers = header.split("\r\n")
    http = headers.shift
    harr = headers.map { |h| h.split(': ') }

    r = ""
    begin
      req = REXML::Document.new(xml)
      req.write(r, 3)
      div = CodeRay.scan(r, :xml).div
    rescue
      div = CodeRay.scan(xml, :xml).div
    end

    begin
      n = Nokogiri.XML(r)
      values = get_values([n.root.name], n.root, [])
    rescue Object => e
      puts e.message
      values = []
    end

    { :headers => harr, :body => div, 
      :header_raw => header, :body_raw => xml,
      :http => http, :body_values => values
    }
  end

  def get_values(context, node, values)
    node.children.each do |a|
      if a.element?
        new_context = context + [a.name]
        values = get_values(new_context, a, values)
      else
        data = a.content.strip
        if !data.empty?
          values << [context.join('.'), data]
        end
      end
    end
    if node.children.size == 0
      values << [context.join('.'), node.name]
    end
    values
  end
end
