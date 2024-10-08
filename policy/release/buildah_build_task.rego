#
# METADATA
# title: Buildah build task
# description: >-
#   This package is responsible for verifying the buildah build task
#
package policy.release.buildah_build_task

import rego.v1

import data.lib

# METADATA
# title: Buildah task uses a local Dockerfile
# description: >-
#   Verify the Dockerfile used in the buildah task was not
#   fetched from an external source.
# custom:
#   short_name: buildah_uses_local_dockerfile
#   failure_msg: DOCKERFILE param value (%s) is an external source
#   solution: >-
#     Make sure the 'DOCKERFILE' parameter does not come from an external source.
#   collections:
#   - redhat
#   depends_on:
#   - attestation_type.known_attestation_type
#
deny contains result if {
	some dockerfile_param in _dockerfile_params
	_not_allowed_prefix(dockerfile_param)
	result := lib.result_helper(rego.metadata.chain(), [dockerfile_param])
}

# METADATA
# title: ADD_CAPABILITIES parameter
# description: >-
#   Verify the ADD_CAPABILITIES parameter of a builder Tasks was not used.
# custom:
#   short_name: add_capabilities_param
#   failure_msg: ADD_CAPABILITIES parameter is not allowed
#   solution: >-
#     The ADD_CAPABILITIES parameter is not allowed for most container image builds. This, however,
#     might be required for certain build types, e.g. flatpaks. Either unset the parameter or use a
#     policy config that excludes this policy rule.
#   collections:
#   - redhat
#   effective_on: 2024-08-31T00:00:00Z
#   depends_on:
#   - attestation_type.known_attestation_type
#
deny contains result if {
	some param in _add_capabilities_params
	trim_space(param) != ""
	result := lib.result_helper(rego.metadata.chain(), [])
}

# METADATA
# title: PLATFORM parameter
# description: >-
#   Verify the value of the PLATFORM parameter of a builder Task is allowed by matching against a
#   list of disallowed patterns. The list of patterns can be customized via the
#   `disallowed_platform_patterns` rule data key. If empty, all values are allowed.
# custom:
#   short_name: platform_param
#   failure_msg: PLATFORM parameter value %q is disallowed by regex %q
#   solution: Use a different PLATFORM value that is not disallowed by the policy config.
#   collections:
#   - redhat
#   effective_on: 2024-09-01T00:00:00Z
#   depends_on:
#   - attestation_type.known_attestation_type
#
deny contains result if {
	some param in _platform_params
	some pattern in lib.rule_data(_plat_patterns_rule_data_key)
	regex.match(pattern, param)
	result := lib.result_helper(rego.metadata.chain(), [param, pattern])
}

# METADATA
# title: disallowed_platform_patterns format
# description: >-
#   Confirm the `disallowed_platform_patterns` rule data, if provided matches the expected format.
# custom:
#   short_name: disallowed_platform_patterns_pattern
#   failure_msg: "%s"
#   collections:
#   - redhat
#   - policy_data
#
deny contains result if {
	some error in _rule_data_errors
	result := lib.result_helper(rego.metadata.chain(), [error])
}

_not_allowed_prefix(search) if {
	not_allowed_prefixes := ["http://", "https://"]
	some not_allowed_prefix in not_allowed_prefixes
	startswith(search, not_allowed_prefix)
}

_buildah_tasks contains task if {
	some att in lib.pipelinerun_attestations
	some task in lib.tekton.build_tasks(att)
}

_dockerfile_params contains param if {
	some buildah_task in _buildah_tasks
	param := lib.tekton.task_param(buildah_task, "DOCKERFILE")
}

_add_capabilities_params contains param if {
	some buildah_task in _buildah_tasks
	param := lib.tekton.task_param(buildah_task, "ADD_CAPABILITIES")
}

_platform_params contains param if {
	some buildah_task in _buildah_tasks
	param := lib.tekton.task_param(buildah_task, "PLATFORM")
}

# Verify disallowed_platform_patterns is a list of strings. Empty list is fine.
_rule_data_errors contains msg if {
	# match_schema expects either a marshaled JSON resource (String) or an Object. It doesn't
	# handle an Array directly.
	value := json.marshal(lib.rule_data(_plat_patterns_rule_data_key))
	some violation in json.match_schema(
		value,
		{
			"$schema": "http://json-schema.org/draft-07/schema#",
			"type": "array",
			"items": {"type": "string"},
			"uniqueItems": true,
		},
	)[1]
	msg := sprintf("Rule data %s has unexpected format: %s", [_plat_patterns_rule_data_key, violation.error])
}

# Verify items in the disallowed_platform_patterns list are valid regular expressions.
_rule_data_errors contains msg if {
	# We could use `"pattern": "regex"` in the JSON schema. However, rego doesn't fully support all
	# regex features. This ensures that the regexes provides are valid within the context of rego.
	some r in lib.rule_data(_plat_patterns_rule_data_key)
	not regex.is_valid(r)
	msg := sprintf("%q is not a valid regular expression in rego", [r])
}

_plat_patterns_rule_data_key := "disallowed_platform_patterns"
