# Headless automated integration testing using docker compose

If running from this directory, run `docker compose up`

If running from the root directory of this repository, run `docker compose -f tools/headless_testing/docker-compose.yml up`

## test file locations
Some tests exist in 
 - [common/testing/infologtest.lua](../../common/testing/infologtest.lua)
 - [luaui/Tests/cmd_blueprint/test_cmd_blueprint_filter.lua](../../luaui/Tests/cmd_blueprint/test_cmd_blueprint_filter.lua)
 - [luaui/Tests/cmd_stop_selfd/test_cmd_stop_selfd.lua](../../luaui/Tests/cmd_stop_selfd/test_cmd_stop_selfd.lua)

## CICD
Note: these tests are run as part of GitHub Actions on every PR.