# Migration Guide: v0.1.4 → v0.1.5

This guide helps existing Spectra users migrate to version 0.1.5 with minimal disruption.

## What's New in v0.1.5

1. **Encrypted API Key Storage** - No more plain-text credentials
2. **LLM Usage Type Separation** - Different providers for planning vs coding
3. **Enhanced Test Coverage** - 85%+ coverage with 105+ tests
4. **Improved Documentation** - Security and testing guides

## Automatic Migrations

### 1. API Key Encryption (Automatic ✅)

**What Happens:**
- First command you run will detect `~/.spectra/config.yaml`
- All keys are encrypted and stored in `~/.spectra/.secure/creds.enc`
- Legacy `config.yaml` is automatically deleted
- You don't need to do anything!

**Example:**
```bash
# After upgrading to v0.1.5
$ spectra progress

# Behind the scenes:
# ✅ Detected config.yaml
# ✅ Migrated to encrypted storage
# ✅ Deleted config.yaml
# ✅ Command continues normally
```

### 2. Provider Configuration (Backward Compatible ✅)

**What Happens:**
- Your `preferred_provider` setting still works
- It's automatically used for both planning and coding
- No action required!

**Example:**
```yaml
# Old config (still works)
preferred_provider: "gemini"

# Spectra internally uses:
# planning_provider: "gemini" (fallback)
# coding_provider: "gemini" (fallback)
```

## Optional: Configure Separate Providers

### Why Configure Separately?

**Cost Savings**: 50-70% reduction in LLM costs
- Use Claude for planning (happens once per phase)
- Use Gemini Flash for coding (happens many times)

**Performance**: Faster execution
- Strategic planning uses reasoning-optimized models
- Code generation uses speed-optimized models

### How to Configure

```bash
spectra config
```

**New Prompts You'll See:**
1. API Keys (same as before)
2. Model Selection (same as before)
3. **NEW**: Planning Provider selection
4. **NEW**: Coding Provider selection
5. Default Provider (legacy fallback)

### Recommended Configuration

For most projects:
```
Planning Provider:  Claude
Coding Provider:    Gemini
Default Provider:   Gemini
```

## Step-by-Step Migration

### For New Users (v0.1.5+)

```bash
# 1. Install
dart pub global activate spectra_cli

# 2. Configure (will set up encrypted storage automatically)
spectra config
# - Enter API keys
# - Select planning provider (recommend: Claude)
# - Select coding provider (recommend: Gemini)

# 3. Use normally
spectra new
spectra plan "Phase 1"
spectra start --workers 3
```

### For Existing Users (Upgrading from v0.1.4)

```bash
# 1. Update
dart pub global activate spectra_cli

# 2. Run any command (triggers automatic migration)
spectra progress

# You'll see:
# ✅ Config migrated to encrypted storage

# 3. (Optional) Configure separate providers
spectra config
# - Your existing keys are preserved
# - Set planning provider (recommend: Claude)
# - Set coding provider (recommend: Gemini)

# 4. Continue working
spectra plan "Next Phase"
spectra execute
```

## Breaking Changes

### None! 🎉

This release is **fully backward compatible**:
- ✅ Existing commands work unchanged
- ✅ Existing config automatically migrated
- ✅ New features are opt-in
- ✅ Legacy `preferred_provider` still works

## Security Migration

### Before v0.1.5
```bash
$ cat ~/.spectra/config.yaml
gemini_key: "AIza123..."      # ❌ Plain text
openai_key: "sk-proj-xyz..."  # ❌ Visible
```

### After v0.1.5 (Automatic)
```bash
$ cat ~/.spectra/config.yaml
# File not found (deleted)

$ ls ~/.spectra/.secure/
creds.enc  # ✅ Encrypted
.key       # ✅ Machine-specific
```

**Your keys are automatically protected on first run.**

## Usage Changes

### Planning Tasks (Now Use Planning Provider)

```bash
# These commands now use your planning provider
spectra plan "Phase 1"    # Strategic task breakdown
spectra map               # Architecture analysis
```

