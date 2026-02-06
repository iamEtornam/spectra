# LLM Architecture: Planning vs Coding Separation

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SPECTRA v0.1.5                              │
│                  LLM Usage Separation                            │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┐  ┌─────────────────────────────┐
│   🎯 PLANNING (Strategic)   │  │   💻 CODING (Tactical)      │
├─────────────────────────────┤  ├─────────────────────────────┤
│                             │  │                             │
│  Commands:                  │  │  Commands:                  │
│  • spectra plan             │  │  • spectra execute          │
│  • spectra map              │  │  • spectra start (workers)  │
│                             │  │                             │
│  Agents:                    │  │  Agents:                    │
│  • Mayor (coordination)     │  │  • Workers (implementation) │
│  • Witness (monitoring)     │  │                             │
│                             │  │                             │
│  Tasks:                     │  │  Tasks:                     │
│  • Break roadmap into tasks │  │  • Generate actual code     │
│  • Analyze architecture     │  │  • Write files to disk      │
│  • Strategic decisions      │  │  • Implement features       │
│  • Documentation gen        │  │  • Refactor code            │
│                             │  │                             │
│  Recommended:               │  │  Recommended:               │
│  • Claude (reasoning)       │  │  • Gemini Flash (speed)     │
│  • GPT-5 (balanced)         │  │  • DeepSeek (code-focused)  │
│  • Gemini Pro (fast)        │  │  • GPT-5 Mini (balanced)    │
│                             │  │                             │
│  Frequency: LOW             │  │  Frequency: HIGH            │
│  Cost/Use: HIGH             │  │  Cost/Use: LOW              │
└─────────────────────────────┘  └─────────────────────────────┘
              │                              │
              │                              │
              ▼                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      LLMService                                  │
│                                                                  │
│  getProviderForUsage(LLMUsageType.planning)  → Planning Provider│
│  getProviderForUsage(LLMUsageType.coding)    → Coding Provider  │
│                                                                  │
│  Fallback Chain:                                                │
│  1. Specific provider (planningProvider/codingProvider)         │
│  2. Preferred provider (preferredProvider)                      │
│  3. Default (gemini)                                            │
└─────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   SpectraConfig (Encrypted)                      │
│                                                                  │
│  API Keys:                                                       │
│  • geminiKey, openaiKey, claudeKey, grokKey, deepseekKey        │
│                                                                  │
│  Provider Configuration:                                         │
│  • planningProvider    (e.g., "claude")                         │
│  • codingProvider      (e.g., "gemini")                         │
│  • preferredProvider   (legacy fallback)                        │
│                                                                  │
│  Storage: ~/.spectra/.secure/creds.enc (Encrypted)              │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### Planning Task (spectra plan)

```
User Command
    │
    ├─ spectra plan "Phase 1"
    │
    ▼
PlanCommand
    │
    ├─ Load PROJECT.md & ROADMAP.md
    ├─ Get provider for LLMUsageType.planning
    │
    ▼
LLMService
    │
    ├─ Check config.planningProvider → "claude"
    ├─ Load Claude API key
    ├─ Create ClaudeProvider
    │
    ▼
Claude LLM (Strategic)
    │
    ├─ Analyze project context
    ├─ Break phase into atomic tasks
    ├─ Generate XML task structure
    │
    ▼
Write PLAN.md
    │
    └─ Task breakdown complete ✅
```

### Coding Task (spectra execute)

```
User Command
    │
    ├─ spectra execute
    │
    ▼
ExecuteCommand
    │
    ├─ Load PLAN.md
    ├─ Parse tasks
    ├─ Get provider for LLMUsageType.coding
    │
    ▼
LLMService
    │
    ├─ Check config.codingProvider → "gemini"
    ├─ Load Gemini API key
    ├─ Create GeminiProvider
    │
    ▼
Gemini Flash LLM (Tactical)
    │
    ├─ Read file context
    ├─ Generate code implementation
    ├─ Format as XML <file_content>
    │
    ▼
Write Files & Commit
    │
    └─ Implementation complete ✅
```

### Multi-Agent Orchestration (spectra start)

```
User Command
    │
    ├─ spectra start --workers 3
    │
    ▼
OrchestratorService
    │
    ├─ Get planning provider → Claude
    ├─ Get coding provider → Gemini
    │
    ▼
Initialize Agents
    │
    ├─ Mayor-1 (Claude) ────────► Coordinates task distribution
    ├─ Witness-1 (Claude) ──────► Monitors agent health
    ├─ Worker-1 (Gemini) ───────► Generates code (task 1)
    ├─ Worker-2 (Gemini) ───────► Generates code (task 2)
    └─ Worker-3 (Gemini) ───────► Generates code (task 3)
    │
    ▼
Parallel Execution
    │
    └─ All tasks complete ✅
```

