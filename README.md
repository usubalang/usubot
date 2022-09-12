# usubot
Bot for usuba

## Setting usubot for the first time

Some files are empty and need to be filled.

- `config.toml`
  + Copy/paste the following skeleton in a `./config.toml` file
  ```toml
  [bot]
  name="usubot" # The name of your bot.
  email="usubalang@users.noreply.github.com"

  [server]
  domain="TO FILL" # URL of the server
  port="3000" # The port number the server is listening on.
  # If commented, the port number is read from the
  # PORT environment variable. If this environment
  # variable is not found, the port is set to 8000.

  # Settings for GitHub
  [github]
  # This token should be your user token
  api_token="TO FILL"
  webhook_secret="TO FILL"
  app_id="TO FILL" # The GitHub App ID

  # Settings for GitLab
  [gitlab]
  # If commented, this secret is read from the environment
  # variable GITLAB_ACCESS_TOKEN
  # You shouldn't touch this part, the bot needs a dummy
  # value to initialize correctly
  api_token="secret"
  ```
  + `domain`: For obvious reasons, this url is not provided. If you have the proper rights, you should have access to it [here](https://github.com/apps/usubot/) and fill it here
  + `port` is set to 3000
  + `[github]`
    - `api_token`: Generate your own GitHub api token (on your account):
      + [GitHub documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
      + Give your API token the following scopes:
        - `repo`: everything
        - rest: nothing
    - `webhook_secret`: This will require some old interaction called "go to Pierre-Evariste's office and ask him for the password"
    - `app_id` is available [here](https://github.com/organizations/usubalang/settings/apps/usubot)
- Generate a private key [here](https://github.com/organizations/usubalang/settings/apps/usubot) in the `Private Keys` section. Once you've generated one, copy its content to the file of your choice (let's call it `usubot.pem`)

## Starting the bot

Once everything is set up you can run the bot with:

    opam exec -- dune exec usubot -- -k usubot.pem config.toml -u /path/to/usuba/repo -b /path/to/benchs --debug 2> logs

The `logs` file will contain any interesting information in case something stops working.
