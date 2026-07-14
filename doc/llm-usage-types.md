# LLM Usage Types

Spectra separates LLM usage into two distinct categories, allowing you to optimize for cost, performance, and capability based on the task at hand.

## Overview

### Why Separate Planning from Coding?

**Different tasks require different strengths:**

1. **Strategic Planning** needs:
   - Strong reasoning capabilities
   - Architectural thinking
   - Long-context understanding
   - Better at "what" and "why"

2. **Tactical Coding** needs:
   - Fast code generation
   - Syntax accuracy
   - Pattern recognition
   - Better at "how"

**Cost Optimization:**
- Use expensive, powerful models for planning (happens once per phase)
- Use faster, cheaper models for coding (happens many times)
- Can save 50-70% on LLM costs without sacrificing quality

## Usage Types

### 🎯 Planning (Strategic)

**Used For:**
- `spectra plan` - Breaking roadmaps into atomic tasks
- `spectra map` - Analyzing existing codebases
- Mayor Agent - Coordinating task distribution
- Witness Agent - Monitoring agent health
- Generating documentation and architecture decisions

**Best Models:**
| Provider | Model | Strengths |
|----------|-------|-----------|
| **Claude** | claude-4.5-sonnet | Best reasoning, excellent at architecture |
| **OpenAI** | gpt-5 | Balanced, good context handling |
| **Gemini** | gemini-3.0-pro | Fast, good for quick analysis |

**Example Configuration:**
```bash
spectra config
# Select "Claude" as Planning Provider
```

### 💻 Coding (Tactical)

**Used For:**
- `spectra execute` - Implementing task code
- `spectra start` - Worker agents generating files
- All actual file writing and code generation
- Refactoring and implementation work

**Best Models:**
| Provider | Model | Strengths |
|----------|-------|-----------|
| **Gemini** | gemini-3.0-flash | Fastest, cost-effective |
| **DeepSeek** | deepseek-v3.2 | Code-specialized, efficient |
| **OpenAI** | gpt-5-mini | Balanced speed/quality |
| **Grok** | grok-4.1 | Experimental, fast |

**Example Configuration:**
```bash
spectra config
# Select "Gemini" as Coding Provider
```

## Configuration

### Setting Up Separate Providers

When you run `spectra config`, you'll be prompted for:

1. **API Keys** (for all providers you want to use)
2. **Model Selection** (specific model versions)
3. **Planning Provider** (strategic tasks)
4. **Coding Provider** (tactical tasks)
5. **Default Provider** (legacy fallback)

### Recommended Configurations

#### 1. Quality-First (Best Results)
```
Planning Provider:  Claude (claude-4.5-sonnet)
Coding Provider:    Claude (claude-4.5-sonnet)
```
**Best for**: Production work, critical projects

#### 2. Balanced (Recommended)
```
Planning Provider:  Claude (claude-4.5-sonnet)
Coding Provider:    Gemini (gemini-3.0-flash)
```
**Best for**: Most projects, good quality + speed

#### 3. Speed-First (Fastest)
```
Planning Provider:  Gemini (gemini-3.0-pro)
Coding Provider:    Gemini (gemini-3.0-flash)
```
**Best for**: Rapid prototyping, experiments

#### 4. Cost-Optimized
```
Planning Provider:  Gemini (gemini-3.0-flash)
Coding Provider:    DeepSeek (deepseek-v3.2)
```
**Best for**: Large projects, budget-conscious

#### 5. Code-Specialized
```
Planning Provider:  Claude (claude-4.5-sonnet)
Coding Provider:    DeepSeek (deepseek-v3.2)
```
**Best for**: Complex codebases, refactoring work

## How It Works

### Planning Tasks

When you run:
```bash
spectra plan "Phase 1: Authentication"
```

Spectra uses your **Planning Provider** to:
1. Analyze PROJECT.md and ROADMAP.md
2. Break the phase into atomic tasks
3. Generate structured XML task definitions
4. Create PLAN.md

**Why planning provider?** Strategic thinking, architectural decisions, task decomposition.

### Coding Tasks

When you run:
```bash
spectra execute
# or
spectra start --workers 3
```

Spectra uses your **Coding Provider** to:
1. Read task objectives and file context
2. Generate actual code implementations
3. Write files to disk
4. Create Git commits

**Why coding provider?** Fast code generation, syntax accuracy, implementation focus.

### Multi-Agent Orchestration

With `spectra start`:
- **Mayor & Witness**: Use **Planning Provider** (coordination, monitoring)
- **Workers**: Use **Coding Provider** (actual code generation)

This ensures:
- Strategic oversight remains high-quality
- Code generation remains fast and cost-effective
- Best of both worlds

## Examples

### Example 1: Using Claude for Planning, Gemini for Coding

```bash
# Configure
spectra config
# Enter API keys for both Claude and Gemini
# Select "Claude" as Planning Provider
# Select "Gemini" as Coding Provider

# Use planning provider (Claude)
spectra plan "Phase 1: Setup"
# Claude analyzes your roadmap and creates detailed tasks

# Use coding provider (Gemini Flash)
spectra start --workers 3
# Workers use Gemini Flash for fast code generation
```