If planning provider not set, falls back to preferred provider.

### Coding Tasks (Now Use Coding Provider)

```bash
# These commands now use your coding provider
spectra execute           # Sequential code generation
spectra start --workers 3 # Parallel code generation (Workers)
```

If coding provider not set, falls back to preferred provider.

### Multi-Agent Orchestration

```bash
spectra start --workers 3
# Mayor & Witness use planning provider (coordination)
# Workers use coding provider (code generation)
```

## Testing Your Migration

### 1. Verify Encrypted Storage

```bash
# Check encrypted file exists
ls -la ~/.spectra/.secure/
# Should show: creds.enc and .key

# Verify legacy file is gone
ls ~/.spectra/config.yaml
# Should show: No such file or directory
```

### 2. Verify Config Loading

```bash
# Should work without errors
spectra progress

# Or check with any command
spectra --help
```

### 3. Verify Provider Separation

```bash
# Configure separate providers
spectra config
# Select different providers for planning and coding

# Run planning task
spectra plan "Test Phase"
# Should use planning provider

# Run coding task (need existing plan)
spectra execute
# Should use coding provider
```

## Troubleshooting

### Issue: "No provider configured" Error

**Cause**: API keys not migrated or missing.

**Solution**:
```bash
spectra config
# Re-enter your API keys
```

### Issue: Different Results After Upgrade

**Cause**: Using different providers for planning/coding.

**Solution**: If you want consistent results, use the same provider for both:
```bash
spectra config
# Select "gemini" for both planning and coding
```

### Issue: Can't Find Old Config

**Cause**: Legacy `config.yaml` was deleted after migration.

**Solution**: This is intentional for security. Your keys are now encrypted. To view/edit:
```bash
spectra config
# Your existing keys are preserved and shown
```

## Rollback (If Needed)

If you need to rollback to v0.1.4:

```bash
# 1. Backup your encrypted config (optional)
cp -r ~/.spectra/.secure ~/.spectra/.secure.backup

# 2. Downgrade
dart pub global activate spectra_cli 0.1.4

# 3. Reconfigure
spectra config
# Re-enter your API keys (will create plain YAML)
```

**Note**: This removes encryption. Only do if absolutely necessary.

## New Features to Try

### 1. Cost Optimization

```bash
# Set up cost-optimized configuration
spectra config
# Planning: Claude (quality, happens rarely)
# Coding: Gemini Flash (speed, happens often)

# Can save ~$10-$50 per month depending on usage
```

### 2. Speed Optimization

```bash
# Set up speed-optimized configuration
spectra config
# Planning: Gemini Pro (fast planning)
# Coding: Gemini Flash (fastest coding)

# Execution can be 2-3x faster
```

### 3. Quality-First

```bash
# Set up quality-first configuration
spectra config
# Planning: Claude (best reasoning)
# Coding: Claude (best code quality)

# Highest quality results, higher cost
```

## Recommended Configurations

### For Production Projects
```
Planning: Claude (claude-4.5-sonnet)
Coding: Gemini (gemini-3.0-flash)
```

### For Prototyping
```
Planning: Gemini (gemini-3.0-pro)
Coding: Gemini (gemini-3.0-flash)
```

### For Large Projects
```
Planning: Claude (claude-4.5-sonnet)
Coding: DeepSeek (deepseek-v3.2)
```

### For Budget-Conscious
```
Planning: Gemini (gemini-3.0-flash)
Coding: DeepSeek (deepseek-v3.2)
```

## Support

### Getting Help

1. **Documentation**: See `doc/llm-usage-types.md` for comprehensive guide
2. **Issues**: Open an issue on [GitHub](https://github.com/iamEtornam/spectra/issues)
3. **Security**: See `doc/security.md` for security details

### Migration Issues

If you encounter issues during migration:

```bash
# Check status
spectra progress

# Clear and reconfigure
rm -rf ~/.spectra/.secure
spectra config
```

---

**Migration to v0.1.5 is seamless and automatic. Enjoy the new features!** 🚀
