require 'redis'

# Replace these with your ElastiCache endpoint and port
elasticache_endpoint = 'pidservice-dev-elasticache-lktnel.serverless.usw2.cache.amazonaws.com'
elasticache_port = '6379'

# Create a Redis client
redis = Redis.new(host: elasticache_endpoint, port: elasticache_port)

# Test the connection
redis.ping