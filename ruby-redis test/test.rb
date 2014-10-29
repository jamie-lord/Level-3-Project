#!/usr/bin/env ruby

require "redis"

redis = Redis.new(:host => "192.168.0.13", :port => 6379, :db => 0)

redis.set("mykey", "hello world")
# => "OK"

redis.get("mykey")
# => "hello world"