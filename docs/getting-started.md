# Getting Started

Learn how to install Spectra and initialize your first project.

## Installation

Ensure you have the Dart SDK installed. Then, activate the Spectra CLI globally:

```bash
dart pub global activate spectra_cli
```

Verify the installation:

```bash
spectra --help
```

## First-Time Configuration

Before running commands, configure your LLM providers:

```bash
spectra config
```

You will be prompted for API keys for:
- Google Gemini
- Anthropic Claude
- OpenAI
- xAI Grok
- DeepSeek

## Initializing a New Project

To start a new project from scratch:

```bash
mkdir my-new-project
cd my-new-project
spectra new
```

Follow the interactive prompts to define your project vision, tech stack, and constraints. This creates the `.spectra/` directory.

## Mapping an Existing Project

If you have an existing codebase you want Spectra to manage:

```bash
cd my-existing-repo
spectra map
```

Spectra will scan your repository to understand its architecture and naming conventions, populating the "Living Memory" in `.spectra/`.

