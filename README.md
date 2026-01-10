# Expense-Tracking-2.0

Expense-Tracking-2.0 is a small self-hosted Rails application to help you import, categorize, and analyze personal transaction data. It provides CSV import with duplicate review, an insights dashboard (income vs spending, subscriptions, top expenses), and a simple category/keyword system that can auto-assign transactions.

## Installation

Prerequisites
- Ruby (use the version declared in the project's Gemfile / .ruby-version)
- Bundler (gem install bundler)
- SQLite3 for local development (or configure your DATABASE_URL for another DB)

Clone and install dependencies

```bash
git clone https://github.com/aliciaschmidt06/Expense-Tracking-2.0.git
cd Expense-Tracking-2.0
bundle install
```

Set up the database (migrations + seed data)

```bash
bin/rails db:setup
# or if you prefer separate steps:
# bin/rails db:create db:migrate db:seed
```

Start the app

```bash
bin/rails server
# open http://localhost:3000
```

There is also a `Dockerfile` and `docker-entrypoint` if you prefer to run it in a container — adapt to your environment.

## Getting started (how to use it)

- Categories: Navigate to Categories to add/edit category names, target percentages and keywords. Keywords are used to auto-assign transactions. The category edit form uses a tag-style keyword editor (add/remove tags) to make managing keywords easier.

- Importing transactions: Use the Imports page to upload CSV files exported from your bank. The import process detects duplicate candidates and presents a review screen where you can Keep (add) or Ignore each duplicate before finalizing the import.

- Insights & Spending: The dashboard shows monthly Income vs Spending bars. Click a bar to list the transactions for that month. The dashboard includes tiles for detected subscriptions and the Top 20 largest expenses, and it honors the date/category filters. The smart month filter accepts formats like `Dec 2024`, `12/2024`, or a bare year like `2025`.

- Uncategorized transactions: Drag-and-drop uncategorized transactions into a category to assign them. When you assign a transaction the app may append a short keyword snippet to the category to improve future auto-assignment.

## Development & tests

- Run the Rails test suite

```bash
bin/rails test
```

- Linting and security tools: the repository includes helper scripts in `bin/` for common checks (brakeman, bundler-audit, rubocop). Use them as needed.

## Contributing

If you'd like to contribute, open a PR against the `main` branch. Please include tests for new behavior and follow the project's existing code style.

---

If you'd like this README to include a quick walkthrough with screenshots, or a Docker Compose example, tell me which you'd prefer and I can add it.


If you'd like this README to include a quick walkthrough with screenshots, or a Docker Compose example, tell me which you'd prefer and I can add it.


If you'd like this README to include a quick walkthrough with screenshots, or a Docker Compose example, tell me which you'd prefer and I can add it.
# Expense-Tracking-2.0

Expense-Tracking-2.0 is a small self-hosted Rails application to help you import, categorize, and analyze personal transaction data. It provides CSV import with duplicate review, an insights dashboard (income vs spending, subscriptions, top expenses), and a simple category/keyword system that can auto-assign transactions.

## Installation

Prerequisites
- Ruby (use the version declared in the project's Gemfile / .ruby-version)
- Bundler (gem install bundler)
- SQLite3 for local development (or configure your DATABASE_URL for another DB)

Clone and install dependencies

```bash
git clone https://github.com/aliciaschmidt06/Expense-Tracking-2.0.git
cd Expense-Tracking-2.0
bundle install
```

Set up the database (migrations + seed data)

```bash
bin/rails db:setup
# or if you prefer separate steps:
# bin/rails db:create db:migrate db:seed
```

Start the app

```bash
bin/rails server
# open http://localhost:3000
```

There is also a `Dockerfile` and `docker-entrypoint` if you prefer to run it in a container — adapt to your environment.

## Getting started (how to use it)

- Categories: Navigate to Categories to add/edit category names, target percentages and keywords. Keywords are used to auto-assign transactions. The category edit form uses a tag-style keyword editor (add/remove tags) to make managing keywords easier.

- Importing transactions: Use the Imports page to upload CSV files exported from your bank. The import process detects duplicate candidates and presents a review screen where you can Keep (add) or Ignore each duplicate before finalizing the import.

- Insights & Spending: The dashboard shows monthly Income vs Spending bars. Click a bar to list the transactions for that month. The dashboard includes tiles for detected subscriptions and the Top 20 largest expenses, and it honors the date/category filters. The smart month filter accepts formats like `Dec 2024`, `12/2024`, or a bare year like `2025`.

- Uncategorized transactions: Drag-and-drop uncategorized transactions into a category to assign them. When you assign a transaction the app may append a short keyword snippet to the category to improve future auto-assignment.

## Development & tests

- Run the Rails test suite

```bash
bin/rails test
```

- Linting and security tools: the repository includes helper scripts in `bin/` for common checks (brakeman, bundler-audit, rubocop). Use them as needed.

## Contributing

If you'd like to contribute, open a PR against the `main` branch. Please include tests for new behavior and follow the project's existing code style.

