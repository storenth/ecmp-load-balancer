# CI/CD Documentation

This document describes the continuous integration and continuous deployment (CI/CD) workflows for the ECMP testing project.

## Overview

The ECMP testing project uses GitHub Actions for automated testing, reporting, and deployment. The CI/CD pipeline ensures code quality, validates configurations, runs comprehensive tests, and generates detailed reports.

## Workflows

### 1. ECMP Testing CI/CD ([`.github/workflows/test.yml`](../.github/workflows/test.yml))

The main testing workflow that runs on every push, pull request, and scheduled execution.

#### Triggers

- **Push to main branch**: Runs the complete test suite
- **Pull requests to main**: Validates changes before merging
- **Manual workflow dispatch**: Allows on-demand testing with custom parameters
- **Scheduled runs**: Daily at 2 AM UTC

#### Jobs

##### lint-and-validate

Validates code quality and configuration files.

**Steps:**
1. Checkout code
2. Set up Python 3.11
3. Install Python dependencies
4. Run flake8 linter
5. Check code formatting with black
6. Validate YAML files with yamllint
7. Validate topology files with containerlab
8. Check shell scripts with shellcheck
9. Validate Python syntax

**Timeout:** 15 minutes

##### deploy-topology

Deploys the network topology for testing.

**Matrix Strategy:**
- Path counts: 2, 3, 4
- Hash policies: L3, L4

**Steps:**
1. Checkout code
2. Set up Docker Buildx
3. Install containerlab
4. Render topology templates
5. Deploy topology using containerlab
6. Wait for containers to be ready
7. Verify deployment
8. Save deployment info
9. Upload deployment artifacts

**Timeout:** 30 minutes

##### run-tests

Executes the ECMP testing suite.

**Matrix Strategy:**
- Path counts: 2, 3, 4
- Hash policies: L3, L4

**Steps:**
1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Create results directory
5. Configure ECMP
6. Start traffic capture
7. Generate test traffic
8. Stop traffic capture
9. Analyze results
10. Generate test results
11. Upload test results
12. Upload Allure results

**Timeout:** 45 minutes

##### generate-reports

Generates comprehensive test reports.

**Matrix Strategy:**
- Path counts: 2, 3, 4
- Hash policies: L3, L4

**Steps:**
1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Download test results
5. Download Allure results
6. Generate Allure report
7. Generate ISO 29119-3 report
8. Generate JSON report
9. Generate HTML report
10. Upload reports as artifacts
11. Generate summary

**Timeout:** 20 minutes

##### cleanup

Cleans up resources after testing.

**Matrix Strategy:**
- Path counts: 2, 3, 4
- Hash policies: L3, L4

**Steps:**
1. Checkout code
2. Install containerlab
3. Destroy topology
4. Clean up Docker resources
5. Verify cleanup

**Timeout:** 10 minutes

**Always runs:** Yes (even if previous jobs fail)

##### status-check

Checks the status of all jobs and generates a workflow summary.

**Steps:**
1. Check job statuses
2. Generate workflow summary

#### Artifacts

All artifacts are retained for 30 days:

- **test-results-{paths}-{policy}**: Test results and captures
- **allure-results-{paths}-{policy}**: Allure test results
- **reports-{paths}-{policy}**: Generated reports (Allure, ISO 29119-3, JSON, HTML)
- **deployment-info-{paths}-{policy}**: Deployment information

#### Environment Variables

```yaml
CONFIG_FILE: config/test_config.yaml
TOPOLOGY_FILE: topology/clab-ecmp-test.yml
RESULTS_DIR: results
VERBOSE: true
```

### 2. Generate Reports ([`.github/workflows/report.yml`](../.github/workflows/report.yml))

Manual workflow for generating reports from existing test results.

#### Triggers

- **Manual workflow dispatch**: Allows on-demand report generation

#### Inputs

- **report_format**: Report format to generate (all, allure, iso29119, json, html)
- **path_count**: Number of ECMP paths (2, 3, 4, all)
- **hash_policy**: Hash policy (L3, L4, all)
- **comment_on_pr**: Comment on PR with report summary (true/false)

#### Steps

1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Download test results
5. Download Allure results
6. Create report directories
7. Generate Allure report (if selected)
8. Generate ISO 29119-3 report (if selected)
9. Generate JSON report (if selected)
10. Generate HTML report (if selected)
11. Generate report summary
12. Upload reports as artifacts
13. Comment on PR (if enabled)
14. Generate workflow summary

**Timeout:** 30 minutes

