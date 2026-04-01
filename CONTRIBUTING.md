# Contributing to Conxian Finance

Welcome to Conxian Finance! We are excited that you are interested in contributing to our Sovereign Autonomous Business.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

1. **Fork the Repository**: Create a fork of the repository and clone it to your local machine.
2. **Create a Branch**: Create a new branch for your feature or bug fix.
3. **Make Your Changes**: Implement your changes, following our coding standards.
4. **Write Tests**: Ensure your changes are covered by tests.
5. **Submit a Pull Request**: Submit a pull request to the main repository for review.

## Coding Standards

- **Clarity**: Use 2-space indentation, kebab-case for functions, and UPPER_CASE for constants.
- **Documentation**: All public functions must be documented with header comments.
- **Security**: Always verify traits and handle error cases explicitly.

## Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification.

Format: `<type>(<scope>): <description>`

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `perf`: A code change that improves performance
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to the build process or auxiliary tools and libraries

Example: `feat(core): add batch operation for role updates`

Thank you for your contributions!

## Dependencies

This repo standardizes on **npm** and commits `package-lock.json` to keep installs reproducible.

- When you change dependencies, include the updated `package-lock.json` in the same PR.
- Do not commit other lockfiles (`pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`).

## Secrets and local environment

- Never commit any `.env*` files (for example: `.env`, `.env.local`, `ui/.env.local`), private keys, or API tokens.
- Use `.env.example` as the template for required environment variables.
- Pull requests and pushes to `main` are scanned with `gitleaks` in GitHub Actions.

## Modular Architecture & Testability

To avoid circular dependencies in our simulation environment, we enforce the **Principal Injection** pattern:
- **Avoid Hardcoding**: Do not use hardcoded contract literals (e.g., `.contract-name`) for internal cross-contract calls if they create a dependency loop.
- **Use Data-Vars**: Use `(define-data-var)` to store the principal of an external contract.
- **Setters**: Provide a public setter (authorized by admin) to initialize or update these principals at runtime.
