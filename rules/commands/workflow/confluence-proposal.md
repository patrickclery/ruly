---
description:
globs:
alwaysApply: true
---

# Change Proposals Rules

## 📋 Change Proposal Template

### 🏗️ Standard Template Structure

```markdown
## 🚀 Proposal: <proposal title>

📊 Current Status: <any of: "proposed", "draft", "approved", "rejected", "done", "cancelled">

## 🎯 Problem statement

  <briefly describe the problem this proposal aims to address>

## ✨ Ideal situation

  <describe the ideal situation if this problem was solved>

## 🔍 Reality

  <describe the problem and current situation more in depth>

### ⚠️ Consequences

  <describe the consequences of not solving this problem>

## 💡 Proposed solution

  <describe the proposed solution>

## 📅 Implementation plan

  <describe the timeline and milestones>

## ⚠️ Risks

| Risk   | Mitigation   | Impact                            |
| ------ | ------------ | --------------------------------- |
| <risk> | <mitigation> | <any of: "low", "medium", "high"> |

## ✅ Approvals

| Submitted by | <my name> |
| ------------ | --------- |
| Approved by  |           |
```

## 🎨 Formatting Guidelines

### 📝 Content Requirements

- 😊 **Positive tone** - Focus on solutions and opportunities
- 🎯 **Concrete examples** - Include specific examples for:
  - Problem statement scenarios
  - Ideal situation outcomes
  - Current reality situations
- 😀 **Emoji prefixes** - Every line and header should start with relevant emoji
- 📖 **Clear structure** - Follow the template exactly for consistency

### 🔧 Solution Priority Framework

#### 🤖 Priority 1: Automated Solutions (Highest)

- **GitHub Actions** workflows for CI/CD automation
- **CircleCI** pipelines for build/test automation
- **Git hooks** for commit validation and enforcement
- **Automated checks** that require zero human intervention
- **Example**: Enforce commit message format with pre-commit hooks

#### 👥 Priority 2: Manual Processes (Medium)

- **Jira workflows** and ticket management
- **Slack communications** and notifications
- **GitHub PR processes** (team uses GitHub only for PRs, not issues)
- **Documentation updates** and knowledge sharing
- **Example**: Create Jira templates for bug reporting

#### 🛠️ Priority 3: New Tools/Services (Lowest)

- **Ruby on Rails** applications
- **React** frontend components
- **PostgreSQL** database solutions
- **Redis/Sidekiq** background processing
- **Node.js** microservices
- **Example**: Build internal dashboard for metrics tracking

## 📍 Team Communication Context

### 💬 Communication Channels

- **Jira** - Primary for task/issue tracking and project management
- **Slack** - Team communication and quick discussions
- **GitHub** - Code reviews and pull requests only (not for issues/bugs)

### 🔄 Workflow Integration

- All proposals should consider existing Jira workflows
- Solutions should integrate with current Slack notification patterns
- GitHub integration limited to PR automation and code quality checks

## 📊 Examples of Good Proposals

### 🤖 Automation Example

```markdown
## 🚀 Proposal: Automated Code Quality Enforcement

📊 Current Status: proposed

## 🎯 Problem statement

🐛 Inconsistent code quality leads to bugs in production and slower code reviews

## ✨ Ideal situation

✅ All code automatically meets quality standards before reaching reviewers

## 💡 Proposed solution

🔧 Implement pre-commit hooks that run RuboCop and tests automatically
```

### 👥 Process Example

```markdown
## 🚀 Proposal: Standardized Bug Reporting

📊 Current Status: draft

## 🎯 Problem statement

🔍 Bug reports lack essential information, causing delays in resolution

## 💡 Proposed solution

📋 Create Jira templates with required fields and automated Slack notifications
```
