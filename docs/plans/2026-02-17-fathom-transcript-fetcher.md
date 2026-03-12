# Fathom Transcript Fetcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a script that fetches Fathom meeting transcripts from a share URL and integrates them into the existing `~/tmp/context/{ISSUE}/` system so the context-fetcher workflow reads them alongside Jira, PR, and Teams data.

**Architecture:** A bash script scrapes the Fathom share page HTML to extract embedded JSON metadata (call ID, title, recording start time, `copyTranscriptUrl`), then fetches the transcript endpoint which returns JSON with a `plain_text` field containing speaker-labeled, timestamped transcript. No API key needed — the share token in the URL is the auth. The context-fetching workflow is updated to discover and read `fathom-transcript-*.txt` files. Fathom fetch is manual (user provides link), not auto-dispatched by context_fetcher.

**Tech Stack:** Bash, curl, jq (for JSON extraction from `data-page` attribute), sed

---

### Task 1: Create fetch-fathom-transcript.sh

**Files:**
- Create: `rules/comms/fathom/bin/fetch-fathom-transcript.sh`

**Step 1: Create the directory**

Run: `mkdir -p /Users/patrick/Projects/ruly/rules/comms/fathom/bin`

**Step 2: Write the script**

Create `rules/comms/fathom/bin/fetch-fathom-transcript.sh`:

```bash
#!/usr/bin/env bash
# Fetches a Fathom meeting transcript from a share URL and saves as plain text.
#
# How it works:
#   1. Fetches the share page HTML
#   2. Extracts embedded JSON from the data-page attribute (contains call metadata + copyTranscriptUrl)
#   3. Fetches the copyTranscriptUrl endpoint (returns JSON with plain_text transcript)
#   4. Saves plain_text transcript with a header to the output file
#
# No API key needed — the share token in the URL is the authentication.
#
# Usage: fetch-fathom-transcript.sh -O <output_dir> <fathom_share_url>
#
# Arguments:
#   -O <output_dir>: Required. Output directory (e.g., ~/tmp/context/WA-12345/)
#   <fathom_share_url>: Fathom share URL (e.g., https://fathom.video/share/XB2rTP...)
#
# Output: <output_dir>/fathom-transcript-<YYYY-MM-DD-HHmm>.txt

set -e

# Parse options
OUTPUT_DIR=""
while [[ "$1" == -* ]]; do
  case "$1" in
    -O)
      shift
      OUTPUT_DIR="$1"
      shift
      ;;
    *)
      echo "Error: Unknown option: $1"
      exit 1
      ;;
  esac
done

SHARE_URL="$1"

if [ -z "$OUTPUT_DIR" ]; then
  echo "Error: Missing required -O <output_dir> parameter"
  echo "Usage: fetch-fathom-transcript.sh -O <output_dir> <fathom_share_url>"
  exit 1
fi

# Expand ~ in OUTPUT_DIR
OUTPUT_DIR="${OUTPUT_DIR/#\~/$HOME}"

if [ -z "$SHARE_URL" ]; then
  echo "Usage: fetch-fathom-transcript.sh -O <output_dir> <fathom_share_url>"
  echo "Example: fetch-fathom-transcript.sh -O ~/tmp/context/WA-12345 'https://fathom.video/share/XB2rTP...'"
  exit 1
fi

# Validate dependencies
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Error: $cmd is required but not installed"
    exit 1
  fi
done

# Extract share token from URL (strip query params, anchors, trailing slashes)
# Handles: https://fathom.video/share/XB2rTP4NEcnV_mDmkF7QoPuK_7gKzkKy?tab=summary&utm_...
SHARE_TOKEN=$(echo "$SHARE_URL" | sed -n 's|.*fathom\.video/share/\([^?&#/]*\).*|\1|p')

if [ -z "$SHARE_TOKEN" ]; then
  echo "❌ Error: Could not extract share token from URL"
  echo "   Expected format: https://fathom.video/share/<token>"
  echo "   Got: $SHARE_URL"
  exit 1
fi

# Normalize share URL (strip query params for clean fetch)
CLEAN_URL="https://fathom.video/share/${SHARE_TOKEN}"

echo "🔍 Fetching Fathom share page..."

mkdir -p "$OUTPUT_DIR"

# Step 1: Fetch share page HTML
PAGE_HTML=$(curl -sS "$CLEAN_URL" \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:148.0) Gecko/20100101 Firefox/148.0' \
  -H 'Accept: text/html')

if [ -z "$PAGE_HTML" ]; then
  echo "❌ Error: Empty response from Fathom share page"
  exit 1
fi

# Step 2: Extract data-page JSON from <div id="app" data-page="...">
# The JSON is HTML-entity-encoded in the attribute
PAGE_JSON=$(echo "$PAGE_HTML" | sed -n 's/.*data-page="\([^"]*\)".*/\1/p' | \
  python3 -c "import sys, html; print(html.unescape(sys.stdin.read()))" 2>/dev/null)

if [ -z "$PAGE_JSON" ]; then
  echo "❌ Error: Could not extract data-page JSON from share page"
  echo "   The page may require authentication or the format may have changed."
  exit 1
fi

# Step 3: Extract metadata from embedded JSON
TITLE=$(echo "$PAGE_JSON" | jq -r '.props.call.title // .props.call.topic // "Untitled"')
RECORDING_START=$(echo "$PAGE_JSON" | jq -r '.props.call.recording.started_at // .props.call.started_at // empty')
CALL_ID=$(echo "$PAGE_JSON" | jq -r '.props.call.id // empty')
COPY_TRANSCRIPT_URL=$(echo "$PAGE_JSON" | jq -r '.props.copyTranscriptUrl // empty')
DURATION_MINS=$(echo "$PAGE_JSON" | jq -r '.props.call.duration_minutes // empty')
HOST_EMAIL=$(echo "$PAGE_JSON" | jq -r '.props.call.host.email // empty')

echo "✅ Found meeting: $TITLE"
echo "   Call ID: $CALL_ID"
echo "   Duration: ${DURATION_MINS} minutes"
echo "   Host: $HOST_EMAIL"
echo "   Recording start: $RECORDING_START"

if [ -z "$COPY_TRANSCRIPT_URL" ]; then
  echo "❌ Error: No copyTranscriptUrl found in page data"
  echo "   The meeting may not have a transcript yet."
  exit 1
fi

# Step 4: Fetch transcript from copyTranscriptUrl
echo "📥 Fetching transcript..."

TRANSCRIPT_JSON=$(curl -sS "$COPY_TRANSCRIPT_URL" \
  -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:148.0) Gecko/20100101 Firefox/148.0')

if [ -z "$TRANSCRIPT_JSON" ]; then
  echo "❌ Error: Empty response from transcript endpoint"
  exit 1
fi

# Extract plain_text from response JSON
PLAIN_TEXT=$(echo "$TRANSCRIPT_JSON" | jq -r '.plain_text // empty')

if [ -z "$PLAIN_TEXT" ]; then
  echo "❌ Error: No plain_text field in transcript response"
  exit 1
fi

# Step 5: Format datetime for filename (YYYY-MM-DD-HHmm)
if [ -n "$RECORDING_START" ]; then
  DATETIME=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${RECORDING_START%%.*}" "+%Y-%m-%d-%H%M" 2>/dev/null || \
             date -d "$RECORDING_START" "+%Y-%m-%d-%H%M" 2>/dev/null || \
             echo "unknown")
else
  DATETIME="unknown"
fi

OUTPUT_FILE="${OUTPUT_DIR}/fathom-transcript-${DATETIME}.txt"

# Step 6: Save transcript with header
cat > "$OUTPUT_FILE" << EOF
$PLAIN_TEXT
EOF

LINE_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')

echo ""
echo "📝 Transcript saved:"
echo "  File: $OUTPUT_FILE"
echo "  Lines: $LINE_COUNT"
echo "  Meeting: $TITLE"
echo "  Date: $RECORDING_START"
echo ""
echo "🎯 Fathom transcript fetch completed successfully"
```

**Step 3: Make the script executable**

Run: `chmod +x /Users/patrick/Projects/ruly/rules/comms/fathom/bin/fetch-fathom-transcript.sh`

**Step 4: Verify the script is syntactically valid**

Run: `bash -n /Users/patrick/Projects/ruly/rules/comms/fathom/bin/fetch-fathom-transcript.sh`
Expected: No output (silent success)

**Step 5: Commit**

```bash
git add rules/comms/fathom/bin/fetch-fathom-transcript.sh
git commit -m "feat: add Fathom transcript fetcher script"
```

---

### Task 2: Update context-fetching.md to include Fathom transcripts

**Files:**
- Modify: `rules/comms/commands/context-fetching.md`

**Step 1: Read the current file**

Read: `rules/comms/commands/context-fetching.md`

**Step 2: Add Fathom to the Context Location table**

In the `## Context Location` section, add a new row to the table:

```markdown
| `fathom-transcript-*.txt`    | Fathom meeting transcript (speaker-labeled)   |
```

