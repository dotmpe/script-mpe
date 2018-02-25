load init

setup()
{
  ENV_NAME=gspread-boreas . ~/.bashrc
}

@test "gspread user API" {
  require_env user
  TODO above env ID user doesnt exist. really want to pass some selectors on invocation

  run python x-gspread.py
  test_ok_nonempty || stdfail
}
