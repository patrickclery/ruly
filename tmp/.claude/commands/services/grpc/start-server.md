# gRPC Server Setup

## Quick Start

```bash
# 1. Start database and Redis (if not already running)
docker-compose up -d db redis-master

# 2. Ensure database exists and is migrated
psql -h localhost -U postgres -c "CREATE DATABASE workaxle_development;" 2>/dev/null || true
bundle exec rails db:migrate RAILS_ENV=development

# 3. Start gRPC server in Docker
docker-compose -f docker-compose.grpc-only.yml up -d grpc

# 4. Start Rails API on host (if needed)
bundle exec rails s -p 3001 -b '0.0.0.0'
```

## Test gRPC Connection

```ruby
# Save as test_grpc.rb and run with: ruby test_grpc.rb
require 'bundler/setup'
require 'grpc'
require_relative 'config/environment'

# Example: Test supervisor assignments
stub = Workaxle::Svc::Core::SupervisorAssignmentService::Stub.new('localhost:3002', :this_channel_is_insecure)

context = Workaxle::Common::RequestContext.new(
  source_svc: 'core',
  user_id: '34799',  # Replace with valid user ID
  company_id: '221', # Replace with valid company ID
  locale: 'en'
)

request = Workaxle::Svc::Core::GetSupervisorAssignmentsByCursorRequest.new(
  filter: {},
  paging: { limit: 10 }
)

response = stub.get_supervisor_assignments_by_cursor(request, metadata: {'context-bin' => context.to_proto})
puts "Status: #{response.status.code}" # 0 = success
```

## Files

- **docker-compose.grpc-only.yml** - Standalone Docker config
- **.env.docker.grpc** - Docker environment variables
- **docker/grpc-entrypoint.sh** - Entry script

## Troubleshooting

```bash
# Check logs
docker-compose -f docker-compose.grpc-only.yml logs grpc

# Restart
docker-compose -f docker-compose.grpc-only.yml restart grpc

# Database connection issues
# Edit docker-compose.grpc-only.yml DATABASE_URL to match your database
```