**Step 3: Add Fathom to the Step 2 reading instructions**

After the Teams threads reading step (item 3 in Step 2), add:

```markdown
4. **Fathom transcripts**: List `fathom-transcript-*.txt` files and read each one. These contain timestamped, speaker-labeled meeting transcripts relevant to the issue.
```

**Step 4: Add Fathom to the example**

In the `## Example` section under "Correct approach", add after the Teams threads step:

```bash
# 6. Fathom transcripts (if any)
cat ~/tmp/context/WA-13902/fathom-transcript-*.txt 2>/dev/null
```

**Step 5: Verify the file is valid markdown**

Read the modified file to confirm formatting is correct.

**Step 6: Commit**

```bash
git add rules/comms/commands/context-fetching.md
git commit -m "feat: add Fathom transcripts to context-fetching workflow"
```

---

### Task 3: Test with the example share URL

**Step 1: Run the script with the example URL**

Run:
```bash
fetch-fathom-transcript.sh -O ~/tmp/context/TEST-FATHOM \
  'https://fathom.video/share/XB2rTP4NEcnV_mDmkF7QoPuK_7gKzkKy?tab=summary&utm_campaign=postmeetingsummary&utm_content=view_recording_link&utm_medium=email'
```

Expected: Script finds the meeting, saves transcript to `~/tmp/context/TEST-FATHOM/fathom-transcript-2026-02-17-1231.txt`

**Step 2: Verify the output file**

Run: `head -20 ~/tmp/context/TEST-FATHOM/fathom-transcript-*.txt`

Expected: Plain text with timestamp/speaker lines like:
```
WA-15829 - QA inquiries - February 17
VIEW RECORDING - 24 mins (No highlights):

---

1:01 - Irina Volinsky (WorkAxle)
  Well, wasn't, right? I saw him in the invite.
```

**Step 3: Clean up test output**

Run: `rm -rf ~/tmp/context/TEST-FATHOM`

---

### Task 4: Squash and verify

**Step 1: Run ruly squash in a temp directory to verify nothing breaks**

Run:
```bash
cd $(mktemp -d) && ruly squash --recipe comms
```

Expected: Clean squash with no errors

**Step 2: Commit all remaining changes**

```bash
cd /Users/patrick/Projects/ruly
git add -A
git commit -m "feat: integrate Fathom transcripts into context system"
```

---

## Notes

### Script Location

Following the existing pattern (`rules/comms/jira/bin/`) for consistency. The script lives at `rules/comms/fathom/bin/fetch-fathom-transcript.sh`.

### How It Works

1. User receives a Fathom share link (e.g., from email after a meeting)
2. User runs: `fetch-fathom-transcript.sh -O ~/tmp/context/WA-12345 '<fathom-url>'`
3. Script fetches the share page HTML (no auth needed)
4. Extracts the `data-page` JSON attribute which contains: call ID, title, `recording.started_at`, `copyTranscriptUrl`
5. Fetches `copyTranscriptUrl` which returns JSON with `plain_text` (speaker-labeled, timestamped transcript)
6. Saves `plain_text` to `~/tmp/context/WA-12345/fathom-transcript-2026-02-17-1430.txt`
7. Context-fetching workflow discovers and reads it alongside other context files

### No API Key Needed

The share token embedded in the URL is the authentication. The script makes two unauthenticated HTTP requests:
1. `GET https://fathom.video/share/{TOKEN}` — returns HTML with embedded JSON
2. `GET https://fathom.video/calls/{CALL_ID}/copy_transcript?token={TOKEN}` — returns `{html, plain_text}`

### Manual vs Automated

Fathom transcript fetching is **manual** — the user runs the script when they have a link. It is NOT auto-dispatched by the `context_fetcher` subagent (unlike Jira/PR/Teams which are auto-fetched). The context_fetcher only needs to **read** existing Fathom transcripts, not fetch them.

### Fathom Share Page Data Structure

The share page HTML contains a `<div id="app" data-page="...">` attribute with HTML-entity-encoded JSON. Key fields:

```json
{
  "props": {
    "call": {
      "id": 571003851,
      "title": "WA-15829 - QA inquiries",
      "duration_minutes": 30,
      "recording": { "started_at": "2026-02-17T16:31:10.181555Z" },
      "started_at": "2026-02-17T16:30:00.000000Z",
      "host": { "email": "irina.volinsky@workaxle.com" }
    },
    "copyTranscriptUrl": "https://fathom.video/calls/571003851/copy_transcript?token=XB2rTP..."
  }
}
```
