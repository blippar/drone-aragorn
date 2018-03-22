#!/bin/sh
# shellcheck disable=SC2034,SC2039
set -e

# Plugin configuration
PLUGIN_TARGET_URL=${PLUGIN_TARGET_URL:-""}
PLUGIN_INSECURE=$([ "${PLUGIN_INSECURE}" = "true" ] && echo "true" || echo "false")
PLUGIN_SUITES=${PLUGIN_SUITES:-""}
PLUGIN_FAILFAST=${PLUGIN_FAILFAST:-"false"}
PLUGIN_JAEGER_ADDR=${PLUGIN_JAEGER_ADDR:-""}
PLUGIN_DEBUG=${PLUGIN_DEBUG:-"false"}
PLUGIN_CONFIG=${PLUGIN_CONFIG:-""}

# Secrets based configuration (use plugin config if exists, else use secret value)
ARAGORN_JAEGER_ADDR=${PLUGIN_JAEGER_ADDR:-"${ARAGORN_JAEGER_ADDR}"}

# Logger
jqLog () {
    LVL="${1?"usage: jqLog level msg desc [extra_fields] [extra_json_fields]"}"
    MSG="${2?"usage: jqLog level msg desc [extra_fields] [extra_json_fields]"}"
    shift 2
    TIME="$(date +"%s.%6N")"

    if [ "$LVL" == "debug" ] && [ "$PLUGIN_DEBUG" != "true" ]; then
        return
    fi

    logline=$(
        jq -ncM '{level: $lvl, ts: $ts, msg: $msg}' \
            --arg ts "${TIME}" \
            --arg lvl "${LVL}" \
            --arg msg "${MSG}"
    )

    while [ $# -gt 1 ]; do
        key=$(echo "$1" | cut -d ':' -f2-)
        if [ "$1" == "$key" ]; then
            logline=$(echo "${logline}" | jq -cM ". + { \"$1\" : \$val }" --arg val "$2")
        else
            logline=$(echo "${logline}" | jq -cM ". + { \"$key\" : \$val }" --argjson val "$2")
        fi
        shift 2
    done

    echo "${logline}" 1>&2
}

# Internal variables
cli_opts=""
cfgfile=""

# Configuration generation logic
gen_envconfig() {

    if [ -n "${cfgfile}" ]; then
        jqLog warn configAlreadyExist \
            'description' "An env config has already been passed via the 'config' argument, ignoring the request to generate one from specified 'suites' and 'target_url'"
        return
    fi

    jqLog info generateConfig \
        'description' 'Generating env configuration file' \
        'url'         "${PLUGIN_TARGET_URL}"

    cfgfile="aragorn.${RANDOM}${RANDOM}.env.json"
    base=$(
        jq -ncM '{ url: $url, insecure: $insecure}' \
            --arg url "${PLUGIN_TARGET_URL}" \
            --argjson insecure "${PLUGIN_INSECURE}"
    )

    jqLog debug baseConfig \
        'description' 'Default base suite config created' \
        ':base'        "$base"

    envconfig=$(
        for suite in ${PLUGIN_SUITES}; do

            jqLog debug suiteAdded \
                'description' "Suite '${suite}' has been added to the env config"

            jq -ncM '{ suite: { base: $base }, path: $path }' \
                --arg path "$suite" \
                --argjson base "$base"

        done | jq -scM '{ suites: . }'
    )

    # Print generated config if debug = true
    if [ "${PLUGIN_DEBUG}" = "true" ]; then
        jqLog debug printConfig \
            ':config' "$envconfig"
    fi

    echo "$envconfig" > "${cfgfile}"
}

# Main logic
main() {

    # Use env config if passed
    if [ -n  "${PLUGIN_CONFIG}" ]; then
        jqLog info loadConfig \
            'description' 'Loading env configuration file' \
            'file'        "${PLUGIN_CONFIG}"
        cfgfile="${PLUGIN_CONFIG}"
    fi

    # Generate env config if 'suites' and 'target_url' are set
    if [ -n "${PLUGIN_SUITES}" ] && [ -n "${PLUGIN_TARGET_URL}" ]; then
        gen_envconfig
    fi

    # Verify that a configuration is set or fatal
    if [ "${cfgfile}" == "" ]; then
        jqLog error noConfig \
            'description' "Either 'config' or 'suites' + 'target_url' must be set in order to have a working aragorn env config, exiting"
        return 1
    fi

    cli_opts="-config=${cfgfile}"

    if [ -n "${ARAGORN_JAEGER_ADDR}" ]; then
        jqLog debug enableTracing \
            'description' 'Jaeger tracing is enabled and exporting'
            'jaeger_addr' "${ARAGORN_JAEGER_ADDR}"
        cli_opts="${cli_opts} -tracer=jaeger -tracer-addr=${ARAGORN_JAEGER_ADDR}"
    fi

    if [ "${PLUGIN_FAILFAST}" = "true" ]; then
        jqLog debug enableFailfast \
            'description' 'Aragorn will run with the failfast option set to true, exiting after the first test failure'
        cli_opts="${cli_opts} -failfast"
    fi

    jqLog info execAragorn \
        'description' 'Aragorn will be started' \
        'cmd'         "aragorn exec ${cli_opts}"
    exec /usr/bin/aragorn exec ${cli_opts}
}

main "$@"
