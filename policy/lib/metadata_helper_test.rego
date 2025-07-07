package lib_test

import rego.v1

import data.lib

test_rule_annotations_with_annotations if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"failure_msg": "Test failure message",
		"pipeline_intention": ["build", "test"],
	}}

	chain := [
		{"annotations": rule_annotations, "path": ["data", "test", "deny"]},
		{"annotations": {}, "path": ["ignored", "path"]},
	]

	lib.assert_equal(rule_annotations, lib._rule_annotations(chain))
}

test_rule_annotations_empty_annotations if {
	empty_annotations := {}

	chain := [
		{"annotations": empty_annotations, "path": ["data", "test", "deny"]},
		{"annotations": {"some": "other"}, "path": ["ignored", "path"]},
	]

	lib.assert_equal(empty_annotations, lib._rule_annotations(chain))
}

test_rule_annotations_only_first_entry if {
	first_rule_annotations := {"custom": {"short_name": "FirstRule"}}
	second_rule_annotations := {"custom": {"short_name": "SecondRule"}}

	chain := [
		{"annotations": first_rule_annotations, "path": ["data", "test", "deny"]},
		{"annotations": second_rule_annotations, "path": ["other", "path"]},
	]

	# Should only return annotations from the first entry
	lib.assert_equal(first_rule_annotations, lib._rule_annotations(chain))
}

test_rule_annotations_single_entry_chain if {
	rule_annotations := {"custom": {"short_name": "SingleRule"}}

	chain := [{"annotations": rule_annotations, "path": ["data", "single", "deny"]}]

	lib.assert_equal(rule_annotations, lib._rule_annotations(chain))
}

test_pipeline_intention_match_with_matching_intention if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": ["build", "release", "test"],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When rule_data("pipeline_intention") matches one of the pipeline_intention values
	lib.assert_equal(true, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
}

test_pipeline_intention_match_with_non_matching_intention if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": ["build", "test"],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When rule_data("pipeline_intention") doesn't match any of the pipeline_intention values
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
}

test_pipeline_intention_match_with_empty_pipeline_intention if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": [],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When pipeline_intention is an empty list, should return false
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
}

test_pipeline_intention_match_without_pipeline_intention_field if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"failure_msg": "Some failure message",
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When pipeline_intention field is missing, should return false
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
}

test_pipeline_intention_match_without_custom_field if {
	rule_annotations := {"other": {"some_field": "value"}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When custom field is missing, should return false
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
}

test_pipeline_intention_match_with_null_rule_data if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": ["build", "release", "test"],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When rule_data("pipeline_intention") is null, should return false
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as null
}

test_pipeline_intention_match_with_multiple_matching_intentions if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": ["build", "release", "production", "test"],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# When rule_data("pipeline_intention") matches one of multiple pipeline_intention values
	lib.assert_equal(true, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "production"
}

test_pipeline_intention_match_case_sensitivity if {
	rule_annotations := {"custom": {
		"short_name": "TestRule",
		"pipeline_intention": ["Build", "Release"],
	}}

	chain := [{"annotations": rule_annotations, "path": ["data", "test", "deny"]}]

	# Case sensitivity should be preserved
	lib.assert_equal(false, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "release"
	lib.assert_equal(true, lib.pipeline_intention_match(chain)) with data.rule_data.pipeline_intention as "Release"
}

test_result_helper if {
	expected_result := {
		"code": "oh.Hey",
		"effective_on": "2022-01-01T00:00:00Z",
		"msg": "Bad thing foo",
	}

	rule_annotations := {"custom": {
		"short_name": "Hey",
		"failure_msg": "Bad thing %s",
	}}

	chain := [
		{"annotations": rule_annotations, "path": ["data", "oh", "deny"]},
		{"annotations": {}, "path": ["ignored", "ignored"]}, # Actually not needed any more
	]

	lib.assert_equal(expected_result, lib.result_helper(chain, ["foo"]))
}

test_result_helper_without_package_annotation if {
	expected_result := {
		"code": "package_name.Hey", # Fixme
		"effective_on": "2022-01-01T00:00:00Z",
		"msg": "Bad thing foo",
	}

	rule_annotations := {"custom": {
		"short_name": "Hey",
		"failure_msg": "Bad thing %s",
	}}

	chain := [{"annotations": rule_annotations, "path": ["package_name", "deny"]}]

	lib.assert_equal(expected_result, lib.result_helper(chain, ["foo"]))
}

test_result_helper_with_collections if {
	expected := {
		"code": "some.path.oh.Hey",
		"collections": ["spam"],
		"effective_on": "2022-01-01T00:00:00Z",
		"msg": "Bad thing foo",
	}

	rule_annotations := {"custom": {
		"collections": ["spam"],
		"short_name": "Hey",
		"failure_msg": "Bad thing %s",
	}}

	chain := [
		{"annotations": rule_annotations, "path": ["some", "path", "oh", "deny"]},
		{"annotations": {}, "path": ["ignored", "ignored"]}, # Actually not needed any more
	]

	lib.assert_equal(expected, lib.result_helper(chain, ["foo"]))
}

test_result_helper_with_term if {
	expected := {
		"code": "path.oh.Hey",
		"term": "ola",
		"effective_on": "2022-01-01T00:00:00Z",
		"msg": "Bad thing foo",
	}

	rule_annotations := {"custom": {
		"short_name": "Hey",
		"failure_msg": "Bad thing %s",
	}}

	chain := [
		{"annotations": rule_annotations, "path": ["data", "path", "oh", "deny"]},
		{"annotations": {}, "path": ["ignored", "also_ignored"]},
	]

	lib.assert_equal(expected, lib.result_helper_with_term(chain, ["foo"], "ola"))
}

test_result_helper_pkg_name if {
	# "Normal" for policy repo
	lib.assert_equal("foo", lib._pkg_name(["data", "foo", "deny"]))
	lib.assert_equal("foo", lib._pkg_name(["data", "foo", "warn"]))

	# Long package paths are retained
	lib.assert_equal("another.foo.bar", lib._pkg_name(["data", "another", "foo", "bar", "deny"]))
	lib.assert_equal("another.foo.bar", lib._pkg_name(["data", "another", "foo", "bar", "warn"]))

	# Unlikely edge case: No deny or warn
	lib.assert_equal("foo", lib._pkg_name(["data", "foo"]))
	lib.assert_equal("foo.bar", lib._pkg_name(["data", "foo", "bar"]))

	# Unlikely edge case: No data
	lib.assert_equal("foo", lib._pkg_name(["foo", "deny"]))
	lib.assert_equal("foo.bar", lib._pkg_name(["foo", "bar", "warn"]))

	# Very unlikely edge case: Just to illustrate how deny/warn/data are stripped once
	lib.assert_equal("foo", lib._pkg_name(["data", "foo", "warn", "deny"]))
	lib.assert_equal("foo.deny", lib._pkg_name(["data", "foo", "deny", "warn"]))
	lib.assert_equal("foo.warn", lib._pkg_name(["data", "foo", "warn", "warn"]))
	lib.assert_equal("data.foo.warn.deny", lib._pkg_name(["data", "data", "foo", "warn", "deny", "warn"]))
}
