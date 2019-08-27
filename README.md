# Soul Medicine

[![Build Status](https://travis-ci.org/chaynHQ/soulmedicine.svg?branch=master)](https://travis-ci.org/chaynHQ/soulmedicine)

**Currently in active development**

## Dev

### Prerequisites

- Ruby - see `.ruby-version` for the version required
- NodeJS 8+
  - with Yarn 1.10+
- Docker Compose v1.23+

### Dependent services

[Docker Compose](https://docs.docker.com/compose/overview/) is the recommended way to run all _dependent_ services locally, like the PostgreSQL db and Redis instances. Environment variables in `.env` have been set up to communicate with these services.

After installing Docker Compose (e.g. using [Docker for Mac](https://docs.docker.com/docker-for-mac/install/)) you can…

Start all services in the background:

```shell
docker-compose up -d
```

Shut down all these services:

```shell
docker-compose down
```

### Initial Setup

Once you have the prerequisites above, the codebase cloned and the dependent services running locally…

Set up **local** env vars in a new `.env.local` file – see the section at the bottom of the `.env` file for the variables you may need to set.

Then run the following to set everything up:

```bash
bin/setup
```

### Running the app locally

Start up the Rails server with:

```shell
bin/rails server
```

This serves the app, including all frontend assets (bundled using [Webpack](https://webpack.js.org/)).

You can **also** run `bin/webpack-dev-server` in a separate terminal shell if you want live reloading (in your browser) of CSS and JavaScript changes (note: only changes made within the `app/webpack` folder will cause live reloads).

(optionally) Start up the background processor with:

```shell
bundle exec sidekiq -c 1
```

### Running tests

```shell
bundle exec rspec
```

### Dev tips

- To get Rubocop to fix detected issues automatically (where it can):
  - `bundle exec rubocop -a`

- To run Brakeman locally
  - `brakeman`
- To step through the ignored warnings
  - `brakeman -I`

## Testing subscription emails

### Local dev

#### Email templates

When working on email templates, [Action Mailer Previews](https://guides.rubyonrails.org/action_mailer_basics.html#previewing-emails) provide a way to test the output of these templates without having to actually send any emails. We have one set up for subscription lesson emails – example usage:

http://localhost:3000/rails/mailers/lesson_mailer/lesson_email?course=how-to-manage-your-money&lesson_no=1&languages=en,ar&disguised=true

Note: this preview currently uses the first `User` in the database, so make sure you have one registered locally!

#### Full subscription email flow

You can also test out the full subscription email flow locally. We use [mailcatcher](https://github.com/sj26/mailcatcher) to capture all sent email from the local app. An instance of mailcatcher will already be running if you've used the Docker Compose set up mentioned above – you can open this at http://localhost:1080/.

Steps to test:

1. Start up the Sidekiq background worker using:
  - `bundle exec sidekiq -c 1`
2. Make or edit a new subscription in the app – make sure the schedule is set accordingly (i.e. to send you an email within the current time slot; note the timezone option, especially if you're currently in daylight savings time).
3. Trigger the subscriptions processor:
  - `bin/rails subscriptions:trigger_worker`
4. Watch the logs for the Sidekiq background worker to see it processing subscriptions and potentially sending out lesson emails.
5. Open up the mailcatcher interface to view all sent emails:
  - http://localhost:1080/

### On Heroku review apps

By default, newly created review apps on Heroku won't have any of the subscriptions processing and email sending set up. If you do need to test out subscriptions on a review app you can set this up:

- A Mailgun email service add-on should already be provisioned within the review app – you now need to add your email address to the "allow list" to ensure emails are received:
  - Go to the "Resources" section of your review app in the Heroku console
  - Click on the "Mailgun" add-on – this opens up the Mailgun console
  - Click on "Overview" in the left hand sidebar
  - In the "Authorized Recipients" section of the page, add your email address
  - A confirmation email will be sent to you with an activation link that you'll need to click on
- Now enable a worker dyno for the Sidekiq background worker:
  - Go to the "Resources" section of your review app in the Heroku console
  - Enable a single worker dyno under the "Hobby Dynos" section
- Now set up a recurring job to trigger the subscriptions processing:
  - Go to the "Resources" section of your review app in the Heroku console
  - Under "Add-ons" search for "scheduler" and select "Heroku Scheduler", then click on "Provision"
  - Now click on the new "Heroku Scheduler" entry in the list to open it's console
  - Click on "Create job"
    - Schedule for "Every hour at..." ":00" (or a different time point if needed for testing)
    - Set the run command to: `bin/rails subscriptions:trigger_worker`
    - Then click on "Save job"
  - This will run the subscriptions processor on an hourly basis
- Now you're ready to create subscriptions in that review app instance and receive lesson emails from it

## Storyblok content preview mode and caching

The env var `CONTENT_PREVIEW_MODE` determines the behaviour of content fetches from Storyblok…

When `CONTENT_PREVIEW_MODE` is set to `true`:
- **draft** versions of content are fetched
- content is not cached
- --> this is useful for review apps and preview environments, for testing the very latest content

When `CONTENT_PREVIEW_MODE` is set to `false`:
- only the last **published** versions of content are fetched
- content is cached in the Redis specified by the env var `REDIS_CACHE_URL`
- --> so subsequent requests for this data don't need to fetch from Storyblok
- --> this is important for staging and production environments
- --> **this means any published content updates may take some time to show up live** (details below)

The cached content, by default, expires after an hour, after which new published content will be fetched from Storyblok. This expiry can be controlled by the `CONTENT_CACHE_TTL_MINS` env var, if required.

To flush the cache manually, open up the endpoint `<site_base_url>/admin/flush_cache` in a browser. Now the very latest published content will be fetched from Storyblok.
