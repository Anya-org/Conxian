# Conxian Testing Guide

## Quick Start (Tutorial)
To run all tests:
```bash
npm install
npx vitest
```

## Test Organization (Reference)
Tests are located in the `tests/` directory and categorized by module.

## Writing Tests (How-to)
Follow the Vitest standard. Use the `simnet` instance from `setup-test-env.ts`.

## Coverage Goals (Explanation)
We aim for 100% coverage of core executive paths (ops-engine, agent-risk, etc.).
