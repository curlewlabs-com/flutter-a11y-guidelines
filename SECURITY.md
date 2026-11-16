# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it
privately via
[GitHub's security advisory feature](https://github.com/curlewlabs-com/flutter-a11y-guidelines/security/advisories/new).

Do not open a public issue for security vulnerabilities.

## Scope

This package runs only inside widget tests. It reads the widget, render and
semantics trees and the pixels a test has painted, and it drives pointer,
focus and scroll events through `WidgetTester`. It does not read files, open
network connections, or run processes, so its security surface is small.
