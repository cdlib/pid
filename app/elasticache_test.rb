require 'redis'

# Replace these with your ElastiCache endpoint and port
elasticache_endpoint = 'redis-lktnel.serverless.usw2.cache.amazonaws.com'
elasticache_port = '6379'

# Create a Redis client
# redis = Redis.new(host: elasticache_endpoint, port: elasticache_port)
redis = Redis.new(host: elasticache_endpoint, port: elasticache_port, ssl: true)

# Test the connection
redis.ping