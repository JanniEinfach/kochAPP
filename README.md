# 🍳 KochAPP

**KochAPP** is an open-source recipe and cooking application for Apple platforms, designed to make discovering, organizing, and preparing recipes simple and intuitive.

The project is built with **Swift and SwiftUI** and follows a modular architecture with a clear separation between application features, packages, backend integration, documentation, and testing.

> 🚧 **Project status:** Active development
> 🍎 **Platform:** Apple platforms
> 🛠️ **Language:** Swift
> 🎨 **UI:** SwiftUI
> 🗄️ **Backend:** Supabase
> 📦 **Architecture:** Modular Swift Package architecture

---

## 📖 About the Project

KochAPP started with a simple idea:

> **Cooking should be easier to organize, discover, and enjoy.**

Instead of treating recipes as isolated pieces of content, KochAPP is being developed as a complete cooking experience with a focus on a clean user interface, maintainable software architecture, and an open development process.

The project is intentionally open source so that developers can inspect the implementation, contribute improvements, suggest features, report problems, and help shape the future of the application.

---

## ✨ Goals

The main goals of KochAPP are:

* 🥘 Make recipes easy to discover and use
* 📚 Provide a structured way to manage recipes
* ❤️ Make cooking more enjoyable and accessible
* 📱 Provide a modern native Apple-platform experience
* 🧩 Keep the application modular and maintainable
* 🧪 Maintain a strong testing foundation
* 🌍 Build an application that can grow with an open-source community
* 🔐 Keep backend and application concerns clearly separated
* 📖 Document architectural decisions and development principles

---

## 🏗️ Architecture

KochAPP is structured as a modular Swift application rather than putting the entire application into a single monolithic target.

The repository currently separates important parts of the project into dedicated areas:

```text
kochAPP/
├── App/
├── AppTests/
├── AppUITests/
├── Packages/
├── docs/
├── scripts/
├── supabase/
├── .env.example
├── ARCHITECTURE.md
├── DECISIONS.md
└── project.yml
```

### `App/`

Contains the main application target and the user-facing application code.

### `AppTests/`

Contains unit and application-level tests.

The goal is to make important application behavior testable and prevent regressions as the project evolves.

### `AppUITests/`

Contains UI-level tests for validating user-facing flows.

### `Packages/`

Contains modular components of the application.

Using separate packages helps keep individual parts of the application isolated and makes the codebase easier to maintain and extend.

### `docs/`

Contains project documentation and additional technical information.

### `scripts/`

Contains development and automation scripts used by the project.

### `supabase/`

Contains the project's Supabase-related backend configuration and database infrastructure.

### `ARCHITECTURE.md`

Documents the architectural structure of the project and the reasoning behind it.

### `DECISIONS.md`

Contains important architectural and technical decisions made during development.

This is intended to make the project easier for contributors to understand rather than forcing them to reverse-engineer every design decision from the source code.

---

# 🧰 Technology Stack

KochAPP is built using technologies from the Apple development ecosystem together with a modular backend architecture.

| Technology                | Purpose                       |
| ------------------------- | ----------------------------- |
| **Swift**                 | Primary programming language  |
| **SwiftUI**               | User interface                |
| **Swift Package Manager** | Modular package management    |
| **Supabase**              | Backend / data infrastructure |
| **Xcode**                 | Development environment       |
| **XCTest / UI Testing**   | Automated testing             |

The project is designed around native Apple technologies wherever possible.

---

# 🧩 Modular Design

One of the core principles of KochAPP is keeping functionality separated into understandable components.

A modular architecture provides several advantages:

* Easier maintenance
* Easier testing
* Better separation of responsibilities
* Smaller individual components
* Easier future refactoring
* Easier onboarding for contributors
* Reduced coupling between unrelated features

Instead of allowing every part of the application to depend directly on everything else, the project aims to establish clear boundaries between components.

---

# 🗄️ Backend

KochAPP uses **Supabase** as part of its backend infrastructure.

The backend layer is kept separate from the application's UI and business logic wherever possible.

This allows the application to evolve without tightly coupling presentation code to database implementation details.

The Supabase configuration can be found in:

```text
supabase/
```

Environment configuration is represented through:

```text
.env.example
```

### 🔐 Security

**Never commit real credentials or secrets to the repository.**

Developers should create their own local environment configuration based on the provided example configuration.

For example:

```text
.env.example
```

should be used as a reference for local configuration rather than storing production credentials in Git.

---

# 🧪 Testing

KochAPP includes both application tests and UI tests.

```text
AppTests/
AppUITests/
```

The purpose of the testing structure is to make the application safer to evolve as new features are introduced.

Testing is particularly important for an application with multiple layers because changes to one component should not unexpectedly break unrelated functionality.

Future development will continue to expand automated test coverage as the application grows.

---

# 🚀 Getting Started

## Requirements

To work on KochAPP you will generally need:

* A Mac
* Xcode
* A compatible Apple SDK
* Git
* A Supabase project for backend functionality

> The exact minimum Xcode and platform versions may change during development.

---

## 1. Clone the repository

```bash
git clone https://github.com/JanniEinfach/kochAPP.git
```

Then enter the project directory:

```bash
cd kochAPP
```

---

## 2. Configure the environment

Use the provided environment template:

```text
.env.example
```

