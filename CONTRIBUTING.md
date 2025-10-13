# Contributing to Augen

First off, thank you for considering contributing to Augen! It's people like you that make Augen such a great tool for the Flutter AR community.

## Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

* **Use a clear and descriptive title** for the issue to identify the problem.
* **Describe the exact steps which reproduce the problem** in as many details as possible.
* **Provide specific examples to demonstrate the steps**.
* **Describe the behavior you observed after following the steps** and point out what exactly is the problem with that behavior.
* **Explain which behavior you expected to see instead and why.**
* **Include screenshots and animated GIFs** if possible.
* **Include your Flutter version, device model, and OS version.**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

* **Use a clear and descriptive title** for the issue to identify the suggestion.
* **Provide a step-by-step description of the suggested enhancement** in as many details as possible.
* **Provide specific examples to demonstrate the steps** or provide mockups/screenshots if applicable.
* **Describe the current behavior** and **explain which behavior you expected to see instead** and why.
* **Explain why this enhancement would be useful** to most Augen users.

### Pull Requests

* Fill in the required template
* Do not include issue numbers in the PR title
* Follow the Dart style guide
* Include thoughtfully-worded, well-structured tests
* Document new code
* End all files with a newline

## Development Setup

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/yourusername/augen.git
   cd augen
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   cd example
   flutter pub get
   cd ..
   ```

3. **Run the example app**
   ```bash
   cd example
   flutter run
   ```

## Project Structure

```
augen/
├── android/              # Android native implementation (ARCore)
│   └── src/main/
│       ├── kotlin/       # Kotlin source files
│       └── AndroidManifest.xml
├── ios/                  # iOS native implementation (RealityKit)
│   ├── Classes/          # Swift source files
│   └── augen.podspec
├── lib/                  # Dart source files
│   ├── src/
│   │   ├── models/       # Data models
│   │   ├── augen_controller.dart
│   │   └── augen_view.dart
│   └── augen.dart        # Main export file
├── example/              # Example application
└── test/                 # Unit tests
```

## Coding Guidelines

### Dart Code Style

* Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
* Use `flutter analyze` to check for issues
* Format code with `flutter format`
* Write meaningful variable and function names
* Add comments for complex logic
* Keep functions small and focused

### Native Code Style

**Android (Kotlin)**
* Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
* Use meaningful variable names
* Add KDoc comments for public APIs

**iOS (Swift)**
* Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
* Use meaningful variable names
* Add documentation comments for public APIs

## Testing

### Running Tests

```bash
# Run Dart tests
flutter test

# Run Android tests
cd android
./gradlew test

# Run iOS tests
cd ios
xcodebuild test
```

### Writing Tests

* Write unit tests for all new features
* Ensure tests are deterministic
* Mock external dependencies
* Test edge cases and error conditions

## Commit Messages

* Use the present tense ("Add feature" not "Added feature")
* Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
* Limit the first line to 72 characters or less
* Reference issues and pull requests liberally after the first line
* Consider starting the commit message with an applicable emoji:
    * 🎨 `:art:` when improving the format/structure of the code
    * 🐎 `:racehorse:` when improving performance
    * 📝 `:memo:` when writing docs
    * 🐛 `:bug:` when fixing a bug
    * 🔥 `:fire:` when removing code or files
    * ✅ `:white_check_mark:` when adding tests
    * 🔒 `:lock:` when dealing with security

## Documentation

* Update the README.md if you change functionality
* Update the CHANGELOG.md following [Keep a Changelog](https://keepachangelog.com/) format
* Add inline documentation for public APIs
* Include code examples where appropriate

## Release Process

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md` with changes
3. Create a git tag with the version number
4. Push the tag to GitHub
5. Publish to pub.dev (maintainers only)

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

## Recognition

Contributors will be recognized in the project README and release notes.

Thank you for contributing to Augen! 🎉

