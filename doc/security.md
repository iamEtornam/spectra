# Security Features

Spectra implements robust security measures to protect your sensitive API keys and configuration data.

## Overview

When you run `spectra config` and provide your API keys, they are:

1. **Never stored in plain text**
2. **Encrypted using machine-specific encryption**
3. **Stored in a secure directory** (`~/.spectra/.secure/`)
4. **Protected by filesystem permissions**

## Encryption Details

### Key Derivation

Spectra uses a machine-specific encryption key derived from:

- **Operating System**: Platform identifier
- **User Context**: Home directory path
- **Machine Identity**: Hostname (when available)

These components are combined and processed using:

- **PBKDF2 (Password-Based Key Derivation Function 2)**
- **SHA-256 Hashing**
- **10,000 Iterations** for key strengthening

### Encryption Method

- **Algorithm**: XOR-based stream cipher with SHA-256 derived keystream
- **Key Size**: 256 bits
- **Deterministic**: Same machine always produces the same encryption key
- **Machine-Bound**: Keys cannot be decrypted on different machines

## Storage Structure

```
~/.spectra/
├── .secure/              # Secure storage directory
│   ├── creds.enc        # Encrypted credentials
│   └── .key             # Derived encryption key metadata
└── config.yaml          # Legacy (auto-migrated to encrypted storage)
```

## Migration from Legacy Format

If you're upgrading from an older version of Spectra that stored API keys in plain YAML:

1. **Automatic Detection**: On first run, Spectra detects the legacy `config.yaml`
2. **Secure Migration**: All keys are encrypted and stored in `.secure/creds.enc`
3. **Cleanup**: The legacy `config.yaml` is automatically deleted
4. **Transparent**: Your API keys continue to work without any manual intervention

## Security Best Practices

### 1. Protect Your Home Directory

Your encrypted API keys are only as secure as your filesystem:

```bash
# Ensure your home directory has appropriate permissions
chmod 700 ~/.spectra
chmod 600 ~/.spectra/.secure/*
```

### 2. Regular Key Rotation

Rotate your API keys periodically:

```bash
# Update your configuration
spectra config

# Your new keys will be encrypted and stored securely
```

### 3. Backup Considerations

If you backup your system:

- **Encrypted data is safe to backup** - it's machine-bound
- **Cannot be restored to another machine** - keys are machine-specific
- **Re-run `spectra config` on the new machine** to set up API keys

### 4. Multi-User Systems

On shared systems:

- Each user has their own `~/.spectra` directory
- Credentials are isolated per user account
- Use OS-level user permissions to control access

## API Key Providers

Spectra supports secure storage for:

- **Google Gemini** (`gemini_key`)
- **OpenAI** (`openai_key`)
- **Anthropic Claude** (`claude_key`)
- **xAI Grok** (`grok_key`)
- **DeepSeek** (`deepseek_key`)

Each provider's keys are encrypted together in a single secure container.

## Clearing Credentials

To remove all stored credentials:

```bash
# This will delete encrypted credentials
rm -rf ~/.spectra/.secure
```

You'll need to run `spectra config` again to set up API keys.

## Security Limitations

### What This Protects Against

✅ **Accidental exposure** (e.g., committing config to Git)
✅ **Unauthorized file access** on your machine
✅ **Plain-text storage** of sensitive credentials
✅ **Cross-machine credential theft**

### What This Does NOT Protect Against

❌ **Root/Admin access** - Users with elevated privileges can access encrypted data
❌ **Memory inspection** - Keys are decrypted in memory when in use
❌ **Malware** running on your machine
❌ **Physical access** to an unlocked machine

## Technical Implementation

For developers interested in the implementation:

```dart
// Secure storage service
final secureStorage = SecureStorageService();

// Store credentials securely
await secureStorage.store({
  'gemini_key': 'AIza...',
  'openai_key': 'sk-...',
});

// Retrieve credentials
final credentials = await secureStorage.retrieve();
print(credentials['gemini_key']); // AIza...

// Clear all credentials
await secureStorage.clear();
```

The `SecureStorageService` handles:

- Machine-specific key derivation
- Encryption/decryption
- Secure file operations
- Automatic cleanup

## Frequently Asked Questions

### Q: Can I use Spectra on multiple machines?

**A:** Yes, but you'll need to run `spectra config` on each machine. Encrypted credentials from one machine cannot be transferred to another.

### Q: What happens if I lose my `.secure` directory?

**A:** You'll need to run `spectra config` again to re-enter your API keys. They will be encrypted and stored securely.

### Q: Is the encryption unbreakable?

**A:** No encryption is "unbreakable." Spectra uses strong encryption suitable for local credential storage. For highest security, consider using environment variables or a dedicated secrets manager.

### Q: Can I see my encrypted keys?

**A:** The encrypted file is binary data. You can decrypt it programmatically using the `SecureStorageService`, but there's no built-in command to view keys in plain text (by design).

### Q: How do I audit what keys are stored?

**A:** Currently, you need to check your API provider dashboards. Future versions may include a secure key listing feature.

## Reporting Security Issues

If you discover a security vulnerability in Spectra's credential storage:

1. **Do NOT open a public issue**
2. **Email**: [Your security contact email]
3. **Include**: Detailed description, reproduction steps, and impact assessment
4. **Response Time**: We aim to respond within 48 hours

---

**Security is an ongoing process.** We continuously evaluate and improve Spectra's security posture. Feedback and contributions are welcome!
