# Execution Modes

Spectra supports three execution modes, giving you full control over how AI is used in your development workflow.

## Overview

**Use Spectra for what you need:**
- Just planning? ✅ Use Manual Mode
- Full automation? ✅ Use Automatic Mode  
- Want to review? ✅ Use Interactive Mode

You're in control of how much AI assistance you want.

---

## 🎯 Three Execution Modes

### 1. Automatic Mode (Default)

**What It Does:**
- AI plans tasks (`spectra plan`)
- AI generates code automatically (`spectra execute`)
- AI writes files to disk
- AI commits changes to Git

**Best For:**
- Rapid prototyping
- Greenfield projects
- Boilerplate generation
- Quick MVPs
- Full autonomous development

**Example:**
```bash
# Configure
spectra config
# Select "Automatic" execution mode

# Plan
spectra plan "Phase 1: Auth"
✅ 8 tasks created

# Execute automatically
spectra execute
✅ AI generates all code
✅ Files written automatically
✅ Git commits created
```

---

### 2. Manual Mode (Planning Only)

**What It Does:**
- AI plans tasks (`spectra plan`) ✅
- Displays task breakdown
- **YOU implement the code manually**
- You commit when ready

**Best For:**
- Learning project architecture
- Complex business logic
- Manual code review required
- Using your IDE/GitHub Copilot for coding
- When you want AI suggestions but human implementation

**Example:**
```bash
# Configure
spectra config
# Select "Manual" execution mode

# Plan with AI
spectra plan "Phase 1: Auth"
✅ 8 tasks created by AI

# View tasks (no code generation)
spectra execute --manual

📋 Manual Execution Mode - 8 tasks to implement:
─────────────────────────────────────────────────────
Task 1/8: #task-001
Name: Create User Model
Objective: Create user data model with auth fields
Files: lib/models/user.dart
Verification: Model compiles
Acceptance: User model complete
─────────────────────────────────────────────────────
...

✅ Task list displayed. Implement manually!

# You implement in your IDE
$ code lib/models/user.dart
# Write the code yourself

# Commit when ready
$ git add .
$ git commit -m "Create user model"
```

---

### 3. Interactive Mode (Review & Approve)

**What It Does:**
- AI plans tasks
- AI generates code suggestions
- **YOU review each file before applying**
- You can edit suggestions
- You approve commits

**Best For:**
- Production code
- Critical systems
- Learning from AI
- Code review workflow
- Hybrid development

**Example:**
```bash
# Configure
spectra config
# Select "Interactive" execution mode

# Plan
spectra plan "Phase 1: Auth"

# Execute interactively
spectra execute

Task 1/8: Create User Model
AI suggests:
─────────────────────────────────────────────────────
class User {
  final String id;
  final String email;
  ...
}
─────────────────────────────────────────────────────

Options:
  [A] Apply as-is
  [E] Edit suggestion
  [S] Skip task
  [Q] Quit

> A

✅ File written: lib/models/user.dart

Commit message: User model complete
  [Y] Commit now
  [N] Skip commit
  [E] Edit message

> Y

✅ Changes committed
```

---

## Configuration

### Setting Execution Mode

#### During Initial Setup

```bash
spectra config

# You'll be prompted:
Execution Mode:
  1. Automatic (AI generates code)       ← Default
  2. Manual (AI plans, you code)        ← Planning only
  3. Interactive (AI suggests, you review)

Select: 2
```

#### Change Anytime

```bash
# Reconfigure
spectra config
# Select different execution mode
```

### Per-Command Override

You can override the configured mode per-command:

```bash
# Force manual mode (even if config says automatic)
spectra execute --manual
spectra start --manual

# Force automatic mode (even if config says manual)
spectra execute --auto
```

---

## Comparison

| Feature | Automatic | Manual | Interactive |
|---------|-----------|--------|-------------|
| AI Plans Tasks | ✅ Yes | ✅ Yes | ✅ Yes |
| AI Generates Code | ✅ Yes | ❌ No | ✅ Yes |
| AI Writes Files | ✅ Yes | ❌ No | 👤 User decides |
| User Reviews Code | ❌ No | 👤 Always | ✅ Yes |
| Speed | ⚡⚡⚡ Fast | 👤 User-paced | ⚡⚡ Medium |
| Control | ⚡ Minimal | 👤👤👤 Full | 👤👤 High |
| Best For | Prototyping | Learning | Production |

---

## Use Cases

### Use Case 1: AI for Planning, Manual for Coding

**Scenario**: You want AI to break down tasks but prefer writing code yourself.

```bash
# Configure
spectra config
> Execution Mode: Manual

# AI creates the plan
spectra plan "E-commerce Platform"
✅ AI breaks down into 20 tasks

# View the breakdown
spectra execute --manual
📋 20 tasks displayed with details

# You implement
# - Use your favorite IDE
# - Reference AI task descriptions
# - Control every line of code

# Commit as you go
git commit -m "Implemented task 1"
```

**Benefits**:
- AI handles architecture planning
- You control implementation
- Learn from AI's task breakdown
- Use your existing workflow

---

### Use Case 2: Full AI Automation

**Scenario**: Rapid prototyping or greenfield project.

