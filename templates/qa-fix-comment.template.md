<!--
QA-Fix Jira Comment — Local SSOT
Stage 5 step 2 — Sprint Lead writes this BEFORE posting to Jira.
The same content is posted via mcp__wrtn-mcp__jira_add_comment.
On successful post + transition, .posted marker file is created alongside this file.
Path: runs/<sprint-id>/qa-fix/jira-comments/<TICKET-ID>.md
-->

## Fix Ready for QA — <SPRINT-ID> / group-<N>

**Root Cause**
<One paragraph. Why did this bug happen? "Unknown" is not allowed. Call out any pattern violations or omissions.>

**Fix Summary**
<One paragraph. What changed and how. User-facing change. Do not paste raw diffs.>

**Verification Steps**
1. <Original Steps to Reproduce step 1 + expected result after fix>
2. <Original step 2 + expected result>
3. ...

**Evidence**
- PR: <BE PR url> / <FE PR url>  ← always required
- Changed files: <key files — absolute path or PR diff link>
- Regression test: <test/flow file path>      ← when regression coverage is feasible
- Screenshot: <before/after URL or attachment ref>  ← UI/copy cases
- N/A — <reason regression automation is impractical>          ← required when evidence is omitted

**Related**
- Sprint: <sprint-id>
- Group: <group-id> (other tickets fixed alongside: <TICKET-IDs>)
- KB Pattern Candidate: <yes — kb-candidates/<TICKET-ID>.yaml | no>

<!--
PARTIAL EVIDENCE: If you couldn't satisfy every evidence requirement, prepend a warning marker to the heading line:
## [PARTIAL] Fix Ready for QA — <SPRINT-ID> / group-<N>
-->
