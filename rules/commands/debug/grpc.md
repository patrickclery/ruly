---
description: Debug gRPC requests by recreating action instances from curl commands
command: debug:grpc
---

# Debug gRPC Request

## Overview

This command takes a curl command (typically from browser DevTools) and creates a debug script that recreates the gRPC action instance with proper authentication context and request protobuf. The generated script uses gRPC helpers and follows established debugging patterns.

## Process

### Step 1: Parse the Curl Command

Extract the following from the provided curl command:

- GraphQL operation name and variables
- Authentication token from `authorization` header
- Company ID from `company-id` header
- Core company ID from `core-company-id` header
- Request body (GraphQL query/mutation)

### Step 2: Identify the Action Class

Map GraphQL operations to gRPC actions by searching common namespaces and patterns.

### Step 3: Generate Debug Script

The generated debug script follows established patterns. For detailed examples of:

- gRPC action debugging patterns
- Authentication and JWT token handling
- Using gRPC helpers (`Grpc::Helpers::Values`)
- Policy debugging patterns

See `@rules/core/debugging/debugging-patterns.md`

## Implementation Steps

### 1. Parse Curl Command

```ruby
def parse_curl_command(curl_string)
  # Extract URL
  url_match = curl_string.match(/curl\s+'([^']+)'/)
  url = url_match[1] if url_match

  # Extract headers
  headers = {}
  curl_string.scan(/-H\s+'([^:]+):\s*([^']+)'/).each do |key, value|
    headers[key.downcase] = value.strip
  end

  # Extract JSON data
  data_match = curl_string.match(/--data-raw\s+'(.+)'$/m)
  data = JSON.parse(data_match[1]) if data_match

  {
    url: url,
    headers: headers,
    data: data
  }
end
```

### 2. Map Operation to Action Class

```ruby
def find_grpc_action(operation_name)
  # Search in common namespaces
  possible_actions = [
    "Grpc::Employee::#{operation_name}Action",
    "Grpc::User::#{operation_name}Action",
    "Grpc::Core::#{operation_name}Action",
    "Grpc::Actions::#{operation_name}",
    "Actions::#{operation_name}"
  ]

  possible_actions.find { |name| Object.const_defined?(name) } ||
    "# TODO: Implement action mapping for #{operation_name}"
end
```

### 3. Generate Request Construction Code

```ruby
def generate_request_construction(operation_name, variables)
  case operation_name
  when 'UpdateCustomCvFieldValues'
    generate_custom_cv_field_request(variables)
  when 'ImportEmployee'
    generate_import_employee_request(variables)
  when 'GetAccessLevels'
    generate_access_levels_request(variables)
  else
    generate_generic_request(operation_name, variables)
  end
end
```

## Usage

```
/debug:grpc
```

Then paste the curl command when prompted. The command will:

1. Parse the curl command and extract authentication/request details
2. Map the GraphQL operation to the appropriate gRPC action class
3. Generate request construction code using gRPC helpers
4. Create a complete debug script with proper error handling
5. Save it with a timestamp: `debug/[OPERATION_NAME]-[TIMESTAMP].rb`

## Output

The command generates a debug script with:

- Proper Rails runner shebang for direct execution
- Authentication extraction from curl headers
- JWT token decoding for user context
- gRPC request construction using helpers
- Action instantiation with `{company:, user:}` context
- Result output using `amazing_print`

For examples of generated scripts, see `@rules/core/debugging/debugging-patterns.md#grpc-action-debugging`