#### Artifacts

- **reports-{run_number}**: Generated reports

### 3. Scheduled ECMP Testing ([`.github/workflows/scheduled.yml`](../.github/workflows/scheduled.yml))

Scheduled workflow for running tests and trend analysis.

#### Triggers

- **Schedule**: Daily at 2 AM UTC
- **Manual workflow dispatch**: Allows on-demand scheduled testing

#### Inputs

- **run_trend_analysis**: Run trend analysis (true/false)
- **send_notifications**: Send notifications on failure (true/false)

#### Jobs

##### scheduled-tests

Runs the complete test suite.

**Steps:**
1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Set up Docker Buildx
5. Install containerlab
6. Create results directory
7. Deploy topology
8. Wait for containers to be ready
9. Configure ECMP
10. Start traffic capture
11. Generate test traffic
12. Stop traffic capture
13. Analyze results
14. Generate test results
15. Generate Allure report
16. Generate ISO 29119-3 report
17. Generate JSON report
18. Generate HTML report
19. Upload test results
20. Upload reports
21. Upload Allure results

**Timeout:** 60 minutes

##### trend-analysis

Analyzes trends from historical test results.

**Steps:**
1. Checkout code
2. Set up Python 3.11
3. Install dependencies
4. Download historical results
5. Create trends directory
6. Generate trend analysis
7. Generate trend report
8. Upload trend analysis
9. Generate trend summary
10. Upload trend summary

**Timeout:** 20 minutes

##### cleanup

Cleans up resources after testing.

**Steps:**
1. Checkout code
2. Install containerlab
3. Destroy topology
4. Clean up Docker resources
5. Verify cleanup

**Timeout:** 10 minutes

**Always runs:** Yes

##### notify

Sends notifications on failure.

**Steps:**
1. Generate failure notification
2. Create issue on failure
3. Generate workflow summary

**Timeout:** 5 minutes

**Condition:** Runs only if previous jobs fail

##### success-summary

Generates a success summary.

**Steps:**
1. Generate success summary

**Timeout:** 5 minutes

**Condition:** Runs only if all jobs succeed

#### Artifacts

- **scheduled-test-results-{run_number}**: Test results and captures (30 days)
- **scheduled-reports-{run_number}**: Generated reports (30 days)
- **scheduled-allure-results-{run_number}**: Allure test results (30 days)
- **trend-analysis-{run_number}**: Trend analysis results (90 days)
- **trend-summary-{run_number}**: Trend summary (90 days)

### 4. Dependency Updates ([`.github/dependabot.yml`](../.github/dependabot.yml))

Automated dependency updates using Dependabot.

#### Configuration

- **Python dependencies**: Weekly updates on Mondays at 09:00 UTC
- **GitHub Actions**: Weekly updates on Mondays at 09:00 UTC
- **Pull request limit**: 10 for Python, 5 for GitHub Actions
- **Labels**: dependencies, python/github-actions
- **Reviewers**: storenth
- **Assignees**: storenth

#### Groups

- **python-dependencies**: Groups all Python dependencies except pytest
- **github-actions**: Groups all GitHub Actions

## Issue Templates

### Bug Report ([`.github/ISSUE_TEMPLATE/bug_report.md`](../.github/ISSUE_TEMPLATE/bug_report.md))

Template for reporting bugs with the following sections:

- Bug Description
- Steps to Reproduce
- Expected Behavior
- Actual Behavior
- Screenshots / Logs
- Environment (OS, Python, Docker, Containerlab, FRR versions)
- Configuration (Test, Topology, FRR)
- Test Results
- Additional Context
- Possible Solutions
- Related Issues
- Checklist

### Feature Request ([`.github/ISSUE_TEMPLATE/feature_request.md`](../.github/ISSUE_TEMPLATE/feature_request.md))

Template for requesting new features with the following sections:

- Feature Description
- Problem Statement
- Proposed Solution
- Alternatives Considered
- Additional Context
- Impact Assessment (Benefits, Risks)
- Testing Requirements
- Documentation Requirements
- Priority
- Timeline
- Related Issues
- Checklist
- Additional Resources

## Pull Request Template ([`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md))

Template for pull requests with the following sections:

- Description
- Type of Change (Bug fix, New feature, Breaking change, etc.)
- Changes Made
- Testing (Unit tests, Integration tests, End-to-end tests, Manual testing)
- Test Results
- Checklist (Code style, Self-review, Comments, Documentation, Warnings, Tests)
- Documentation
- Breaking Changes
- Migration Guide
- Performance Impact
- Performance Metrics
- CI/CD Status
- Additional Context
- Reviewers
- Related Issues