```bash
# Configure
spectra config
> Execution Mode: Automatic

# Let AI do everything
spectra plan "MVP Features"
spectra execute
# or
spectra start --workers 5

# AI generates all code
# Files written automatically
# Commits created automatically
```

**Benefits**:
- Fastest possible development
- Focus on architecture, not implementation
- Great for MVPs and prototypes

---

### Use Case 3: Mixed Workflow

**Scenario**: Use AI for boilerplate, manual for business logic.

```bash
# Configure automatic mode by default
spectra config
> Execution Mode: Automatic

# Let AI handle boilerplate
spectra plan "Phase 1: Setup & Models"
spectra execute
✅ Models, configs, utils generated by AI

# Switch to manual for critical logic
spectra plan "Phase 2: Payment Processing"
spectra execute --manual
📋 Tasks displayed
# You implement payment logic manually
```

**Benefits**:
- AI handles tedious work
- You control critical code
- Best of both worlds

---

## Configuration Examples

### Scenario: Planning-Only Tool

```yaml
# Use Spectra purely for planning
execution_mode: "manual"
planning_provider: "claude"
# No coding_provider needed
```

**Workflow:**
1. `spectra plan` - AI creates task breakdown
2. `spectra execute --manual` - View tasks
3. Implement in your IDE
4. Commit manually

---

### Scenario: Full Automation

```yaml
# Use Spectra for everything
execution_mode: "automatic"
planning_provider: "claude"
coding_provider: "gemini"
```

**Workflow:**
1. `spectra plan` - AI plans
2. `spectra start --workers 3` - AI implements
3. Review and adjust as needed

---

### Scenario: Review-Based Workflow

```yaml
# AI generates, you approve
execution_mode: "interactive"
planning_provider: "claude"
coding_provider: "gemini"
```

**Workflow:**
1. `spectra plan` - AI plans
2. `spectra execute` - AI suggests, you review
3. Approve or edit each file
4. Control final output

---

## Command Reference

### `spectra execute`

```bash
# Use configured mode
spectra execute

# Force manual mode
spectra execute --manual
spectra execute -m

# Force automatic mode
spectra execute --auto
spectra execute -a
```

### `spectra start`

```bash
# Use configured mode
spectra start --workers 3

# Force manual mode (show task assignments)
spectra start --manual
spectra start -m

# Automatic mode (default)
spectra start --workers 3
```

---

## Best Practices

### When to Use Manual Mode

✅ **Use Manual Mode When:**
- Learning a new codebase
- Working on critical business logic
- Company policy requires human review
- Using Spectra as a planning tool only
- You have your own coding workflow (IDE, Copilot)

❌ **Don't Use Manual Mode When:**
- Rapid prototyping
- Generating boilerplate
- Working under time pressure
- You trust the AI for implementation

### When to Use Automatic Mode

✅ **Use Automatic Mode When:**
- Building MVPs quickly
- Generating repetitive code
- Working on greenfield projects
- You trust the AI's output
- Time is critical

❌ **Don't Use Automatic Mode When:**
- Working on production systems (use interactive)
- Learning a new pattern
- Security-critical code
- You want full control

### When to Use Interactive Mode

✅ **Use Interactive Mode When:**
- Deploying to production
- Learning from AI suggestions
- Want to verify every change
- Building critical systems
- Teaching/mentoring scenarios

---

## FAQ

### Q: Can I change modes mid-project?

**A:** Yes! Run `spectra config` anytime or use flags:
```bash
# Switch to manual for next phase
spectra execute --manual

# Back to automatic
spectra execute --auto
```

### Q: What if I forget the mode?

**A:** Spectra will use your configured mode. Check with:
```bash
cat ~/.spectra/.secure/creds.enc  # (encrypted, can't read)
# Or just try:
spectra execute --manual  # Will show tasks if manual works
```

### Q: Can I use Spectra only for planning?

**A:** Absolutely! That's what manual mode is for:
```bash
spectra config
> Execution Mode: Manual
> Planning Provider: Claude
# You don't even need a coding provider!

spectra plan "Your Project"
spectra execute --manual
# Implement everything yourself
```

### Q: Does manual mode still use LLM?

**A:** Yes, but only for planning:
- `spectra plan` uses your planning provider (Claude, etc.)
- `spectra execute --manual` just displays the tasks (no LLM)
- You implement the code yourself

### Q: Can I mix modes?

**A:** Yes! Use flags to override:
```bash
# Manual for critical tasks
spectra plan "Payment System"
spectra execute --manual

# Automatic for boilerplate
spectra plan "Models & DTOs"
spectra execute --auto
```

---

## Migration

### From v0.1.4 (Automatic Only)

All existing workflows continue to work:
```bash
# v0.1.4 behavior (automatic by default)
spectra execute  # Generates code

# v0.1.5 behavior (same by default)
spectra execute  # Generates code

# v0.1.5 new option
spectra execute --manual  # Just shows tasks
```

No breaking changes!

---

## Summary

Execution modes give you flexibility:

- 🤖 **Automatic**: Full AI automation (fastest)
- 👤 **Manual**: AI plans, you code (most control)
- 🤝 **Interactive**: AI suggests, you review (balanced)

**Use Spectra your way:**
- Just for planning? Perfect.
- Full automation? Great.
- Mix of both? Excellent.

You choose how much AI assistance you want at every step.

