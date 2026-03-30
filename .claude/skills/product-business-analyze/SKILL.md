---
name: product-business-analyze
description: |
  Product and business impact analysis methodology. Assess user impact, priority, scope,
  and feasibility. Use when analyzing bugs or features from a product perspective.

  Trigger keywords: "assess impact", "product analysis", "priority assessment", "scope analysis"
user-invocable: false
---

# Product & Business Analysis

Analyze: $ARGUMENTS

## Framework

For each issue/feature, assess:

| Dimension | Key Questions |
|-----------|--------------|
| **Impact** | How many users affected? Business criticality? |
| **Complexity** | Technical difficulty, unknowns, dependencies? |
| **Risk** | What could go wrong? Security/privacy implications? |
| **Effort** | Rough estimation (S/M/L/XL)? |

## Priority Assessment (MoSCoW)

| Priority | Criteria |
|----------|----------|
| **Must-have** | Critical for launch, no workarounds |
| **Should-have** | Important but not blocking |
| **Could-have** | Nice to have, low effort |
| **Won't-have** | Explicitly out of scope |

## Bug Impact Assessment

When analyzing a bug:

1. **Severity**: How bad is it when it happens?
   - Critical: Data loss, crash, security breach
   - High: Feature broken, no workaround
   - Medium: Feature degraded, workaround exists
   - Low: Cosmetic, minor inconvenience

2. **Scope**: How many users are affected?
   - All users / specific user segment / edge case only

3. **Frequency**: How often does it occur?
   - Always / often / sometimes / rare

4. **Business Impact**: Revenue, reputation, compliance?

## Feature Scope Assessment

When analyzing a feature:

1. **Requirements Breakdown**
   - Functional requirements (what it does)
   - Non-functional requirements (performance, security, accessibility)
   - Implicit requirements (not stated but expected)

2. **Affected Modules**
   - Use `explore-codebase("medium: [feature] implementation")` to map scope
   - List modules, files, and interfaces affected

3. **Dependencies**
   - External: APIs, services, third-party libraries
   - Internal: Other features, shared components

4. **Risk Assessment**
   - Technical risks (new technology, complex integration)
   - Schedule risks (dependencies, unknowns)
   - Quality risks (test coverage gaps)

## Firebase Crash Assessment

When crash data is available:

| Field | What It Tells You |
|-------|-------------------|
| **Issue Title** | Class/method where crash occurred - start investigation here |
| **Subtitle** | Exception message - often contains root cause hint |
| **Error Type** | FATAL (crash), NON_FATAL (handled) |
| **Signals** | FRESH (new), REGRESSED (returned), REPETITIVE (ongoing) |
| **Affected Versions** | When did it start? Regression? |
| **User Impact** | Event count + unique users |
| **Stacktrace** | Full call chain - find the code path to fix |

**Firebase analysis workflow:**
```
1. Parse stacktrace → identify crash location (file:line)
2. explore-codebase → find the code and surrounding context
3. Analyze: Why does this code path fail?
4. Check: Is this a regression? What changed?
5. Propose: Root cause hypothesis + fix approach
```

## Acceptance Criteria Dimensions

| Dimension | Key Questions |
|-----------|--------------|
| **Functionality** | Core features for launch? |
| **Usability** | User-friendliness, accessibility? |
| **Reliability** | Error handling, recovery, edge cases? |
| **Performance** | Speed, memory, battery? |
| **Supportability** | Logging, debugging, maintenance? |

## Quality Checklist

Before finalizing any analysis:
- [ ] Severity is exactly one of: Critical, High, Medium, Low — with concrete justification
- [ ] Scope specifies concrete user segment (e.g., "all users on v1.9.8+", not "some users")
- [ ] Priority is exactly one of: Must-have, Should-have, Could-have, Won't-have
- [ ] User Impact describes who is affected, how many, how badly, how often
- [ ] All functional requirements from the description addressed (none skipped)
- [ ] Non-functional requirements considered: performance, security, accessibility
- [ ] Edge cases and error handling defined
- [ ] Affected Modules table lists specific modules with concrete impact descriptions
- [ ] Risk Assessment table has ≥1 row with Likelihood + Impact + Mitigation
- [ ] Recommendations are prioritized and actionable (not vague suggestions)
- [ ] For bugs: frequency assessment based on evidence (crash data, user reports), not guesswork
- [ ] For features: effort estimate (S/M/L/XL) with rationale
- [ ] Testing strategy outlined with concrete test cases
- [ ] Migration/rollback plan if applicable

## Output Format

```markdown
## Impact Assessment

### Severity: [Critical/High/Medium/Low]
### Scope: [All users / Segment / Edge case]
### Priority: [Must-have / Should-have / Could-have]

### User Impact
[Who is affected, how badly, how often]

### Business Impact
[Revenue, reputation, compliance implications]

### Affected Modules
| Module | Impact |
|--------|--------|
| TTServiceKit | [what changes] |
| TTMessaging | [what changes] |

### Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | High/Med/Low | High/Med/Low | [mitigation] |

### Recommendations
1. [Prioritized action items]
```
