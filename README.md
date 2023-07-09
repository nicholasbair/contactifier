# Contactifier

## Use case
Demonstrate the usage of Nylas parsed contacts in a CRM/CSP-like platform.

### What is it really?
Imagine you are a user of a CRM/CSP tool.  When you have email interactions with customers, maybe your contact copies someone new on the email.  Ideally, your CRM/CSP will capture that new person's email address so you can store it in your system for use later.  This is where parsed contacts come in--if your email account is connected, Nylas will create contacts that exist only on Nylas based on your email interactions.  Contactifier uses these contacts to power a "workflow" wherein the user of the CRM/CSP tool can choose to convert a parsed contact into a legit contact in the CRM/CSP.

### Features
* Email & contact integration powered by Nylas
* A user can have many integrations (e.g. multiple accounts connected via Nylas)
* Webhooks for parsed contacts
* Webhooks for Nylas connected account status
* Scheduled job to delete stale Nylas connected accounts

### What's missing?
* Tests
* A concept of organzations, where multiple users can access a shared group of customers, contacts, etc.
* Email notifications for integration re-auth
* The bulk of stuff you would expect in a CRM/CSP: emailing, customer metrics, etc.

## Running locally
* Clone the repo
* CD into the directory
* Make sure you have Postgres running
* Set environment variables: `CLOAK_KEY`, `NYLAS_CLIENT_ID`, `NYLAS_CLIENT_SECRET`
* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
* Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