### Example 2: Single Provider for Everything

```bash
# Configure
spectra config
# Enter Gemini API key only
# Select "Gemini" for both Planning and Coding

# Both commands use Gemini
spectra plan "Phase 1"
spectra execute
```

### Example 3: Cost-Optimized Workflow

```bash
# Use Claude only for planning (expensive but rare)
spectra plan "Phase 1"  # ~$0.50

# Use DeepSeek for all coding (cheap and frequent)
spectra start --workers 5  # ~$2.00 for entire phase

# Total: ~$2.50 instead of ~$15 with Claude for everything
```

## Migration from v0.1.4

### Automatic Fallback

Existing configurations work automatically:

```yaml
# Old config (still works)
preferred_provider: "gemini"

# Spectra will use "gemini" for both planning and coding
```

### Upgrading Your Config

Run `spectra config` to set up separate providers:

```bash
spectra config
# You'll see new prompts for:
# - Planning Provider
# - Coding Provider
# - Default Provider
```

Your existing API keys are preserved.

## Provider Comparison

### For Planning Tasks

| Provider | Reasoning | Speed | Cost | Recommendation |
|----------|-----------|-------|------|----------------|
| Claude | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 💰💰💰 | **Best** |
| GPT-5 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 💰💰💰 | Great |
| Gemini Pro | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 💰💰 | Good |
| Grok | ⭐⭐⭐ | ⭐⭐⭐⭐ | 💰💰 | Experimental |
| DeepSeek | ⭐⭐ | ⭐⭐⭐ | 💰 | Budget |

### For Coding Tasks

| Provider | Code Quality | Speed | Cost | Recommendation |
|----------|--------------|-------|------|----------------|
| Gemini Flash | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 💰 | **Best** |
| DeepSeek | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 💰 | Great |
| GPT-5 Mini | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 💰💰 | Good |
| Grok | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 💰💰 | Fast |
| Claude | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 💰💰💰 | Premium |

## Technical Implementation

### For Developers

```dart
import 'package:spectra_cli/models/llm_usage_type.dart';
import 'package:spectra_cli/services/llm_service.dart';

final llmService = LLMService();

// Get planning provider
final planningProvider = await llmService.getProviderForUsage(
  LLMUsageType.planning,
);

// Get coding provider
final codingProvider = await llmService.getProviderForUsage(
  LLMUsageType.coding,
);

// Use appropriate provider for task (optional {List<String>? context} parameter)
final response = await planningProvider.generateResponse(prompt);
```

### Configuration Structure

```yaml
# ~/.spectra/.secure/creds.enc (encrypted)
planning_provider: "claude"   # For strategic tasks
coding_provider: "gemini"     # For tactical tasks
preferred_provider: "gemini"  # Legacy fallback
```

## Best Practices

### 1. Use Strong Reasoning for Planning

Planning happens **once per phase** but affects all subsequent tasks:
```bash
# Worth the cost
Planning: Claude (best reasoning)  # $0.50 once
Coding: Gemini Flash (fast)        # $2.00 for 50 tasks
```

### 2. Use Fast Models for Coding

Coding happens **many times** during execution:
```bash
# Not optimal
Coding: Claude                     # $25.00 for 50 tasks

# Better
Coding: Gemini Flash               # $2.00 for 50 tasks
```

### 3. Match Model to Project Size

| Project Size | Planning | Coding |
|--------------|----------|--------|
| Small (< 10 files) | Gemini Pro | Gemini Flash |
| Medium (10-50 files) | Claude | Gemini Flash |
| Large (50+ files) | Claude | DeepSeek |

### 4. Experiment and Iterate

Try different combinations:
```bash
# Week 1: Test with Claude/Gemini
# Week 2: Try Claude/DeepSeek
# Week 3: Measure cost and quality
# Week 4: Pick optimal combination
```

## FAQ

### Q: Can I use the same provider for both?

**A:** Yes! Just select the same provider for both planning and coding. This works well for:
- Small projects
- Prototyping
- When you have credits to burn

### Q: What if I only have one API key?

**A:** No problem! Spectra will use that provider for both planning and coding. The separation is optional.

### Q: Can I change providers mid-project?

**A:** Yes! Run `spectra config` anytime to update provider preferences. Changes take effect immediately.

### Q: Which combination do you recommend?

**A:** For most projects:
- **Planning**: Claude (best reasoning for architecture)
- **Coding**: Gemini Flash (fastest, cheapest code generation)

### Q: What about Grok and DeepSeek?

**A:**
- **Grok**: Experimental, very fast, improving rapidly
- **DeepSeek**: Excellent for code, very cost-effective, great for large projects

### Q: Does this affect my existing projects?

**A:** No! Existing configurations automatically fallback to your preferred provider. The separation is backward compatible.

---

## Summary

LLM Usage Types allow you to:
- ✅ **Optimize costs** - Use expensive models only where it matters
- ✅ **Maximize speed** - Fast models for frequent operations
- ✅ **Maintain quality** - Strong models for critical decisions
- ✅ **Stay flexible** - Easy to experiment and change

**Recommended**: Claude for planning, Gemini Flash for coding. Best balance of quality, speed, and cost.
