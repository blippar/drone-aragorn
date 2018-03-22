# Aragorn Drone Plugin

#### Using a list of test suites

```yaml
pipeline:
  check_regression:
    image: blippar/drone-aragorn
    pull: true
    target_url: https://my.service.com # Aragorn target url for all specified test suites
    suites:                            # Aragorn test suites to run (required)
      - .aragorn/test1.suite.json
      - .aragorn/test2.suite.json
    insecure: true                     # Ignore TLS verification while running test against secure endpoint (default: false)
    jaeger_addr: my.jaeger.com:4242    # will activate jaeger based tracing and forward to passwed url (optional)
    failfast: true                     # will activate failfast mode where aragorn will stop after the first test failure
    debug: true                        # will activate debug mode for the plugin (default: false)
```

#### Using an environment config

```yaml
pipeline:
  check_regression:
    image: blippar/drone-aragorn
    pull: true
    config: .aragorn/live.env.json  # run a specific env config
    jaeger_addr: my.jaege.com:4242  # will activate jaeger based tracing and forward to passwed url (optional)
    failfast: true                  # will activate failfast mode where aragorn will stop after the first test failure
    debug: true                     # will activate debug mode for the plugin (default: false)
```
