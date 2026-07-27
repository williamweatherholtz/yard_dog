// =====================================================================
// YardDog — critique-battery finding (data-safety sweep, post-Sprint 30).
// An antagonistic pass over the backup/verify/retention pillar.
// =====================================================================
package YardDogCritiqueIssuesS31 {
    private import EngineElement::*;
    private import EngineWork::*;
    private import EngineRelationships::*;

    // -- CORRECTNESS (Medium): verify is one-directional (extra files undetected) --
    part issVerifyExtraFiles : Issue {
        :>> id = "7ad18d47-24ac-4a23-a690-debbafabfb65";
        :>> title = "Backup verify does not detect unexpected/extra files (one-directional integrity)";
        :>> createdAt = "2026-07-27";
        :>> createdBy = "wweatherholtz";
        :>> description = "verify() checks that every manifest entry still exists and matches (Missing/Changed) but never flags files present in the backup directory yet ABSENT from the manifest. So a backup that has gained stray/extra files verifies as 'intact', even though it no longer exactly matches what was captured. Integrity should be an exact match in both directions (the same principle applied to gitver::restore in S23). Fix: add an Unexpected finding for files under the backup dir (excluding manifest.json) not present in the manifest.";
        :>> discoveredInField = false;
        :>> severity = Severity::Medium;
    }

    #Resolves dependency from verifyDetectsExtra to issVerifyExtraFiles;
}
