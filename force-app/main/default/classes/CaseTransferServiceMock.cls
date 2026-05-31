/**
 * @file              CaseTransferServiceMock.cls
 * @description       Mock (test double) implementation of ICaseTransferService for use in
 *                    tests requiring dependency injection into CaseTriggerHandler and other
 *                    classes that accept the interface. Tracks call counts and supports
 *                    configurable throw behaviour for negative test paths.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      ICaseTransferService
 * @calledBy          CaseTriggerHandlerTest
 * @testClass         (this IS a test double — consumed by CaseTriggerHandlerTest)
 *
 * @see               LLD Case Transfer Flow — Test Strategy §10
 */

/**
 * Configurable mock for ICaseTransferService.
 *
 * Responsibilities:
 *   - Record whether validateTransferRequirements and executeTransfer were called.
 *   - Support configurable return values and throw-on-call modes.
 *   - Expose call-count tracking for bulk test assertions.
 *
 * @testClass CaseTriggerHandlerTest
 */
@isTest
public class CaseTransferServiceMock implements ICaseTransferService {

    /** Set to true to make validateTransferRequirements throw a CaseTransferException. */
    public Boolean shouldThrowOnValidate = false;

    /** Set to false to simulate a validation failure return value. */
    public Boolean shouldValidate = true;

    /** Tracks whether validateTransferRequirements was called at least once. */
    public Boolean validateCalled = false;

    /** Counts total calls to validateTransferRequirements. */
    public Integer validateCallCount = 0;

    /** Tracks whether executeTransfer was called at least once. */
    public Boolean executeCalled = false;

    /**
     * Mock implementation of validateTransferRequirements.
     * Returns shouldValidate value; throws if shouldThrowOnValidate is true.
     *
     * @param  caseId  (ignored in mock)
     * @return         Value of shouldValidate field.
     */
    public Boolean validateTransferRequirements(Id caseId) {
        validateCalled = true;
        validateCallCount++;
        if (shouldThrowOnValidate) {
            throw new CaseTransferException('Mock validation error');
        }
        return shouldValidate;
    }

    /**
     * Mock implementation of executeTransfer. Records that the method was called.
     *
     * @param  caseId               (ignored)
     * @param  troubleshootingSteps (ignored)
     * @param  reproductionSteps    (ignored)
     * @param  contentDocumentIds   (ignored)
     */
    public void executeTransfer(
        Id caseId,
        String troubleshootingSteps,
        String reproductionSteps,
        List<String> contentDocumentIds
    ) {
        executeCalled = true;
    }
}
