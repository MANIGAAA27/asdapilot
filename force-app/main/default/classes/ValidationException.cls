/**
 * @file              ValidationException.cls
 * @description       Custom exception indicating field-specific validation failures
 *                    and rule violations during case transfer. Extends CaseTransferException
 *                    for typed exception handling in callers.
 * @author            ASDA Dev Agent (Claude Code)
 * @created           2026-05-30
 * @lastModified      2026-05-30
 * @group             CaseTransfer
 *
 * @dependencies      CaseTransferException
 * @calledBy          CaseTransferDomain, CaseTransferService
 * @testClass         CaseTransferServiceTest
 *
 * @see               LLD Case Transfer Flow — Error Handling Design §8
 */

/**
 * Thrown when required fields are missing or fail validation during transfer.
 *
 * Responsibilities:
 *   - Indicate which validation rule was violated via the exception message.
 *   - Allow callers to distinguish validation errors from attachment errors.
 *
 * @testClass CaseTransferServiceTest
 */
public with sharing class ValidationException extends CaseTransferException {
}
