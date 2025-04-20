# frozen_string_literal: true

require "helper"

class TestFunctions < Minitest::Test
  include Helper::Client

  LUA_SCRIPT_RETURN_KEYS = <<~LUA
    #!lua name=my_return_keys_lib\nredis.register_function('return_keys', function(keys, args) return keys end)
  LUA

  LUA_SCRIPT_RETURN_ARGS = <<~LUA
    #!lua name=my_return_args_lib\nredis.register_function('return_args', function(keys, args) return args end)
  LUA

  def to_sha(script)
    r.script(:load, script)
  end

  def test_script_exists
    a = to_sha("return 1")
    b = a.succ

    assert_equal true, r.script(:exists, a)
    assert_equal false, r.script(:exists, b)
    assert_equal [true], r.script(:exists, [a])
    assert_equal [false], r.script(:exists, [b])
    assert_equal [true, false], r.script(:exists, [a, b])
  end

  def test_script_flush
    sha = to_sha("return 1")
    assert r.script(:exists, sha)
    assert_equal "OK", r.script(:flush)
    assert !r.script(:exists, sha)
  end

  def test_script_kill
    redis_mock(script: ->(arg) { "+#{arg.upcase}" }) do |redis|
      assert_equal "KILL", redis.script(:kill)
    end
  end

  def test_function_load_and_call
    r.function('flush', 'sync')
    assert_equal 'my_return_keys_lib', r.function('load', LUA_SCRIPT_RETURN_KEYS)
    assert_raises(Redis::CommandError) { r.function('load', LUA_SCRIPT_RETURN_KEYS) }
    assert_equal 'my_return_keys_lib', r.function('load', 'replace', LUA_SCRIPT_RETURN_KEYS)
    assert_equal 'my_return_args_lib', r.function('load', 'replace', LUA_SCRIPT_RETURN_ARGS)
    assert_equal ["k1", "k2"], r.fcall("return_keys", ["k1", "k2"], ['a1', 'a2'])
    assert_equal ["a1", "a2"], r.fcall("return_args", ["k1", "k2"], ['a1', 'a2'])
  end

  def test_eval_with_options_hash
    assert_equal 0, r.eval("return #KEYS", {})
    assert_equal 0, r.eval("return #ARGV", {})
    assert_equal ["k1", "k2"], r.eval("return KEYS", { keys: ["k1", "k2"] })
    assert_equal ["a1", "a2"], r.eval("return ARGV", { argv: ["a1", "a2"] })
  end

  def test_evalsha
    assert_equal 0, r.evalsha(to_sha("return #KEYS"))
    assert_equal 0, r.evalsha(to_sha("return #ARGV"))
    assert_equal ["k1", "k2"], r.evalsha(to_sha("return KEYS"), ["k1", "k2"])
    assert_equal ["a1", "a2"], r.evalsha(to_sha("return ARGV"), [], ["a1", "a2"])
  end

  def test_evalsha_no_script
    error = defined?(RedisClient::NoScriptError) ? Redis::NoScriptError : Redis::CommandError
    assert_raises error do
      redis.evalsha("invalid")
    end
  end

  def test_evalsha_with_options_hash
    assert_equal 0, r.evalsha(to_sha("return #KEYS"), {})
    assert_equal 0, r.evalsha(to_sha("return #ARGV"), {})
    assert_equal ["k1", "k2"], r.evalsha(to_sha("return KEYS"), { keys: ["k1", "k2"] })
    assert_equal ["a1", "a2"], r.evalsha(to_sha("return ARGV"), { argv: ["a1", "a2"] })
  end
end
