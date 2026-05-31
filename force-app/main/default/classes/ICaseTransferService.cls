/**
 * @file              ICaseTransferService.cls
 * @description       Interface defining the core operations for case transfer processing.
 *                    Implemented by CaseTransferService (production) and
 *                    CaseTransferServiceMock (test double). Enables dependency injection
 *                    in CaseTriggerHandler for testable, swappable service implementations.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      (none)
 * @calledBy          CaseTriggerHandler
 * @testClass         CaseTriggerHandlerTest
 *
 * @see               LLD Case Transfer Flow — Apex Class Design §3
 */

/**
 * Contract for case transfer service implementations.
 *
 * Responsibilities:
 *   - Define validateTransferRequirements for pre-transfer checks.
 *   - Define executeTransfer for persisting transfer data and updating Case ownership.
 *
 * @testClass CaseTriggerHandlerTest
 */
public interface ICaseTransferService {

    /**
     * Validates that all required information is in place before a case can be
     * transferred to the Engineering queue.
     *
     * @param  caseId  The Id of the Case record to validate.
     * @return         true if all transfer requirements are satisfied; false otherwise.
     */
    Boolean validateTransferRequirements(Id caseId);

    /**
     * Executes the full case transfer: persists troubleshooting data, links
     * content documents, marks the case as transferred, and updates Case ownership.
     *
     * @param  caseId               Id of the Case to transfer.
     * @param  troubleshootingSteps Troubleshooting documentation (min 20 chars).
     * @param  reproductionSteps    Semicolon-delimited reproduction step values.
     * @param  contentDocumentIds   Ids of uploaded ContentDocument records to link.
     */
    void executeTransfer(
        Id caseId,
        String troubleshootingSteps,
        String reproductionSteps,
        List<String> contentDocumentIds
    );
}
