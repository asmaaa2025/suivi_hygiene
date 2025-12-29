# Contributing to BekkApp

Thank you for your interest in contributing to BekkApp! This document provides guidelines and instructions for contributing.

## Code of Conduct

This project adheres to a Code of Conduct that all contributors are expected to follow. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## How to Contribute

### Reporting Bugs

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md)
- Include steps to reproduce the issue
- Include relevant logs, screenshots, or error messages
- Specify your Flutter/Dart version and device/platform

### Suggesting Features

- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md)
- Clearly describe the feature and its use case
- Explain why this feature would be beneficial

### Pull Requests

1. **Fork the repository** and create a branch from `main`
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the existing code style
   - Write clear commit messages
   - Add comments for complex logic

3. **Run checks before submitting**
   ```bash
   # Format code
   flutter format .
   
   # Analyze code
   flutter analyze
   
   # Run tests
   flutter test
   ```

4. **Update documentation** if needed
   - Update README.md if adding features
   - Update CHANGELOG.md with your changes

5. **Submit a pull request**
   - Use the [pull request template](.github/pull_request_template.md)
   - Reference any related issues
   - Request review from maintainers

## Development Setup

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/bekkapp.git
   cd bekkapp
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Set up environment variables
   ```bash
   cp .env.example .env
   # Edit .env with your Supabase credentials
   ```

4. Set up Supabase database (see README.md)

5. Run the app
   ```bash
   flutter run
   ```

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `dart format` to format code
- Follow the existing code structure and naming conventions
- Write meaningful variable and function names
- Add comments for complex logic

## Testing

- Write tests for new features
- Ensure all existing tests pass
- Aim for good test coverage

## Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove, etc.)
- Reference issue numbers when applicable
- Example: `Fix temperature reading display issue (#123)`

## Review Process

- All pull requests require review
- Address review comments promptly
- Maintainers will merge after approval

## Questions?

If you have questions, please open an issue or contact the maintainers.

Thank you for contributing! 🎉

