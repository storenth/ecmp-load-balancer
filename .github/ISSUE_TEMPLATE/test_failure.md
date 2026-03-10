---
name: Test Failure Report
about: Report a test failure in the ECMP Testing CI/CD pipeline
title: '[TEST FAILURE] '
labels: test-failure
assignees: ''
---

## Test Failure Description

A clear and concise description of the test failure.

## Workflow Run Information

- **Workflow**: ECMP Testing CI/CD
- **Run ID**: [run-id]
- **Run URL**: [workflow-run-url]
- **Branch**: [branch-name]
- **Commit**: [commit-sha]
- **Trigger**: [manual/scheduled/push/pull_request]
- **Triggered By**: [username]

## Failed Job

- **Job Name**: [job-name]
- **Job Status**: [failed/cancelled]
- **Failure Step**: [step-name]

## Test Configuration

- **Test Scenario**: [scenario-name]
- **Test Duration**: [duration] seconds
- **Packet Count**: [count]
- **Configuration File**: [config-file]
- **Test ID**: [test-id]

## Error Details

### Error Message

```
[Paste the error message here]
```

### Error Logs

```bash
# Paste relevant error logs here
```

### Stack Trace (if applicable)

```
[Paste stack trace here]
```

## Test Results

### Expected Results

Describe what the expected test results should be.

### Actual Results

Describe what the actual test results were.

### Test Metrics

- **Total Packets**: [count]
- **Packets per Path**: [list]
- **Distribution Variance**: [percentage]
- **Chi-Square P-Value**: [value]
- **Test Status**: [passed/failed]

## Environment

- **OS**: [e.g., Ubuntu 22.04]
- **Python Version**: [e.g., 3.11.0]
- **Containerlab Version**: [e.g., 0.50.0]
- **FRRouting Version**: [e.g., 8.4]
- **Docker Version**: [e.g., 24.0.0]
- **Allure Version**: [e.g., 2.24.0]

## Reproduction Steps

Steps to reproduce the test failure:

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Frequency

- [ ] Always fails
- [ ] Intermittent (fails ~X% of the time)
- [ ] First time failure

## Recent Changes

Have there been any recent changes that might have caused this failure?

- [ ] Yes, I made changes
- [ ] Yes, someone else made changes
- [ ] No recent changes

If yes, please describe the changes:

## Artifacts

- [ ] Setup artifacts
- [ ] Deployment artifacts
- [ ] Configuration artifacts
- [ ] Test artifacts
- [ ] Analysis artifacts
- [ ] Allure report

## Screenshots

If applicable, add screenshots to help explain the test failure.

## Possible Root Cause

If you have a hypothesis about the root cause, please describe it here.

## Possible Solution

If you have a possible solution, please describe it here.

## Priority

- [ ] Critical (blocks all testing)
- [ ] High (blocks important testing)
- [ ] Medium (affects some testing)
- [ ] Low (minor issue)

## Checklist

- [ ] I have searched for similar test failures
- [ ] I have provided workflow run information
- [ ] I have provided error logs
- [ ] I have provided test configuration
- [ ] I have provided environment information
- [ ] I have described reproduction steps
- [ ] I have considered recent changes