Create your local environment configuration and add the required development credentials.

**Do not commit your local `.env` file.**

---

## 3. Configure Supabase

Create or use a Supabase project and configure the required backend settings according to the documentation in:

```text
supabase/
```

---

## 4. Open the project

Open the project using Xcode.

If the project is generated through the included project configuration, use the project's configured generation workflow.

---

## 5. Build and run

Select an appropriate Apple platform simulator or connected device in Xcode and build the application.

---

# 🛠️ Development

Before submitting changes, contributors should ideally:

1. Create a branch
2. Make the required changes
3. Run the relevant tests
4. Run UI tests where applicable
5. Check for build errors and warnings
6. Update documentation when behavior or architecture changes
7. Submit a pull request

Example:

```bash
git checkout -b feature/my-feature
```

Make your changes and then commit them:

```bash
git add .
git commit -m "Add my feature"
```

Push the branch:

```bash
git push origin feature/my-feature
```

Then open a Pull Request on GitHub.

---

# 🤝 Contributing

KochAPP is intended to become a community-driven open-source project.

Contributions are welcome.

You can contribute by:

* 🐛 Reporting bugs
* 💡 Suggesting features
* 🧑‍💻 Writing code
* 🧪 Improving tests
* 📖 Improving documentation
* 🎨 Improving the user experience
* 🔐 Reviewing security concerns
* 🏗️ Improving the architecture
* 🌍 Helping with localization
* 🔎 Reviewing pull requests

Before contributing, please read:

```text
CONTRIBUTING.md
```

if available in the repository.

---

# 💡 Feature Requests

Have an idea for KochAPP?

Open a GitHub Issue and describe:

* What problem the feature solves
* Why it would be useful
* How you imagine the feature working
* Any relevant examples or screenshots

Good feature requests focus on the **problem first**, rather than prescribing a specific implementation.

---

# 🐛 Bug Reports

If you discover a bug, please provide as much useful information as possible.

Include:

* Device
* Apple platform version
* Application version / commit
* Steps to reproduce
* Expected behavior
* Actual behavior
* Screenshots or recordings where useful
* Relevant logs

This makes it significantly easier to reproduce and fix problems.

---

# 🧠 Architectural Decisions

KochAPP maintains architectural documentation so that important decisions remain understandable over time.

Two important documents are:

```text
ARCHITECTURE.md
DECISIONS.md
```

### Why document decisions?

Software projects change over time.

Without documentation, future contributors often see only the final implementation and cannot understand why a particular approach was chosen.

Recording important decisions helps contributors understand:

* Why a technology was selected
* Why an architectural pattern was chosen
* What alternatives were considered
* What trade-offs were accepted
* Which decisions may need to be revisited later

---

# 🗺️ Roadmap

The project is continuously evolving.

Potential areas of future development include:

* [ ] Expand recipe management
* [ ] Improve recipe discovery
* [ ] Improve search and filtering
* [ ] Expand testing coverage
* [ ] Improve accessibility
* [ ] Improve localization
* [ ] Improve onboarding
* [ ] Expand backend functionality
* [ ] Improve offline behavior
* [ ] Improve performance
* [ ] Expand documentation
* [ ] Grow the contributor community

The roadmap is intentionally flexible because community feedback and real-world usage should influence development priorities.

---

# 🌍 Open Source

KochAPP is developed as an open-source project.

The goal is not only to publish the source code, but to create a project where other developers can understand the architecture, contribute improvements, and participate in its development.

Open source also provides an opportunity to experiment with:

* Modern Swift development
* SwiftUI
* Modular application architecture
* Backend integration
* Automated testing
* Documentation
* Collaborative software development

---

# 🔐 Security

If you discover a security vulnerability, please avoid publicly disclosing sensitive information before the issue can be investigated.

Please follow the project's security reporting process described in:

```text
SECURITY.md
```

Never include:

* API keys
* Passwords
* Authentication tokens
* Private credentials
* Production secrets

in issues, pull requests, commits, or public documentation.

---

# 📄 License

KochAPP is open source.

See the repository's `LICENSE` file for the complete license and terms of use.

---

# 👨‍💻 Maintainer

**JanniEinfach**

GitHub:

https://github.com/JanniEinfach

Project:

https://github.com/JanniEinfach/kochAPP

---

# ⭐ Support the Project

If you find KochAPP interesting, you can help the project by:

⭐ Starring the repository
🐛 Reporting bugs
💡 Suggesting improvements
🧑‍💻 Contributing code
📖 Improving documentation
🔀 Opening Pull Requests
📣 Sharing the project with other developers

Every contribution helps the project grow.

---

## 📌 Project Philosophy

KochAPP is built around a few simple principles:

> **Native first.**

Use the strengths of the Apple platform instead of fighting against them.

> **Modular by design.**

Keep components understandable, isolated, and maintainable.

> **Test what matters.**

Automated tests should protect important application behavior.

> **Document decisions.**

Future contributors should understand not only *what* the code does, but *why* it was designed that way.

> **Open by default.**

Make the project understandable and accessible to contributors.

---

## ❤️ Contributing to KochAPP

KochAPP is still evolving.

If you are interested in Swift, SwiftUI, mobile development, backend systems, testing, architecture, UX, or open-source software, you are welcome to explore the project and contribute.

**Let's build a better cooking experience together.**