## Configuration Files

### YAML Linting ([`.yamllint`](../.yamllint))

Configuration for yamllint to validate YAML files:

- Line length: 120 characters (warning)
- Document start: disabled
- Truthy values: true, false, yes, no
- Indentation: 2 spaces
- Brackets, colons, commas, dashes: specific spacing rules
- Octal values: forbidden
- Trailing spaces: enabled
- New lines: Unix style

**Ignored directories:**
- node_modules/
- .git/
- results/
- *.pyc
- __pycache__/

## Workflow Badges

Add these badges to your README.md to display workflow status:

```markdown
![CI/CD](https://github.com/storenth/ecmp/workflows/ECMP%20Testing%20CI/CD/badge.svg)
![Scheduled Tests](https://github.com/storenth/ecmp/workflows/Scheduled%20ECMP%20Testing/badge.svg)
```

## Best Practices

### 1. Workflow Design

- **Modular jobs**: Each job has a single responsibility
- **Matrix strategy**: Test multiple configurations in parallel
- **Fail-fast**: Set to false to allow all matrix combinations to complete
- **Timeouts**: Set appropriate timeouts for each job
- **Always runs**: Cleanup jobs run even if previous jobs fail

### 2. Caching

- **Python dependencies**: Cache pip packages using actions/cache
- **Docker layers**: Cache Docker Buildx layers
- **Cache keys**: Use hashFiles for cache keys

### 3. Artifacts

- **Retention**: 30 days for test results, 90 days for trend analysis
- **Naming**: Use descriptive names with matrix parameters
- **Upload**: Upload only necessary files
- **Download**: Use pattern matching for multiple artifacts

### 4. Error Handling

- **Continue-on-error**: Use for non-critical steps
- **If conditions**: Use to control job execution
- **Exit codes**: Properly handle script failures

### 5. Security

- **Secrets**: Use GitHub Secrets for sensitive data
- **Permissions**: Limit workflow permissions
- **Token**: Use GITHUB_TOKEN with minimal scope

### 6. Documentation

- **Comments**: Add comments for complex steps
- **Descriptions**: Use clear descriptions for jobs and steps
- **Summaries**: Generate workflow summaries for easy review

## Troubleshooting

### Common Issues

#### 1. Containerlab deployment fails

**Symptoms:** Deploy topology job fails

**Solutions:**
- Check Docker is running
- Verify containerlab installation
- Check topology file syntax
- Review container logs

#### 2. Tests timeout

**Symptoms:** Run tests job exceeds timeout

**Solutions:**
- Increase timeout value
- Check network connectivity
- Verify traffic generation parameters
- Review system resources

#### 3. Report generation fails

**Symptoms:** Generate reports job fails

**Solutions:**
- Verify test results exist
- Check report generation scripts
- Review Python dependencies
- Check file permissions

#### 4. Cleanup fails

**Symptoms:** Cleanup job fails

**Solutions:**
- Check containerlab installation
- Verify topology file exists
- Review Docker permissions
- Check for stuck containers

### Debugging

#### Enable verbose logging

Set the `VERBOSE` environment variable to `true`:

```yaml
env:
  VERBOSE: true
```

#### Check workflow logs

1. Go to the Actions tab
2. Select the workflow run
3. Click on the failed job
4. Review the logs

#### Download artifacts

1. Go to the Actions tab
2. Select the workflow run
3. Scroll to Artifacts section
4. Download the relevant artifacts

#### Re-run workflows

1. Go to the Actions tab
2. Select the workflow run
3. Click "Re-run jobs"
4. Select the jobs to re-run

## Maintenance

### Updating Workflows

1. Test changes in a feature branch
2. Create a pull request
3. Review workflow changes
4. Merge after approval

### Updating Dependencies

1. Dependabot will create pull requests
2. Review the changes
3. Test the updates
4. Merge if tests pass

### Monitoring

- Check workflow runs regularly
- Review failed runs
- Monitor artifact storage
- Track trend analysis

## Contributing

When contributing to the CI/CD workflows:

1. Follow GitHub Actions best practices
2. Add appropriate comments
3. Update documentation
4. Test changes thoroughly
5. Use proper error handling
6. Set appropriate timeouts
7. Use caching where possible

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Containerlab Documentation](https://containerlab.dev/)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot)
- [YAML Lint Documentation](https://yamllint.readthedocs.io/)
