// =====================================================================
// YardDog — Sprint 1 delivery: the path-intelligence + existence-guard core.
// A thin vertical slice: a Rust CLI that, given a docker-compose file, classifies
// every mount into the four path types, reports host-path existence/type, and
// surfaces ranked remediations. Chartered by the Pillar-1 Needs; implements
// srClassifyMounts / srHostPathExistence / srGuidedRemediation. Tasks + DoDs are
// authored via `keel add-task`; gate results via `keel append-gate-result`.
// =====================================================================
package Sprint1PathCore {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;
    // Cross-package charter targets (needPathTyping / needPathExistence /
    // needGuidedRemediation) are referenced by bare name — in .tracking, rust
    // validates these edges generically (name refs, no cross-resolution), so the
    // origin packages are intentionally NOT imported (per sysmlv2-syntax-notes).

    part storyPathCli : Story {
        :>> id = "75820ac5-9bce-4d8b-b6a4-e985e7375bc0";
        :>> title = "Path-classifier CLI: classify mounts, check host-path existence, suggest remediation";
        :>> createdAt = "2026-07-26";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
        :>> actualPoints = 5;
    }

    // Charter lineage (D0068): the work traces to the Needs that chartered it.
    #CharteredBy dependency from storyPathCli to needPathTyping;
    #CharteredBy dependency from storyPathCli to needPathExistence;
    #CharteredBy dependency from storyPathCli to needGuidedRemediation;

    // Backlog: tasks added via `keel add-task --file ... --def Sprint1Backlog ...`.
        action scaffoldCargo;
        verification scaffoldCargoDoD : Test { :>> id = "f3638fa9-b6b5-4fa9-ba40-0e8f76acff63"; :>> method = VerificationMethod::test; :>> procedureText = "cargo build succeeds and cargo test runs green on the skeleton crate, with bollard, serde/serde_yaml, and clap dependencies resolving."; }
        part scaffoldCargoDoDR1 : TestResult { :>> id = "bf39fbb5-7d25-40a8-8f50-495428584cb4"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action parseComposeMounts;
        verification parseComposeMountsDoD : Test { :>> id = "74898383-27b1-41e9-ba40-0e8f777afa3f"; :>> method = VerificationMethod::test; :>> procedureText = "Given compose fixtures, every service mount is extracted with source/target/mode, handling both short and long volume syntax and ${VAR} interpolation."; }
        part parseComposeMountsDoDR1 : TestResult { :>> id = "2c5da933-7d0f-46b9-baff-521cec62990b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action classifyMountType;
        verification classifyMountTypeDoD : Test { :>> id = "a732b76c-e564-41c1-ba40-0e8f7848e323"; :>> method = VerificationMethod::test; :>> procedureText = "Each mount is classified as exactly one of host-bind / named-volume / anonymous / network, verified against fixtures including an NFS/CIFS-backed named volume and a bind on a network mount."; }
        part classifyMountTypeDoDR1 : TestResult { :>> id = "256e9a77-aefc-4d9f-9209-b620f66ecd19"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action checkHostPathExistence;
        verification checkHostPathExistenceDoD : Test { :>> id = "7bfab12b-0d3d-439d-ba40-0e8f79174137"; :>> method = VerificationMethod::test; :>> procedureText = "For bind and network mounts the tool reports existence and directory-vs-file type; a test asserts a missing path is reported AND that no host path is created (no filesystem mutation)."; }
        part checkHostPathExistenceDoDR1 : TestResult { :>> id = "045f1936-657c-4606-afd9-c1e1cfe13666"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action detectOwnershipPerms;
        verification detectOwnershipPermsDoD : Test { :>> id = "975775e8-1384-4a09-ba40-0e8f79dc3dbb"; :>> method = VerificationMethod::test; :>> procedureText = "Owner (uid/gid) and mode of each bind path are reported; a root-owned directory and a PUID/PGID mismatch are flagged in tests."; }
        part detectOwnershipPermsDoDR1 : TestResult { :>> id = "d2ecdc9a-d505-4ac3-adaf-c7bf086ab1a9"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action suggestRemediation;
        verification suggestRemediationDoD : Test { :>> id = "50027ae3-f727-4d51-ba40-0e8f7a9a3c67"; :>> method = VerificationMethod::test; :>> procedureText = "For each detected issue class (missing path, type mismatch, ownership/permission), the tool emits ranked, print-only remediation suggestions matching expected output in tests."; }
        part suggestRemediationDoDR1 : TestResult { :>> id = "363cc577-bd15-4281-84c6-1ffbf8ba262b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
        action cliReport;
        verification cliReportDoD : Test { :>> id = "e5f63cc1-3f4f-4089-ba40-0e8f7b57e8a7"; :>> method = VerificationMethod::test; :>> procedureText = "cargo run -- <compose fixture> prints a per-mount report (type, existence, ownership, remediation); an end-to-end integration test over a fixture passes."; }
        part cliReportDoDR1 : TestResult { :>> id = "bd1575d5-714b-46a9-8e21-57db1fc28ff3"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
    action def Sprint1Backlog { }

    // Refine/DoR gate — result appended via `keel append-gate-result --gate refineGate`.
    verification refineGate : Test { :>> id = "a5c39e10-a538-4756-b34f-b226704e039d"; :>> method = VerificationMethod::inspect; :>> procedureText = "Definition of Ready: estimatedPoints set (5); #CharteredBy edges set to the Pillar-1 Needs; scope/acceptance unambiguous; DoD tasks authored with method-tagged criteria; stack decided (decStack: Rust)."; }
    part refineGateR1 : TestResult { :>> id = "f0ea496a-340f-4b37-ac9c-d6a3944158c1"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }

    // Review gate — HUMAN sign-off (confirmation); result appended via append-gate-result.
    verification reviewGate : Test { :>> id = "84d21bad-7044-46d3-8158-ff6ac9eac737"; :>> method = VerificationMethod::confirmation; :>> procedureText = "Sprint review: wweatherholtz reviewed the path-classifier CLI — 7/7 DoD tests green and the live demo classifying mounts, flagging missing host paths, and proposing ranked remediations — and approved the sprint."; }
    part reviewGateR1 : TestResult { :>> id = "6ba34d73-ee73-4125-97e8-25ba320c3427"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "wweatherholtz"; }

    // CloseOut gate — mechanical check that all DoD passed and review is signed off.
    verification closeOutGate : Test { :>> id = "a64833b3-ef3a-4807-87a2-83a68c2353dc"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: all 7 DoD tasks pass (orient done=7/0) and the review gate carries a passing human attestation; sprint closed."; }
    part closeOutGateR1 : TestResult { :>> id = "cd677ea3-327a-4c01-97e8-25ba330c686f"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "d5d1f74"; :>> judgedAt = "2026-07-26"; :>> judgedBy = "ai"; }
}
