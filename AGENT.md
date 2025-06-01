# AGENT.md - Developer Guidelines

## Commands
Rails 8 app with Docker Compose. Prefix all CLI commands with `docker compose run web $COMMAND`

### Test Commands
- Run all tests: `docker compose run web rails test`
- Run single test: `docker compose run web rails test test/path/to/test_file.rb`
- Run specific test method: `docker compose run web rails test test/path/to/test_file.rb:method_name`

### Build/Lint Commands
- Lint code: `docker compose run web rubocop`
- Auto-fix lint: `docker compose run web rubocop -a`
- Security scan: `docker compose run web brakeman`
- CSS build: `docker compose run web rails tailwindcss:watch` (dev only)

## Code Style
- Uses Rubocop Rails Omakase for style enforcement (strict)
- Use `rails g` for migrations instead of manual creation
- PostgreSQL with PostGIS for spatial data
- Validates presence and uniqueness appropriately in models
- Use clear, descriptive method names (e.g., `representative_slug`, `find_by_location`)

## Architecture
- Rails 8 with Turbo/Stimulus
- TailwindCSS 4.0 for styling
- Good Job for background jobs
- ActiveRecord with PostGIS adapter for geographic data