## Configuration Flow

### Setting Up

```
User runs: spectra config
    │
    ▼
ConfigCommand
    │
    ├─ Prompt for API keys
    ├─ Prompt for model selections
    ├─ NEW: Prompt for planning provider
    ├─ NEW: Prompt for coding provider
    ├─ Prompt for default provider
    │
    ▼
SpectraConfig
    │
    ├─ planningProvider = "claude"
    ├─ codingProvider = "gemini"
    ├─ preferredProvider = "gemini"
    │
    ▼
SecureStorageService
    │
    ├─ Encrypt config with PBKDF2
    ├─ Store in ~/.spectra/.secure/creds.enc
    │
    └─ Configuration saved ✅
```

## Provider Selection Logic

### Planning Provider Resolution

```dart
getProviderForUsage(LLMUsageType.planning)
    │
    ├─ Check config.planningProvider
    │   ├─ If set → Use it
    │   └─ If not set ↓
    │
    ├─ Check config.preferredProvider
    │   ├─ If set → Use it
    │   └─ If not set ↓
    │
    └─ Default to "gemini"
```

### Coding Provider Resolution

```dart
getProviderForUsage(LLMUsageType.coding)
    │
    ├─ Check config.codingProvider
    │   ├─ If set → Use it
    │   └─ If not set ↓
    │
    ├─ Check config.preferredProvider
    │   ├─ If set → Use it
    │   └─ If not set ↓
    │
    └─ Default to "gemini"
```

## Cost Optimization Example

### Scenario: 20-task project

#### Before (Single Provider)
```
All tasks use Claude:
├─ spectra plan: $0.50
└─ spectra execute (20 tasks): $20.00
Total: $20.50
```

#### After (Separated Providers)
```
Planning uses Claude, Coding uses Gemini:
├─ spectra plan: $0.50 (Claude - once)
└─ spectra execute (20 tasks): $1.50 (Gemini - 20x)
Total: $2.00

Savings: $18.50 (90%)
```

## Speed Optimization Example

### Scenario: 15-task rapid development

#### Before (Claude for everything)
```
Average response time: 3.2s per task
├─ spectra plan: 3.2s
└─ spectra execute (15 tasks): 48s
Total: 51.2s
```

#### After (Gemini for coding)
```
Planning: Claude 3.2s, Coding: Gemini 0.8s avg
├─ spectra plan: 3.2s (Claude - strategic)
└─ spectra execute (15 tasks): 12s (Gemini - tactical)
Total: 15.2s

Speedup: 3.4x faster
```

## Agent Role Mapping

### Mayor Agent
- **Role**: Strategic coordination
- **Provider**: Planning
- **Reasoning**: Needs to understand project goals, assign tasks intelligently
- **Why**: High-level decision making

### Witness Agent
- **Role**: Health monitoring
- **Provider**: Planning
- **Reasoning**: Analyzes agent behavior, detects issues
- **Why**: Requires understanding of system state

### Worker Agents
- **Role**: Task implementation
- **Provider**: Coding
- **Reasoning**: Generates actual code, writes files
- **Why**: Needs speed and code accuracy

## Configuration Recommendations

### By Project Type

```
Startup/Prototype:
├─ Planning: Gemini Pro (fast decisions)
└─ Coding: Gemini Flash (rapid iteration)

Production App:
├─ Planning: Claude (best architecture)
└─ Coding: Gemini Flash (reliable, fast)

Enterprise System:
├─ Planning: Claude (critical decisions)
└─ Coding: DeepSeek (code quality, cost-effective)

Open Source:
├─ Planning: Claude (community standards)
└─ Coding: DeepSeek (efficient, documented)
```

### By Budget

```
Premium ($$$):
├─ Planning: Claude 4.5
└─ Coding: Claude 4.5

Balanced ($$):
├─ Planning: Claude 4.5
└─ Coding: Gemini Flash

Budget ($):
├─ Planning: Gemini Flash
└─ Coding: DeepSeek
```

### By Speed Priority

```
Quality-First (slower):
├─ Planning: Claude
└─ Coding: Claude

Balanced:
├─ Planning: Claude
└─ Coding: Gemini

Speed-First (fastest):
├─ Planning: Gemini Pro
└─ Coding: Gemini Flash
```

---

## Summary

The LLM separation architecture enables:
- ✅ **Smart Resource Allocation**: Right model for right task
- ✅ **Cost Optimization**: 50-90% savings possible
- ✅ **Speed Optimization**: 2-4x faster execution
- ✅ **Quality Maintenance**: Best models where it matters
- ✅ **Full Flexibility**: Easy to experiment and optimize

**Key Insight**: Strategic thinking (rare, high-impact) deserves powerful models. Tactical execution (frequent, repetitive) deserves fast models.
