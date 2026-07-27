// =====================================================================
// YardDog — Sprint 33 delivery: persona use-case catalog + real-Docker E2E.
// Each use case is validated by a demo verification (#Verify -> UseCase) run by
// the tests/e2e_docker.rs harness against a live Docker daemon.
// =====================================================================
package Sprint33E2E {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineVerification::*;
    private import EngineRelationships::*;

    part storyE2E : Story {
        :>> id = "632f8f26-5db7-4bd8-b578-493a64446167";
        :>> title = "Persona/use-case catalog + real-Docker E2E harness validating every use case";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> kind = WorkKind::code;
        :>> priority = WorkPriority::p1;
        :>> owner = "ai";
        :>> estimatedPoints = 5;
    }

    #CharteredBy dependency from storyE2E to needSimplicity;
    #CharteredBy dependency from storyE2E to needSafeDeploy;

    // -- one demo verification per use case (run by tests/e2e_docker.rs) --------
    verification e2eFirstDeploy : Test { :>> id = "6147f5ef-9d3b-45a9-ad73-75f738af64e0"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_first_deploy — `yd doctor` READY then `yd deploy --yes` on a fresh nginx stack against real Docker: reports Deployed, the container reaches health=healthy, and the stack dir becomes a versioning repo."; }
    part e2eFirstDeployR1 : TestResult { :>> id = "8bd8c0c3-41ac-444b-88df-f9e8a2eb0d65"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification e2eAutoRollback : Test { :>> id = "bebe628f-4afd-4312-84fe-a54df1e6c574"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_auto_rollback — a broken-healthcheck redeploy fails the gate, RolledBack; the live container ends healthy on the restored good config and the compose no longer contains the broken port."; }
    part e2eAutoRollbackR1 : TestResult { :>> id = "f07ba9fd-2e15-409b-bb98-1d3b9df43b88"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification e2eHealthGatedUpgrade : Test { :>> id = "020b02a2-d92f-4e9a-a360-e988b5242a8a"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_health_gated_upgrade — an accepted upgrade 1.27->1.29 leaves the running image at nginx:1.29-alpine healthy; an upgrade of an unknown service fails (NoSuchService) rather than silently succeeding."; }
    part e2eHealthGatedUpgradeR1 : TestResult { :>> id = "fa793d3c-f197-466d-a121-a3af6d2bb313"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification e2eBackupVerifiedRestore : Test { :>> id = "011a0d7b-024c-4c63-a1dd-dfc63428875f"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_backup_verified_restore — `yd backup --run` captures bind data with a manifest, `yd verify` is clean on a fresh backup and fails (non-zero) once a backed-up file is tampered."; }
    part e2eBackupVerifiedRestoreR1 : TestResult { :>> id = "98b4fb91-8c06-4365-bd1c-5807b1d32e29"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification e2eGuardrailsBlock : Test { :>> id = "9153ab9e-e59d-49a6-a6bd-67a16965bda1"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_guardrails_block — a floating :latest stack is NOT READY and deploy is refused before any container starts; a *_FILE secret reference is READY (not falsely blocked)."; }
    part e2eGuardrailsBlockR1 : TestResult { :>> id = "396a94e8-5653-4eb3-83a4-82fe416ec80a"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification e2eLifecycle : Test { :>> id = "245e0afd-545d-4203-94c1-5c5d29b22e14"; :>> method = VerificationMethod::demo; :>> procedureText = "e2e_docker::e2e_uc_lifecycle — `yd new` scaffolds a guardrail-clean datastore in Draft; activate->deprecate->archive; deploy of the archived stack is refused; after restore the stack is READY again."; }
    part e2eLifecycleR1 : TestResult { :>> id = "91245f65-4b47-4674-b610-06ef1bbab757"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    // -- validate the use cases (D0006: validation is verify -> use case) -------
    #Verify dependency from e2eFirstDeploy to ucFirstDeploy;
    #Verify dependency from e2eAutoRollback to ucAutoRollback;
    #Verify dependency from e2eHealthGatedUpgrade to ucHealthGatedUpgrade;
    #Verify dependency from e2eBackupVerifiedRestore to ucBackupVerifiedRestore;
    #Verify dependency from e2eGuardrailsBlock to ucGuardrailsBlock;
    #Verify dependency from e2eLifecycle to ucLifecycle;

    verification refineGate33 : Test { :>> id = "4a527c23-0104-4f00-86dd-70b82114ad5d"; :>> method = VerificationMethod::inspect; :>> procedureText = "DoR: points set (5); charter edges set; 3 personas + 6 use cases authored (personas-usecases.sysml); scope = an opt-in real-Docker E2E harness with one demo per use case, wired via #Verify."; }
    part refineGate33R1 : TestResult { :>> id = "91473453-7029-4444-b633-2bb17195f8d0"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification reviewGate33 : Test { :>> id = "d749f3a1-9ce3-4c71-a255-1122aa420006"; :>> method = VerificationMethod::inspect; :>> procedureText = "AI review: all 6 e2e_docker tests pass against Docker 29.5/Compose v5 (43.8s: real pulls, deploys, health-gates, rollback, upgrade), teardown clean, and the suite is #[ignore]d so `cargo test` stays hermetic (6 ignored). Personas + use cases validate clean; each use case now carries a passing demo verification."; }
    part reviewGate33R1 : TestResult { :>> id = "80997bf0-483b-4c99-8cfd-aa531341415b"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }

    verification closeOutGate33 : Test { :>> id = "376987e2-edd0-4012-9acf-e4714abdd266"; :>> method = VerificationMethod::inspect; :>> procedureText = "CloseOut: personas + use-case catalog defined and each use case validated by a live-Docker demo. The 'test all use cases/personas' pass is green end-to-end; run with `cargo test --test e2e_docker -- --ignored --test-threads=1`."; }
    part closeOutGate33R1 : TestResult { :>> id = "e3645a83-2ba6-48dc-959f-b166e60916cb"; :>> outcome = VerdictKind::pass; :>> judgedAgainst = "b75df60"; :>> judgedAt = "2026-07-27"; :>> judgedBy = "ai"; }
}
