---
description: Draft and review Jira comments before posting them
alwaysApply: true
requires:
  - ../../commands.md
---

# Jira Draft

## Overview

Draft, review, and revise Jira comments before posting. **Requires exact phrase "post it" to submit.**

## Usage

```
/jira:draft [your comment content]
```

## Process

1. **Generate draft** from your input
2. **Show preview** with clear borders
3. **Wait for confirmation**:
   - ✅ ONLY "post it" will submit (case-insensitive)
   - ❌ ANY other response = revision request
4. **Revise and repeat** until you type "post it"

## Preview Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📝 DRAFT JIRA COMMENT for [ISSUE-KEY]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Your formatted comment appears here]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Type "post it" to submit this comment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Confirmation Rules

**ONLY these exact phrases work:**
- "post it"
- "Post it"
- "POST IT"

**Everything else triggers revision:**
- "yes, post it" → revision
- "please post it" → revision
- "looks good" → revision
- "submit" → revision
- Any other text → revision

## Example Flow

```
You: /jira:draft fixed the bug in the payment processor
Me: [shows formatted draft]
You: add more technical details
Me: [shows revised draft with details]
You: mention the test coverage too
Me: [shows revised draft with test info]
You: post it
Me: ✅ Posted to PROJ-123
```

## Notes

- Any response except "post it" = revision request
- Maintains context between revisions
- No accidental posts possible