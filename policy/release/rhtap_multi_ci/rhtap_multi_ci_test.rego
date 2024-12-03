package rhtap_multi_ci_test

import rego.v1

import data.lib
import data.rhtap_multi_ci

test_atts_happy_path if {
	lib.assert_empty(rhtap_multi_ci.deny) with input.attestations as [good_att]
	lib.assert_empty(rhtap_multi_ci.deny) with input.attestations as [ignored_att, good_att]
}

test_atts_missing if {
	expected := {
		"code": "rhtap_multi_ci.attestation_found",
		"msg": sprintf("%s%s%s%s", [
			"A SLSA v1.0 provenance with one of the following RHTAP Multi-CI build types was not found:",
			" 'https://redhat.com/rhtap/slsa-build-types/jenkins-build/v1',",
			" 'https://redhat.com/rhtap/slsa-build-types/github-build/v1',",
			" 'https://redhat.com/rhtap/slsa-build-types/gitlab-build/v1'.",
		]),
	}

	lib.assert_equal_results({expected}, rhtap_multi_ci.deny) with input.attestations as []
	lib.assert_equal_results({expected}, rhtap_multi_ci.deny) with input.attestations as [ignored_att]
}

good_build_type := "https://redhat.com/rhtap/slsa-build-types/jenkins-build/v1"

good_att := mock_att(good_build_type, {})

ignored_att := mock_att("https://other/build/type/v1", {})

mock_att(build_type, run_details) := {"statement": {
	"predicateType": "https://slsa.dev/provenance/v1",
	"predicate": {
		"buildDefinition": {"buildType": build_type},
		"runDetails": run_details,
	},
}}

test_rhtap_build_type if {
	lib.assert_equal(
		"https://redhat.com/rhtap/slsa-build-types/bacon-build/v1",
		rhtap_multi_ci._build_type("bacon"),
	)
}
